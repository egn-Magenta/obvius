package WebObvius::SOAP::CacheHandler;

use strict;
use warnings;

use Obvius;
use Obvius::Config; 
use Data::Dumper;

my $obvius_config;

sub import {
     my ($class, $config) = @_;
     $obvius_config = Obvius::Config->new($config);
}

my @good_caches = qw( WebObvius::Cache::UserCache WebObvius::Cache::ApacheCache );

sub flush {
     my ($this, $command) = @_;

     my $obvius = Obvius->new($obvius_config); 
     my $cache = $command->{cache};
     goto end if (!scalar(grep { $_ eq $cache } @good_caches));
     
     my $cache_obj;

     eval "use $cache;\n \$cache_obj = $cache->new(\$obvius);";
     goto end if ($@ || !$cache_obj);
     
     my $commands = $command->{commands};
     
     $cache_obj->flush($commands);

   end:
     undef $obvius->{DB};
     return 0;
} 

1;
