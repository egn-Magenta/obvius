use strict;
use Obvius;
use Data::Dumper;

die "Usage: $0 <hostmap>\n" if (scalar (@ARGV) != 3);

my $obvius = Obvius->new(Obvius::Config->new('ku'));
$obvius->{USER} = 'admin';

my $file = $ARGV[0];
my $month = $ARGV[1];
my $year = $ARGV[2];

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

my @stat_files = glob("../www.ku.dk/awstats${month}${year}.*");

my $day_of_month = ((localtime(time)))[3];

# We traverse the awstats files.
for my $file (@stat_files) {
    open(CURRENT_STATS, "<$file") or die "Couldn't open $file.\n";
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
            $rel_url  =~ s!/+!!g;; # Remove starting slash(es)
            $rel_url  =~ s/\/$//;   # Remove tailing slash
            $URI = $conf2path{$file_parts[(scalar(@file_parts) - 2)]} . $rel_url;
            # We update the URL hassh with the score.
            $score_hash{$URI} = $score_hash{$URI} + $line_parts[3];
            $docid_hash{$URI} = $obvius->get_doc_by_path($line_parts[0]);
        }
        if ($line =~ /BEGIN_SIDER /) {
            # We rise the READ flag in to start reading the stats.
            $read = 1;
        }
    }
    foreach my $key (keys %score_hash) {
            my $res = $obvius->execute_select(
                "SELECT id FROM monthly_path_statisics WHERE uri = ?;",
                $key,
            );
            if (scalar(@$res) == 0) {       # If URI is not found, we INSERT...
                my $insert_statement = $obvius->dbh->prepare(
                    q|
                        INSERT INTO monthly_path_statisics (
                            subsite, 
                            uri, 
                            month, 
                            visit_count
                        )
                        VALUES(?, ?, ?, ?);
                    |
                );
                $insert_statement->execute(
                    $docid_hash{$key},
                    $key,
                    $month,
                    $score_hash{$key}
                );
            } else {                        # ...otherwise, we UPDATE.
                my $update_statement = $obvius->dbh->prepare(
                    qq|
                        UPDATE monthly_path_statisics SET 
                            visit_count = ? 
                            WHERE 
                                uri = ? AND
                                month = ? AND
                                subsite = ?;
                    |
                );
                $update_statement->execute(
                    $score_hash{$key},
                    $key,
                    $month,
                    $docid_hash{$key}
                );
            }
            if ($day_of_month == 1) {
                # Check number of columns
                # Evt. add count from last month to archive column
                my $column_count = $obvius->execute_select(
                    "SELECT COUNT(*) AS count FROM monthly_path_statisics WHERE uri = ?;",
                    $key
                );
                if (@$column_count[0]->{count} == 13) {
                    my $month_copy;
                    if ($month > 1) {
                        $month_copy = 2;#--$month;
                    } else {
                        $month_copy = 12;
                    }
                    my $count_previous_month = $obvius->execute_select(
                        "SELECT visit_count, subsite FROM monthly_path_statisics WHERE uri = ? AND month = ?;",
                        $key,
                        2
                    );
                    my $current_total_count = $obvius->execute_select(
                        "SELECT visit_count, subsite FROM monthly_path_statisics WHERE uri = ? AND month = ?;",
                        $key,
                        13 
                    );
                    if (scalar(@$current_total_count) > 0) { # If archive row is present, we UPDATE it...
                        my $total_count = @$count_previous_month[0]->{visit_count} + @$current_total_count[0]->{visit_count};
                        my $month_update_statement = $obvius->dbh->prepare(
                            qq|
                                UPDATE monthly_path_statisics SET 
                                    visit_count = ? 
                                    WHERE uri = ? AND
                                    month = ? AND
                                    subsite = ?;
                            |
                        );
                        $month_update_statement->execute(
                            $total_count,
                            $key,
                            13, # We set 13 to be the archive column
                            @$count_previous_month[0]->{subsitet}
                        );
                    } else {                                # otherwise, we INSERT it.
                        my $month_insert_statement = $obvius->dbh->prepare(
                            qq|
                                INSERT INTO monthly_path_statisics (
                                    month, 
                                    visit_count, 
                                    uri,
                                    subsite
                                )
                                VALUES (?, ?, ?, ?);
                            |
                        );
                        $month_insert_statement->execute(
                            13, # We set 13 to be the archive column
                            @$count_previous_month[0]->{visit_count},
                            $key,
                            @$count_previous_month[0]->{subsitet}
                        );
                    }
                }
            }
    }
}
