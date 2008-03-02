package WebObvius::Cache::CacheObjects;

use strict;
use warnings;

use Data::Dumper;
use WebObvius::Cache::StandardHashCache;
use WebObvius::Cache::CacheDoc;
use WebObvius::Cache::Collection;

our @ISA = qw( WebObvius::Cache::Collection );

our @cache_objects = qw( WebObvius::Cache::CacheDoc
		         WebObvius::Cache::StandardHashCache );

sub new {
     my ($class, $obvius) = @_;
     
     my $obj = $class->SUPER::new;
     return $obj;
}
     
sub add_to_cache {
     my ($this, $obvius, %object) = @_;;

     for (@cache_objects) {
	  my $obj = eval ($_ . '->new($obvius, %object);' );
	  print STDERR "error: $@";
	  next if (!$obj);
	  
	  push @{$this->{collection}}, $obj;
	  return $obj;
     } 
     
     return 0;
}
     
