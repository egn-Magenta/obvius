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

my @stat_files = glob("../../www.ku.dk/awstats${month}${year}.*");

# We traverse the awstats files.
for my $file (@stat_files) {
    open(CURRENT_STATS, "<$file") or die "Couldn't open $file.\n";
    my $read = 0;
    while (my $line = <CURRENT_STATS>) {
        if ($line =~ /END_SIDER/) {
            # We lower the read flag.
            $read = 0;
        }
        if ($read) {
            my @line_parts = split(' ', $line);
            my @file_parts = split(/\./, $file);
            my $doc_id = $obvius->get_doc_by_path($line_parts[0]);
            if ($doc_id) {
                print STDERR "\nSTATEMENT:\n" . "INSERT INTO monthly_path_statisics (subsite, uri, month, visit_count) VALUES($doc_id, '" . $conf2path{$file_parts[scalar(@file_parts) - 2]} . "', $month, $line_parts[3])";

#$obvius->dbh->prepare("INSERT INTO monthly_path_statisics (subsite, uri, month, visit_count) VALUES($doc_id, '" . $conf2path($line_parts_by_dot[count($line_parts_by_dot) - 2]) . "', $month, $line_parts_by_whitespace[3])");
            }
        }
        if ($line =~ /BEGIN_SIDER /) {
            # We give signal to start reading the stats.
            $read = 1;
        }
    }
}
