package Obvius::DocType::Image;

# $Id$

use strict;
use warnings;

use Obvius;
use Obvius::DocType;

use Image::Magick;

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
        if($size and $size =~ /^\d+X\d+$/i and $this->{FIELDS}->{"DATA_" . $size}) { # Only if we actually support this size
            $sized_data = $obvius->get_version_field($vdoc, "DATA_" . $size);

	    # We're caching these now (WebObvius::Site::Mason):
	    # (when we weren't it was important to have this, because otherwise
	    #  the thumbnail would be put in the cache and mistaken for the big
	    #  picture - i.e. poluting the cache).
	    # $input->no_cache(1);

            # Converted pictures are always gifs
            return('image/gif', $sized_data) if($sized_data);
        }
    }

    my $fields = $obvius->get_version_fields($vdoc, ['mimetype', 'data']);
    return ($fields->param('mimetype'), $fields->param('data'));
}

sub create_new_version_handler {
    my ($this, $fields, $obvius) = @_;

    my @image_data_fields = grep { $_ =~ /^DATA_\d+X\d+$/i } keys %{$this->{FIELDS}};
    for(@image_data_fields) {
        # Skip the field if it is already there
        next if($fields->param($_));
        
        # Get width and height
        my ($width, $height) = (/DATA_(\d+)X(\d+)/i);
        my $data = $fields->param('data');


        # Generate image data
        my $imagesize = $width . "x" . $height;

        my $image = Image::Magick->new;

        # Read picture from data blob
        $image->BlobToImage($data);

        # Resize picture
        $image->Resize(geometry=>$imagesize, filter=>'Bessel', blur=> 0.01);

        # Now we have a picture that fits inside a width x height frame and isn't stretched.

        # Make a transparent image exactly width x height
        my $new_img = Image::Magick->new();
        $new_img->Set(size=>$imagesize);
        $new_img->ReadImage('xc:white');
        $new_img->Transparent(color=>'white');

        # Add the old, resized image to the new one and center it
        $new_img->CompositeImage(compose=>'Over', image=>$image, geometry=>$imagesize, gravity=>'Center');

        # Hmmm, there might be a better way :)
        $new_img->Write(filename => '/dev/null/blah.gif', interlace => 'None');

        # Return the new image
        my @blobs = $new_img->ImageToBlob();

        $fields->param($_ => $blobs[0]);
    }

    return OBVIUS_OK;

}

1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Obvius::DocType::Image - Perl extension for blah blah blah

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
