package Obvius::DocType::EtikImage;

# $Id$

use strict;
use warnings;

use Obvius;
use Obvius::DocType;

our @ISA = qw( Obvius::DocType );
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub raw_document_data {
    my ($this, $doc, $vdoc, $obvius, $input) = @_;

    $this->tracer($doc, $vdoc, $obvius) if ($this->{DEBUG});

    # Check for sized data
    if($input) {
        my $sized_data;
        # Handle childish $input behavior :)
        my $apr = ref($input) eq 'Apache' ? Apache::Request->new($input) : $input;

        my $size = uc($apr->param('size'));
        use Data::Dumper;
        if($size and $size =~ /^\d+X\d+$/i and $this->{FIELDS}->{"DATA_" . $size}) { # Only if we actually support this size
            $sized_data = $obvius->get_version_field($vdoc, "DATA_" . $size);

            # Converted pictures are always gifs
            return('image/gif', $sized_data) if($sized_data);
        }
    }

    my $fields = $obvius->get_version_fields($vdoc, ['mimetype', 'data']);
    return ($fields->param('mimetype'), $fields->param('data'));
}

1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Obvius::DocType::EtikImage - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Obvius::DocType::Image;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Obvius::DocType::Image, created by h2xs. It looks like the
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
