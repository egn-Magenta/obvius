package WebObvius::SOAP::CacheHandler;

use strict;
use warnings;

use Obvius;
use Obvius::Config; 
use Data::Dumper;
use WebObvius::Cache::ApacheCache;

my $obvius_config;

sub import {
     my ($class, $config) = @_;
     $obvius_config = Obvius::Config->new($config);
}

sub flush {
     my ($this, $commands) = @_;

     my $obvius = Obvius->new($obvius_config); 
     my $ac = WebObvius::Cache::ApacheCache->new($obvius);
     $ac->flush($commands);

     return 0;
} 

1;
