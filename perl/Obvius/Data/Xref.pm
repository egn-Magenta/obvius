# $Id$

package Obvius::Data::Xref;

use 5.006;
use strict;
use warnings;

use Obvius::Data;

our @ISA = qw( Obvius::Data );
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub list_valid_keys {
    my ($this) = @_;

    return [ {id => $this->{ID}} ];
}



1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Obvius::Data::Xref - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Obvius::Data::Xref;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Obvius::Data::Xref, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head2 EXPORT

None by default.


=head1 AUTHOR

A. U. Thor, E<lt>a.u.thor@a.galaxy.far.far.awayE<gt>

=head1 SEE ALSO

L<perl>.

=cut
