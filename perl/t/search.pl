#!/usr/bin/perl

use strict;
use warnings;

use lib '/home/httpd/root/perl';

use Obvius;
use Obvius::Config;

use Data::Dumper;

my $conf = new Obvius::Config('biotik');
#print Dumper($conf);

my $mcms = new Obvius($conf);
#print Dumper($mcms);

my $docs = $mcms->search([ 'expires', 'lprio', 'lsection', 'published', 'lduration' ],
			 'public > 0 AND expires > NOW() AND lprio > 1 AND lsection != 0 AND (UNIX_TIMESTAMP()-UNIX_TIMESTAMP(published))/(24*60*60) <= lduration',
			 order => 'lprio DESC, published DESC', max=>1
			);
print Dumper($docs);




#$docs = $mcms->search([ 'title' ],
#			 'public > 0 AND title like "%kunder%"'
#			);
#print Dumper($docs);

$docs = $mcms->search([ 'title', 'require' ],
			 'public > 0 AND title like "%kunder%"',
			 order => 'require'
			);
print Dumper($docs);
