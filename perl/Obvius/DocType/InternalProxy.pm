package Obvius::DocType::InternalProxy;

use strict;
use warnings;

our @ISA = qw( Obvius::DocType );
our $VERSION="1.0";

sub can_preview {
     return 0;
}

1;
