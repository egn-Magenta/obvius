use strict;
use Obvius;
use Data::Dumper;

die q|
Usage: $0 <conf_dir>\n
       $1 <stat_files_dir>\n
       $2 <month>\n
       $3 <year>\n
| if (scalar (@ARGV) != 4);

my $obvius = Obvius->new(Obvius::Config->new('ku'));
$obvius->{USER} = 'admin';

my $file = $ARGV[0];
my $stat_file_dir = $ARGV[1];
my $month = $ARGV[2];
my $year = $ARGV[3];

open(HOSTMAP, "<$file") or die "Couldn't open $file.\n";
my %subsites = ();
my %conf2path;

while (<HOSTMAP>) {
    next if (/^#/ or /^\s*$/);
    my ($site, $path) = ($_ =~ /^(\S+)\s+(\S+)\s*$/);
    die "Horrible error in File $file: \n \"$_\" is not a well formed line" unless ($site and $path);
    $conf2path{subsite_env($site)} = $path;
}

sub subsite_env {
    my $string = shift;
    $string =~ s/\.//g;
    $string =~ s/^(www)+//;
    return $string;
}

my @stat_files = glob(File::Spec->catdir($stat_file_dir . "awstats${month}${year}.*"));

my $current_date = ((localtime(time)))[3] . ((localtime(time)))[4] . ((localtime(time)))[5];

# We traverse the awstats files.
for my $file (@stat_files) {
    open(CURRENT_STATS, "<$file") or die "Couldn't open $file.\n";
    print STDERR "Analysing file: '$file'\n";
    my $read = 0;
    my %score_hash;
    my %docid_hash;
    my $URI;
    while (my $line = <CURRENT_STATS>) {
        if ($line =~ /END_SIDER/) {
            # We lower the READ flag.
            $read = 0;
        }
        if ($read) {
            my @line_parts = split(' ', $line);
            my @file_parts = split(/\./, $file);
            my $rel_url = $line_parts[0];
            $rel_url = lc($rel_url);# Lower case the relative URL
            $rel_url  =~ s!/+!/!g;; # Remove starting slash(es)
            $rel_url  =~ s/\/$//;   # Remove tailing slash
            $URI = $conf2path{$file_parts[(scalar(@file_parts) - 2)]} . $rel_url;
            # We update the URL hassh with the score.
            $score_hash{$URI} = $score_hash{$URI} + $line_parts[3];
            if (index ($line_parts[0], 'docid') < 0) {
                $docid_hash{$URI} = $obvius->get_doc_by_path($line_parts[0]);
            }
        }
        if ($line =~ /BEGIN_SIDER /) {
            # We rise the READ flag in to start reading the stats.
            $read = 1;
        }
    }
    # We create a dump table to store the dat`subsite` int(11) DEFAULT NULL,a temporarily
    my $create_statement = $obvius->dbh->prepare(q|
        CREATE TABLE `monthly_path_statisics_tmp` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `subsite` int(11) DEFAULT NULL,
            `month` tinyint(4) NOT NULL,
            `uri` varchar(255) NOT NULL,
            `visit_count` int(11) DEFAULT NULL,
            PRIMARY KEY (`id`)
        );
    |);
    $create_statement->execute();
    foreach my $key (keys %score_hash) {
        # First we store the data in the dump table:
        my $insert_statement = $obvius->dbh->prepare(q|
            INSERT INTO monthly_path_statisics_tmp (
                subsite, 
                uri, 
                month, 
                visit_count
            )
            VALUES(?, ?, ?, ?);
        |);
        $insert_statement->execute(
            $docid_hash{$key},
            $key,
            $month,
            $score_hash{$key}
        );
    }
    my $previous_cycle = $obvius->execute_select("SELECT cycle_date FROM monthly_path_statisics_last_cycle;");
    if ($current_date < @$previous_cycle[0]->{cycle_date}) {
        # We create a temp table to the hold count of columns
        my $create_count_statement = $obvius->dbh->prepare(q|
            CREATE TABLE `column_count` (
                `subsite` int(11) DEFAULT NULL,
                `uri` varchar (255),
                `columns_count` int(11)
            );
        |)->execute();
        my $last_copy;
        if ($month == 1) {
            $last_copy = 12;
        } else {
            $last_copy = $month - 1;
        }
        my $tmp_counts_statement = $obvius->dbh->prepare(q|
            INSERT INTO column_count (
                subsite,
                uri,
                columns_count
            )
            SELECT subsite, uri, COUNT(*)
            FROM monthly_path_statisics
            GROUP BY uri;
        |)->execute();
        my $copy_counts_statement = $obvius->dbh->prepare(q|
            UPDATE monthly_path_statisics mps, (
                SELECT mps_t.uri, mps_t.subsite, mps_t.visit_count
                FROM monthly_path_statisics mps_t
                INNER JOIN column_count counts
                ON (
                    counts.uri = mps_t.uri AND
                    counts.subsite <=> mps_t.subsite AND
                    counts.columns_count = 13 AND
                    mps_t.month = ?
                )
            ) mps2
            SET mps.visit_count = (
                mps.visit_count + mps2.visit_count
            )
            WHERE
                mps.month = 13 AND
                mps.uri = mps2.uri AND
                mps.subsite <=> mps2.subsite;
        |)->execute($last_copy);
        my $copy_counts_statement = $obvius->dbh->prepare(q|
            INSERT INTO monthly_path_statisics (
                subsite, 
                uri, 
                month, 
                visit_count
            )
            SELECT mps.subsite, mps.uri, 13, mps.visit_count
            FROM monthly_path_statisics mps, (
                SELECT c.uri, c.subsite
                FROM column_count c
                WHERE c.columns_count = 12
            ) counts
            WHERE
                mps.month = ? AND
                mps.uri = counts.uri and
                mps.subsite <=> counts.subsite;
        |)->execute($last_copy);
        my $drop_query = $obvius->dbh->prepare("drop table column_count;")->execute();
    }
    my $update_tables_statement = $obvius->dbh->prepare(q|
        UPDATE monthly_path_statisics mps
        INNER JOIN monthly_path_statisics_tmp mps_t
        ON
            mps_t.month = mps.month AND
            mps_t.subsite <=> mps.subsite AND
            mps_t.uri = mps.uri
        SET mps.visit_count = mps_t.visit_count;
    |)->execute();
    my $insert_tables_statement = $obvius->dbh->prepare(q|
        INSERT INTO monthly_path_statisics (
            subsite, 
            uri, 
            month, 
            visit_count
        )
        SELECT mps_t.subsite, mps_t.uri, mps_t.month, mps_t.visit_count
        FROM monthly_path_statisics_tmp mps_t
        LEFT JOIN monthly_path_statisics mps_j
        ON 
            mps_j.month = mps_t.month AND
            mps_j.subsite <=> mps_t.subsite AND
            mps_j.uri = mps_t.uri
        WHERE
            mps_j.uri IS NULL AND
            mps_j.subsite IS NULL AND
            mps_j.month IS NULL;
    |)->execute();
    # We drop the dump table
    my $drop_query = $obvius->dbh->prepare("drop table monthly_path_statisics_tmp;")->execute();
}
