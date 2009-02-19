# $Id$

package Obvius::FieldType::Regexp;

use 5.006;
use strict;
use warnings;

use Obvius::FieldType;

our @ISA = qw( Obvius::FieldType );
our $VERSION="1.0";

sub validate {
    my ($this, $obvius, $fspec, $value, $input) = @_;

    my $regexp = $this->{VALIDATE_ARGS};
    return (eval { $value =~ /$regexp/ }) ? $value : undef;
}



1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Obvius::FieldType::Regexp - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Obvius::FieldType::Regexp;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Obvius::FieldType::Regexp, created by h2xs. It looks like the
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
