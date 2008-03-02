package WebObvius::Cache::Collection;

use Data::Dumper;

use strict;
use warnings;

sub new {
     my ($class, @coll) = @_;

     return bless { collection =>  [@coll] }, $class;
}

sub AUTOLOAD {
     my ($this, @args) = @_;
     our $AUTOLOAD;

     my ($method) = $AUTOLOAD =~ /::([^:]+)$/;
     my @result;
     
     print STDERR "Here: $method \n";
     for my $cache (@{$this->{collection}}) {
	  if (my $sub = $cache->UNIVERSAL::can($method)) {
	       push @result, &$sub($cache,@args);
	  }
     }
     
     return \@result;
}


sub request_values {
     my ($this, @values) = @_;
     my @result;
     
     print STDERR "in request_values\n";
     for my $cache (@{$this->{collection}}) {
	  my %res = map {$_ => $cache->{$_}} @values;
	  push @result, \%res;
     }

     return \@result;
}

1;
