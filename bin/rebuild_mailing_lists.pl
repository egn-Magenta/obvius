#!/usr/bin/perl
# $Id$
use strict;
use warnings;


use Obvius;
use Obvius::Config;

use Getopt::Long;
use Carp;

use Data::Dumper;

my ($site, $sitename, $debug) = (undef,undef,0);

GetOptions(
           'site=s'      => \$site,
           'sitename=s'  => \$sitename,
           'debug'       => \$debug);

croak ("No site defined")
    unless (defined($site));

my $conf = new Obvius::Config($site);
#print Dumper($conf);
croak ("Could not get config for $site")
    unless(defined($conf));

my $obvius = new Obvius($conf);
#print Dumper($obvius);
croak ("Could not get Obvius object for $site")
    unless(defined($obvius));

my $base_dir = '/home/httpd/'. ($sitename || $conf->Sitename);

my $list_dir = $base_dir . "/mail";

## "Main" program part

do { build_all(); exit (0) };

print STDERR "Hey!! Nothing done!\n";

exit(0);


sub build_all {
    my @subscribers_2_send;

    my %search_options = (
                            notexpired => 1,
                            public => 1,
                            needs_document_fields => ['name']
                        );

    my $subscribeable_docs = $obvius->search( [ 'subscribeable' ], 'subscribeable = \'automatic\'', %search_options) || [];

    # Remove the old files.
    system("rm -f $list_dir/$site.*");

    for my $doc (@$subscribeable_docs) {
        my $emails = $obvius->get_subscription_emails($doc->DocId) || [];
        unshift(@$emails, 'nobody');

        my $filename = "$list_dir/" . $site . "." . $doc->DocId . "." . lc($doc->Name);
        open(FILE, ">$filename") or die "Could not open file for writing: $filename\n";

        for(@$emails) {
            print FILE $_ . "\n";
        }

        close(FILE);
    }
}

