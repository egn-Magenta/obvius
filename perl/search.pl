#!/usr/bin/perl

use strict;
use warnings;

use lib '/home/httpd/root/perl';

use Obvius;
use Obvius::Config;

use Data::Dumper;

my $conf = new Obvius::Config('biotik');
print Dumper($conf);

my $obvius = new Obvius($conf);
#print Dumper($obvius);

my $docs = $obvius->get_synonyms(1);

print Dumper($docs);
