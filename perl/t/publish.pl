#!/usr/bin/perl

use strict;
use warnings;

use lib '/home/httpd/root/perl';

use Obvius;
use Obvius::Config;

use Data::Dumper;
use POSIX qw(strftime);

$Data::Dumper::Indent = 1;

my $conf = new Obvius::Config('magenta');
#print Dumper($conf);

my $mcms = new Obvius($conf);
#print Dumper($mcms);

my $doc = $mcms->lookup_document('/magenta/test/');
print Dumper($doc);

my $vdoc = $mcms->get_latest_version($doc);
$mcms->get_version_fields($vdoc, 255);
print Dumper($vdoc);

$vdoc->field(published => strftime('%Y-%m-%d %H:%M:%S', localtime));
$vdoc->field(gduration => 0);
$vdoc->field(gprio => 0);
$vdoc->field(lduration => 0);
$vdoc->field(lprio => 0);
$vdoc->field(lsection => 0);

if ($mcms->publish_version($vdoc)) {
    print "New document published\n";
} else {
    print "FEJL $mcms->{DB_Error}\n";
    exit;
}
