#!/usr/bin/perl
# $Id$
use strict;
use warnings;

use lib '/home/httpd/obvius/perl_blib', '/usr/lib/perl/5.6.1', '/usr/lib/perl/5.6.0';

use Obvius;
use Obvius::Config;

use Getopt::Long;
use Carp;

use Date::Calc qw(Today_and_Now Add_Delta_DHMS);
use Data::Dumper;

my ($site) = (undef);

GetOptions('site=s'=> \$site);

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

# Admin should always be capable of publishing
$obvius->{USER} = 'admin'; # XXX need to change this someday

my ($year, $month, $day, $hour, $min, $sec) = Today_and_Now();

($year, $month, $day, $hour, $min, $sec) = Add_Delta_DHMS($year, $month, $day, $hour, $min, $sec, 0,0,1,0); # Add one minute

my $now = sprintf("%04d-%02d-%02d %02d:%02d:%02d", $year, $month, $day, $hour, $min, $sec);

my $docs = $obvius->search(['publish_on'], "publish_on < '$now' and publish_on > '0000-00-00 00:00:00' and public < 1") || [];

for(@$docs) {
    my $doctype = $obvius->get_doctype_by_id($_->Type);
    my @fields = keys %{$doctype->publish_fields};
    $obvius->get_version_fields($_, \@fields, 'PUBLISH_FIELDS');
    $_->{PUBLISH_FIELDS}->{PUBLISHED} = $now;
    $_->{PUBLISH_FIELDS}->{PUBLISH_ON} = '0000-00-00 00:00:00'; # Don't publish again
    my $publish_error;
    unless($obvius->publish_version($_, \$publish_error)) {
	print STDERR "An error occured publishing the document with docid " . $_->DocId . "\n";
	print STDERR '$obvius->publish_version returned the following error: ' . $publish_error . "\n" if($publish_error);
    }
}
