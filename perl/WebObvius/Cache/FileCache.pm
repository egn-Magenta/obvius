package WebObvius::Cache::FileCache;

use strict;
use warnings;

use Data::Dumper;
use Cache::FileCache;

sub new {
     my ($class, $obvius, $namespace, %cache_options) = @_;
     
     my $cache_dir = $obvius->{OBVIUS_CONFIG}{FILECACHE_DIRECTORY};
     my $this = bless {obvius => $obvius, 
                 namespace => $namespace, 
                 cache_root => $cache_dir, 
                 cache_options => \%cache_options,
                }, $class;
     
     $this->{cache} = Cache::FileCache->new({cache_root => $this->{cache_root},
                                             namespace => $this->{namespace},
                                             %{$this->{cache_options}}});
     return bless $this, $class;
}

sub get_cache {
     return shift->{cache};
}

sub save {
     my ($this, $key, $data) = @_;
     return $this->get_cache()->set($key, $data);
}

sub get {
     my ($this, $key) = @_;
     return $this->get_cache()->get($key);
}

sub flush {
     my ($this, $dirty) = @_;
     $dirty = [$dirty] if !ref $dirty;
     
     my $cache = $this->get_cache();
     $cache->remove($_) for (@$dirty);
}

sub flush_completely {
     my $this = shift;
     my $cache = $this->get_cache();
     
     $cache->clear();
}

sub find_and_flush {
     my ($this, $cache_objects) = @_;
   
     my $dirty = $this->find_dirty($cache_objects);
     $this->flush($dirty);
}
     
1;
