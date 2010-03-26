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

my $cache_objs = WebObvius::Cache::CacheObjects->new;
$cache_objs->add_to_cache($obvius, docid => 106849);
print STDERR Dumper($cache->find_dirty($cache_objs));
