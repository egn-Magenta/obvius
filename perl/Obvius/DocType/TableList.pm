package Obvius::DocType::TableList;

# $Id$

use strict;
use warnings;

use Obvius;
use Obvius::DocType;

our @ISA = qw( Obvius::DocType );
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub action {
    my ($this, $input, $output, $doc, $vdoc, $obvius) = @_;

    return OBVIUS_OK;
}

sub alternate_location {
    my ($this, $doc, $vdoc, $obvius) = @_;

    $this->tracer($doc, $vdoc, $obvius) if ($this->{DEBUG});

    $obvius->get_version_fields($vdoc);

    my $url = $vdoc->field('url');
    return undef unless ($url);

    my $content = $vdoc->field('content');
    return (defined $content and length($content) == 0) ? $url : undef;
}

1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Obvius::DocType::TableList - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Obvius::DocType::TableList;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Obvius::DocType::TableList, created by h2xs. It looks like the
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
