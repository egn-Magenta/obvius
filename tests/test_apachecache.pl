#!/usr/bin/env perl

use strict;
use warnings;

use Data::Dumper;

use Obvius;
use Obvius::Config;

use WebObvius::Cache::ApacheCache;
use WebObvius::Cache::CacheObjects;

my $obvius = Obvius->new(Obvius::Config->new('ku'));
my $cache = WebObvius::Cache::ApacheCache->new($obvius);

my $calendarevent = $obvius->execute_select("select docid from versions where type=20 limit 1");
my $cache_objs = WebObvius::Cache::CacheObjects->new;
$cache_objs->add_to_cache($obvius, docid => $calendarevent->[0]{docid});
print STDERR Dumper($cache->find_dirty($cache_objs));
