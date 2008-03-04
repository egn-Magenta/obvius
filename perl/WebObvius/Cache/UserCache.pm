package WebObvius::Cache::UserCache;

use WebObvius::Cache::FileCache;

our @ISA = qw( WebObvius::Cache::FileCache );
use warnings;
use strict;

sub new {
     my ($class, $obvius) = @_;
     return $class->SUPER::new($obvius, 'user_data');
}

sub find_and_flush {
     my ($this, $class_objects) = @_;
     
     my $relevant = $class_objects->retrieve_values('users');
     
     my $flush = grep { $_->{users} } @$relevant;

     $this->flush_completely if $flush;
}

1;
