package WebObvius::Cache::FileCache;

use strict;
use warnings;

use Data::Dumper;
use Cache::FileCache;

sub new {
     my ($class, $obvius, %opts) = @_;

     my $this = {obvius => $obvius, %opts};
     return bless $this, $class;
}

sub find_dirty {
     my ($this, $cache_objects) = @_;
     my @dirty;

     my $obvius = $this->{obvius};
     
     my $values = $cache_objects->request_values('docid', 'clear_leftmenu', 'clear_admin_leftmenu');
     my @docids = map { $_->{docid} } 
       grep { $_->{clear_admin_leftmenu} || $_->{clear_leftmenu}} @$values;
     
     for (@docids) {
	  push @dirty, $_;
	  my $doc = $obvius->get_doc_by_id($_);
	  next if (!$doc);
	  
	  push @dirty, $doc->Parent if ($doc->Parent);

     }
     
     return \@dirty;
}
 
sub flush {
     my ($this, $dirty) = @_;
     $dirty = [ $dirty] if (!ref $dirty);
     
     my $cache = Cache::FileCache->new({cache_root => '/var/www/www.ku.dk/var/file_cache',
					namespace => 'subdocs'});

     $cache->remove($_) for (@$dirty);
}

sub find_and_flush {
     my ($this, $cache_objects) = @_;
     
   
     my $dirty = $this->find_dirty($cache_objects);
     $this->flush($dirty);
}
     
1;
