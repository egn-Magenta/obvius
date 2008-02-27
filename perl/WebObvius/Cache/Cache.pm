package WebObvius::Site::Mason::Cache;

use WebObvius::Cache::MasonCache;
use WebObvius::Cache::ExternalCache;
use WebObvius::Cache::CacheCollection;

our @mason_cache = (['/portal/subdocs', 'get_subs']);
our @ISA = qw( WebObvius::Cache::CacheCollection );

sub new {
     my ($class, $mason_base, $obvius) = @_;
     
     my @mason_caches;
     push @mason_caches, WebObvius::Cache::MasonCache->new($mason_base, @$_) for @mason_cache;

     my $apache_cache = WebObvius::Cache::ApacheCache->new($obvius);
     
     return $class::SUPER->new($external_cache, @mason_caches);
}

1;
