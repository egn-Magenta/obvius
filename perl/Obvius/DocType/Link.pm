package Obvius::DocType::Link;

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

    my $url=$obvius->get_version_field($vdoc, 'url');
    return $url;

    # wtf?
    #my $content = $vdoc->field('content');
    #return (defined $content and length($content) == 0) ? $url : undef;
}

1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Obvius::DocType::Link - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Obvius::DocType::Link;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Obvius::DocType::Link, created by h2xs. It looks like the
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
