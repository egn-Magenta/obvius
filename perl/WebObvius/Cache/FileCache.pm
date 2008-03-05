package WebObvius::Cache::FileCache;

use strict;
use warnings;

use Data::Dumper;
use Cache::FileCache;

sub new {
     my ($class, $obvius, $namespace) = @_;

     my $cache_dir = $obvius->{OBVIUS_CONFIG}{FILECACHE_DIRECTORY};
     my $this = {obvius => $obvius, namespace => $namespace, cache_root => $cache_dir};
     return bless $this, $class;
}

sub flush {
     my ($this, $dirty) = @_;
     $dirty = [ $dirty] if (!ref $dirty);
     
     my $cache = Cache::FileCache->new({cache_root => $this->{cache_root},
					namespace => $this->{namespace}});

     $cache->remove($_) for (@$dirty);
}

sub flush_completely {
     my $this = shift;
     my $cache = Cache::FileCache->new({cache_root => $this->{cache_root},
					namespace  => $this->{namespace}
				       });
     
     $cache->clear();
}

sub find_and_flush {
     my ($this, $cache_objects) = @_;
   
     my $dirty = $this->find_dirty($cache_objects);
     $this->flush($dirty);
}
     
1;
