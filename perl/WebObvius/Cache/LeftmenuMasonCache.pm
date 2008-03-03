package WebObvius::Cache::LeftmenuMasonCache;

use Data::Dumper;
use WebObvius::Cache::MasonCache;

our @ISA = qw( WebObvius::Cache::MasonCache );

sub new {
     my ($class, $obvius, @args) = @_;
     
     my $new = $class->SUPER::new(@args);
     
     $new->{obvius} = $obvius;
     return $new;
}

sub find_dirty {
     my ($this, $cache_objects) = @_;
     
     my $obvius = $this->{obvius};

     my $cache_objects = $cache_objects->request_values('docid', 'clear_leftmenu');
     
     @$cache_objects = map { $_->{docid} } 
         grep { $_->{clear_leftmenu} || $_->{clear_admin_leftmenu}} @$cache_objets;

     for (@$cache_objects) {
	  my $doc = $obvius->get_doc_by_id($_->{docid});
	  next if (!$doc);
	    
	  push @dirty, $doc->Parent if ($doc->Parent);
	  
     }
     
     return \@dirty;
}

1;
