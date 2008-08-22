package Obvius::DocType::InternalProxy;

use strict;
use warnings;

our @ISA = qw( Obvius::DocType );
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub can_preview {
     return 0;
}

1;
