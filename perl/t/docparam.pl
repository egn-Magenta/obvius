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
print Dumper($doc);

print Dumper($mcms->get_docparam_value_recursive($doc, 'mini_icon'));
