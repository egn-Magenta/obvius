package Obvius::DocType::HTML;

# $Id$

use strict;
use warnings;

use Obvius;
use Obvius::DocType;

our @ISA = qw( Obvius::DocType );
our $VERSION="1.0";

sub action {
    my ($this, $input, $output, $doc, $vdoc, $obvius) = @_;

    return OBVIUS_OK;
}

1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Obvius::DocType::HTML - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Obvius::DocType::HTML;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Obvius::DocType::HTML, created by h2xs. It looks like the
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
