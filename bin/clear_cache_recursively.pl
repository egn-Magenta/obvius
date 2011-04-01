#!/usr/bin/perl

use strict;
use warnings;

use Obvius;
use Obvius::Config;

use WebObvius::Cache::Cache;

my $confname = $ARGV[0];
die "No config name specified" unless($confname);

my $docid = $ARGV[1];
die "You must specify a path or a docid to clear" unless($docid);

my $conf = new Obvius::Config($confname);
die "No such Obvius config '$confname'" unless($conf);
my $obvius = new Obvius($conf);

my $doc;

if($docid =~ m!^\d+$!) {
    $doc = $obvius->get_doc_by_id($docid);
} else {
    $doc = $obvius->lookup_document($docid);
}

die "The specified docid/path does not result to a document" unless($doc);

$obvius->register_modified(docid => $doc->Id, clear_recursively => 1);

# Clear cache
my $cache = WebObvius::Cache::Cache->new($obvius);
my $modified = $obvius->modified;
$obvius->clear_modified;
$cache->find_and_flush($modified);
