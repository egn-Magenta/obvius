#!/usr/bin/perl

use strict;
use warnings;

use lib '/home/httpd/root/perl';

use Obvius;
use Obvius::Config;

use Data::Dumper;

$Data::Dumper::Indent = 1;

my $conf = new Obvius::Config('magenta');
#print Dumper($conf);

my $mcms = new Obvius($conf);
#print Dumper($mcms);

my $doc = $mcms->lookup_document('/magenta/');
#print Dumper($doc);

#my @bad = $doc->validate;
#print Dumper(\@bad);
#exit;

my $vdoc = $mcms->get_public_version($doc);
print Dumper($vdoc);

#my @bad = $vdoc->validate;
#print Dumper(\@bad);
#exit;

my $doctype = $mcms->get_version_type($vdoc);
print Dumper($doctype);

my %a = $doctype->validate_fields($mcms->get_version_fields($vdoc, 255), $mcms);
print Dumper(\%a);

my %b = $doctype->validate_publish_fields($mcms->get_version_fields($vdoc, 255), $mcms);
print Dumper(\%b);
