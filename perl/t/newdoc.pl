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
print Dumper($doc);

my $fields = new Obvius::Data(
			    author => 'newdoc.pl test program',
			    category => [],
			    content => 'Her kan vi skrive en roman',
			    contributors => 'et.al',
			    docdate => '2001-08-15',
			    docref => 'noref',
			    doctype => 'document type',
			    expires => '9999-01-01 00:00:00',
			    gduration => 1,
			    gprio => 2,
			    image => undef,
			    keyword => [ 1, 2, 4],
			    lang => 'da',
			    lduration => 3,
			    lprio => 4,
			    lsection => 0,
			    mimetype => 'text/html',
			    pagesize => 10,
			    published => '0000-00-00 00:00:00',
			    require => 'teaser',
			    seq => 0,
			    short_title => 'kort titel',
			    sortorder => 'author',
			    source => 'newdoc.pl',
			    subscribeable => 0,
			    teaser => 'Test dokument',
			    template => 1,
			    title => 'titel',
			    url => '',
			   );

my ($docid, $version) = $mcms->create_new_document($doc, 'test', $doc->param('type'), 'da', $fields);
if (defined $docid) {
    print "Nyt document $docid, version $version\n";
} else {
    print "FEJL $mcms->{DB_Error}\n";
    exit;
}
