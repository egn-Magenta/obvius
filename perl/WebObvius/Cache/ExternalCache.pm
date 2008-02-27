package WebObvius::Cache::ExternalCache;

use strict;
use warnings;

our @ISA = qw( WebObvius::Cache::ApacheCache );
sub new {
     my ($class,  @args) = @_;
     
     my $new = $class->SUPER::new(@args);
     bless $new, $class;
}

1;
