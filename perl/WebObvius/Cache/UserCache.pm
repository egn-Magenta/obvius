package WebObvius::Cache::UserCache;

use warnings;
use strict;

use Data::Dumper;
use WebObvius::Cache::FileCache;

our @ISA = qw( WebObvius::Cache::FileCache );


sub new {
     my ($class, $obvius) = @_;
     return $class->SUPER::new($obvius, 'user_data');
}

sub find_and_flush {
     my ($this, $cache_objects) = @_;

     my $relevant = $cache_objects->request_values('users');
     
     my $flush = grep { $_->{users} } @$relevant;

     $this->flush_completely if ($flush);
}

1;
