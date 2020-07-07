#!/usr/bin/perl

use strict;
use warnings;

# This script can be used for quick processing of Obvius' command queue from
# cron. The script should be fast enough that you can run it each minute and
# get the same result as if using atd.

use Obvius::Config;
use DBI;
use POSIX qw(strftime);
use Time::HiRes;
use Data::Dumper;

for my $confname (@ARGV) {
    my $config;
    eval {

        $config = new Obvius::Config($confname);
        die "No config $confname" unless($config && $config->param('dsn'));

        my $sitebase = $config->param('sitebase');
        die "No sitebase for $confname" unless($sitebase);

        die "Config $confname not configured to use cron queue"
            unless($config->param('use_cron_for_queue'));

        $sitebase =~ s!/$!!;
        my $timefile = "$sitebase/var/queue_last_processed.time";
        my $logfile = "$sitebase/logs/queue_processing.log";
        # Default to processing jobs from within the last 24 hours
        my $time = strftime('%Y-%m-%d %H:%M:%S', localtime(time - 60*60*24));
        my $starttime = time;
        if(-f $timefile) {
            my @stat = stat($timefile);
            # Adjust time to be 24 hours since last run
            $time = strftime(
                '%Y-%m-%d %H:%M:%S', localtime($stat[9] - 60*60*24)
            );
        }

        my $dbh = DBI->connect(
            $config->param('dsn'),
            $config->param('normal_db_login'),
            $config->param('normal_db_passwd')
        ) or die "Couldn't connect to database for $confname";

        # Select the 50 most recent unprocessed jobs
        my $sth = $dbh->prepare(q|
            SELECT
                id
            FROM
                queue
            WHERE
                date >= ?
                AND
                date <= NOW()
                AND
                (
                    status IS NULL
                    or
                    status = ""
                )
            ORDER BY date
            LIMIT 50
        |);
        $sth->execute($time);

        while(my ($id) = $sth->fetchrow_array) {
            system("/var/www/obvius/bin/perform_order --site $confname $id >> $logfile 2>&1 &");
            # Stagger jobs by 1 second to prevent failure due to concurrent database writes
            # This also ensures we don't run out of memory
            Time::HiRes::sleep(1);
        }

        # Make sure time file exists and set its mtime to when we started
        system("touch $timefile") unless(-f $timefile);
        utime($starttime, $starttime, $timefile);
    };

    if($@) {
        warn($@);
        next;
    }
}
