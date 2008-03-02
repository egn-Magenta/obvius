package WebObvius::Cache::Cache;

use strict;
use warnings;
use WebObvius::Cache::LeftmenuMasonCache;
use WebObvius::Cache::ExternalCache;
use WebObvius::Cache::Collection;

our @ISA = qw( WebObvius::Cache::Collection );

sub new {
     my ($class, $obvius) = @_;
     
     my $leftmenu_cache = WebObvius::Cache::LeftmenuMasonCache->new($obvius->{OBVIUS_CONFIG}{SITEBASE}, 
							    '/portal/subdocs', 'get_subs');

     my $external_cache = WebObvius::Cache::ExternalCache->new($obvius);
     
     return $class->SUPER::new($external_cache, $leftmenu_cache);

}

1;
