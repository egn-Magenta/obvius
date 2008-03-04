package WebObvius::Cache::Cache;

use strict;
use warnings;

use WebObvius::Cache::ExternalCache;
use WebObvius::Cache::Collection;
use WebObvius::Cache::FileCache;

our @ISA = qw( WebObvius::Cache::Collection );

sub new {
     my ($class, $obvius) = @_;
     
     my $leftmenu_cache = WebObvius::Cache::FileCache->new($obvius);

     my $external_cache = WebObvius::Cache::ExternalCache->new($obvius);
     
     return $class->SUPER::new($leftmenu_cache, $external_cache);

}

1;
