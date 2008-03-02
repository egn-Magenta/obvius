package WebObvius::Cache::MasonCache;

use Data::Dumper; 
use Cache::FileCache;
use HTML::Mason::Utils;

sub new
{
    my ($class, @args) = @_;
    
    return bless {cache_args => [@args]}, $class;
}

sub open_cache
{
    my ($base, $component, $method) = @_;

    my $namespace=($method ? "[method '$method' of /sitecomp$component]" : "/sitecomp$component");
    my $cache=Cache::FileCache->new(
	{
	    namespace=>HTML::Mason::Utils::data_cache_namespace($namespace),
	    cache_root=>$base
	});

    return $cache;
}

sub flush {
     my ($this, $docids) = @_;
     
     my $cache = open_cache(@{$this->{cache_args}});
     
     print STDERR "Flusing: " . Dumper($docids);
     $docids = [$docids] if (!ref $docids);

     $cache->remove($_) for (@$docids);
}

sub find_and_flush {
     my ($this, $docs) = @_;
     
     print STDERR "Docs: " . Dumper($docs);
     my $dirty = $this->find_dirty($docs);
     $this->flush($dirty) if scalar(@$dirty);
}

1;
