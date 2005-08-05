#!/usr/bin/perl

# expire_archive.pl - Deletes archived logfiles and database backups which are
#                     older than a year. Great care is taken NOT just to remove
#                     files which are older than a year, but to ensure that
#                     atleast a years worth of data is still left behind.
#                     This is done by only deleting files which are a year older
#                     than the latest created archive.
#
# Copyright (C) 2005 Magenta ApS. By Martin Skøtt. Under the GPL.
#
# $Id$

use strict;
use warnings;

use Getopt::Long;
use IO::Dir;
use Cwd;
use Date::Calc qw (Delta_YMD);

my @OPTV=@ARGV;

#Directories where sites are stored. Usually /var/www and /home/http (often link to /var/www)
my @BASEDIRS=qw (/var/www /home/httpd);

#Directories under each site where archived data can be found
my $LOGDIR="logs";
my $DBDIR="backup";

# expire - $path - path where files to be expired are
#          $regex - pattern to match files to be expired
#          $extension - last part of all names (eg. .log.gz) usually final part of $regex
sub expire {
    my ($path,$regex,$extension)=@_;
    my $cwd=getcwd();
    chdir($path);
    my %directory;
    tie (%directory, 'IO::Dir', '.', 1); #Change 1 to 0 if no files should be deleted

    my %files;
    foreach (keys(%directory))
    {
        if ( $_ =~ /$regex/)
        {
            $files{$1} = [] unless defined ($files{$1});
            push (@{$files{$1}}, $2);
        }
    }

    foreach my $basename (keys(%files))
    {
        my $latest = (sort(@{$files{$basename}}))[-1];
        my $latestY = substr($latest,0,4);
        my $latestM = substr($latest,4,2);
        my $latestD = substr($latest,6,2) || '01';
        foreach my $cur (@{$files{$basename}})
        {
            my $curY = substr($cur,0,4);
            my $curM = substr($cur,4,2);
            my $curD = substr($cur,6,2) || '01';
            my ($Dy,$Dm,$Dd) = Delta_YMD($curY,$curM,$curD,$latestY,$latestM,$latestD);
            if (($Dy > 0) and ($Dm >= 0)) #More than a year old
            {
                print ("#\tRemoving $basename$cur$extension\n");
                delete $directory{"$basename$cur$extension"};
            }
        }
    }

    chdir($cwd);
}

sub site_expire{
    my ($site)=@_;
    my $cwd=getcwd();
    chdir($site);
    print ("# $site\n");
    expire($LOGDIR,'(.*)(\d{6})\.log\.gz$','.log.gz') if -d $LOGDIR;
    expire($DBDIR,'(.*)(\d{8})\.sql\.gz$','.sql.gz') if -d $DBDIR;
    chdir($cwd);
}

foreach my $base (@BASEDIRS)
{
    #Detect links to paths allready listed for check.
    #No need to check them twice
    if (my $link_target = readlink($base))
    {
        next if (scalar(grep (/$link_target/, @BASEDIRS)))
    }
    my $b = IO::Dir->new($base);
    while (defined($_ = $b->read())) {
        next unless -d "$base/$_";
        next if $_ =~ /^[.][.]?\z/;
        site_expire("$base/$_");
    }
}
