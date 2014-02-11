use strict;
use Obvius;
use Data::Dumper;

die q|
Usage: $0 <conf_file_path>\n
       $1 <stat_files_dir>\n
       $2 <month_start>\n
       $3 <year_start>\n
       $4 <month_end>\n
       $5 <year_end>\n
| if (scalar (@ARGV) != 6);

my $obvius = Obvius->new(Obvius::Config->new('ku'));
$obvius->{USER} = 'admin';

my $conf_file_path = $ARGV[0];
my $stat_file_dir = $ARGV[1];
my $cur_month = $ARGV[2];
my $cur_year = $ARGV[3];
my $month_end = $ARGV[4];
my $year_end = $ARGV[5];

my $month_append = "0" if (length($cur_month) == 1);
my $year_append = "20" if (length($cur_month) == 2);

while ($cur_month < $month_end && $cur_year < $end_year) {
    print STDERR "Running command with M=$cur_month and Y=$cur_year\n";
    system (
        "perl bin/update_monthly_subsite_stats.pl 01 2013",
        $conf_file_path,
        $stat_file_dir,
        $month_append . $cur_month,
        $year_append . $cur_year
    );
    if ($cur_month == 12) {
        $cur_year++;
        $cur_month = 0;
    } else {
        $cur_month++;
    }
}
