package WebObvius::Cache::Cache;

use strict;
use warnings;

use WebObvius::Cache::UserCache;
use WebObvius::Cache::ExternalCache;
use WebObvius::Cache::Collection;
use WebObvius::Cache::AdminLeftmenuCache;

our @ISA = qw( WebObvius::Cache::Collection );

sub new {
     my ($class, $obvius) = @_;
     
     my $user_cache     = WebObvius::Cache::UserCache->new($obvius);
     my $leftmenu_cache = WebObvius::Cache::AdminLeftmenuCache->new($obvius);

     my $external_cache = WebObvius::Cache::ExternalCache->new($obvius);
     
     return $class->SUPER::new($user_cache, $leftmenu_cache, $external_cache);
}

1;
