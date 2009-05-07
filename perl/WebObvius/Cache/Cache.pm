package WebObvius::Cache::Cache;

use strict;
use warnings;

use WebObvius::Cache::ExternalUserCache;
use WebObvius::Cache::ExternalApacheCache;
use WebObvius::Cache::Collection;
use WebObvius::Cache::AdminLeftmenuCache;
use WebObvius::Cache::InternalProxyCache;
use WebObvius::Cache::ExternalMedarbejderoversigtCache;

our @ISA = qw( WebObvius::Cache::Collection );

sub new {
     my ($class, $obvius) = @_;
     
     my $user_cache     = WebObvius::Cache::ExternalUserCache->new($obvius);
     my $leftmenu_cache = WebObvius::Cache::AdminLeftmenuCache->new($obvius);

     my $apache_cache = WebObvius::Cache::ExternalApacheCache->new($obvius);
     my $internal_proxy_cache = WebObvius::Cache::InternalProxyCache->new($obvius);
     
     my $medarbejderoversigt_cache = WebObvius::Cache::ExternalMedarbejderoversigtCache->new($obvius);;
   
     return $class->SUPER::new($user_cache, 
                               $leftmenu_cache, 
                               $apache_cache, 
                               $internal_proxy_cache,
                               $medarbejderoversigt_cache);
}

1;
