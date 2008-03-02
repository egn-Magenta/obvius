package WebObvius::Cache::StandardHashCache;

use Data::Dumper;
use strict;
use warnings;

sub new {
     my ($class, $obvius, %options) = @_;
     
     return bless {%options}, $class;
}

1;
