#!/usr/bin/perl

use strict;
use warnings;

use lib '/home/httpd/root/perl';

use Obvius;
use Obvius::Config;

use Data::Dumper;

my $conf = new Obvius::Config('magenta');
#print Dumper($conf);

my $mcms = new Obvius($conf);
#print Dumper($mcms);

my $doc = $mcms->lookup_document('/magenta/');
#print Dumper($doc);

my $vdoc = $mcms->get_public_version($doc);
#print Dumper($vdoc);

my $doctype = $mcms->get_version_type($vdoc);
#print Dumper($doctype);

my $fields = $mcms->get_version_fields($vdoc);
#print Dumper($fields);

my $f = $mcms->get_version_field($vdoc, 'template');
print "Template = ", Dumper($f);

$fields = $mcms->get_version_fields($vdoc, [ 'template', 'doctype', 'source', 'author' ]);
#print Dumper($fields);

$fields = $mcms->get_version_fields($vdoc, 64);
#print Dumper($fields);

$fields = $mcms->get_version_fields($vdoc, 32);
#print Dumper($fields);

$fields = $mcms->get_version_fields($vdoc, 129);
#print Dumper($fields);

$fields = $mcms->get_version_fields($vdoc, 10000);
#print Dumper($fields);
