package Obvius::DocType::Image;

# $Id$

use strict;
use warnings;

use Obvius;
use Obvius::DocType;

use Image::Magick;
use File::Path;

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

        my $size = $apr->param('size') || '';

        if($size and $size =~ /^(\d+X\d+|\d+%)$/i) {
            return $this->get_resized_data($size, $vdoc, $obvius, $apr);
        }
    }

    my $fields = $obvius->get_version_fields($vdoc, ['mimetype', 'data']);
    return ($fields->param('mimetype'), $fields->param('data'));
}

sub get_resized_data {
    my($this, $size, $vdoc, $obvius, $r) = @_;

    my $siteobj = $r->pnotes('site');
    my $cachedir = $siteobj->param('webobvius_cache_directory');

    my $imagedir = $cachedir . '/sizedimagecache/' . $vdoc->DocId . '/' . $vdoc->Version . '/';

    my $cachefile = $imagedir . $size;

    my $data;

    if(-f $cachefile and -f "$cachefile.mimetype") {

        # Read mimetype
        open(FH, "$cachefile.mimetype");
        my $mimetype = <FH>;
        close(FH);

        # Read image data
        local $/ = undef;
        open(FH, $cachefile);
        $data = <FH>;
        close(FH);

        return($mimetype, $data);
    } else {
        my $org_data = $obvius->get_version_field($vdoc, 'data');

        my $image = Image::Magick->new;
        $image->BlobToImage($org_data);

        my ($org_width, $org_height) = $image->Get('width', 'height');

        my ($new_width, $new_height);

        if($size =~ /^(\d+)%$/) {
            $new_width = $org_width * $1 / 100;
            $new_height = $org_height * $1 / 100;
        } elsif($size =~ /^(\d+)x(\d+)$/i) {
            $new_width = $1;
            $new_height = $2;
        } else {
            $new_width = $org_width;
            $new_height = $org_height;
        }

        my $mimetype;
        my $final_image;

        if($new_width == $org_width) {
            # Dont perform any scaling
            $mimetype = $obvius->get_version_field($vdoc, 'mimetype');
            $final_image = $image;
        } else {
            # Limit images to 300 pixels in both width and height
            # This is so outsiders can't bring the server down by
            # making requesting huge pictures.
            $new_width = 300 if($new_width > 300);
            $new_height = 300 if($new_height > 300);

            # Scale the image
            $image->Scale(geometry => $new_width . "x" . $new_height);

            # Get the new scaled sizes
            my ($scaled_width, $scaled_height) = $image->Get('width', 'height');

            # If the image already have the correct size don't change the
            # mimetype
            if($scaled_width == $new_width and $scaled_height == $new_height) {
                $mimetype = $obvius->get_version_field($vdoc, 'mimetype');
                $final_image = $image;
            } else {
                # Make a transparent image exactly width x height (eg. gif type)

                my $imagesize = $new_width . "x" . $new_height;
                my $new_img = Image::Magick->new();
                $new_img->Set(size=>$imagesize);

                # Add frames one by one.
                for(my $i=0; $image->[$i]; $i++) {
                    $new_img->ReadImage('xc:magenta');
                    $new_img->Transparent(color=>'magenta');

                    # Add the old, resized image to the new one and center it
                    $new_img->[$i]->CompositeImage(compose=>'Over', image=>$image->[$i], geometry=>$imagesize, gravity=>'Center');
                }

                # And set $image to the new one
                $final_image = $new_img;

                #These images should always have mimetype gif
                $mimetype = 'image/gif';
            }
        }

        # Make sure we have a path
        mkpath($imagedir) unless(-d $imagedir);

        # Write the image
        if($mimetype eq 'image/gif') {
            $final_image->Set(magick => 'GIF');
            $final_image->Write(filename => $cachefile, interlace => 'None');
        } else {
            $final_image->Write(filename => $cachefile);
        }

        # Free some mem before reading the picture again
        $final_image = undef;
        $image = undef;

        # Write the mimetype
        open(FH, ">$cachefile.mimetype");
        print FH $mimetype;
        close(FH);

        # Get the imagedata
        local $/ = undef;
        open(FH, "$cachefile");
        my $data = <FH>;
        close(FH);

        return($mimetype, $data);

    }
}

sub create_new_version_handler {
    my ($this, $fields, $obvius) = @_;

    # This used to create resized versions of the image and store it in
    # the database but that is no longer neccesary since resizing of
    # images is now handled on the fly.

    return OBVIUS_OK;
}

our %magick_map = (
                    'gif' => 'GIF',
                    'jpeg' => 'JPEG',
                    'png' => 'PNG'
                );

sub transform_image_at_upload() {
    my ($this, $fhref, $width, $height, $format, $quality) = @_;

    my $mimetype = ''; # Function returns mimetype of the generated picture

    my $image = Image::Magick->new;
    my $test = $image->Read(file=>$fhref);
    print STDERR "Error while reading image: $test\n" if($test);

    my ($old_width, $old_height) = $image->Get('width', 'height');

    my ($new_height, $new_width);

    if($width) {
        $width =~ m/^(\d+)(%?)$/;
        if($2) {
            # Set new width to the given percentage
            $new_width = int($old_width * $1 / 100);
        } elsif($1) {
            $new_width = $1;
        }
    }

    if($height) {
        $height =~ m/^(\d+)(%?)$/;
        if($2) {
            # Set new width to the given percentage
            $new_height = int($old_height * $1 / 100);
        } elsif($1) {
            $new_height = $1;
        }
    }

    if($new_width) {
        unless($new_height) {
            $new_height = int($old_height * ($new_width / $old_width));
        }
    } else {
        if($new_height) {
            $new_width = int($old_width * ($new_height / $old_height));
        } else {
            $new_height = $old_height;
            $new_width = $old_width;
        }
    }

    if($new_width != $old_width or $new_height != $old_height) {
        # Scale (and stretch) image to the chosen width and height
        $image->Scale(geometry => $new_width . "x" . $new_height . "!");
    }



    my %options;

    $format ||='';

    my $magick;
    if($magick = $magick_map{$format}) {
        $options{'magick'} = $magick;
        $mimetype = "image/$format";
    }

    if(defined($quality) and $quality =~ /^\d+$/) {
        $options{'quality'} = $quality;
    }

    $magick ||= lc($image->Get('magick')) || 'gif';

#    print STDERR "\nWriting to blob\n";

    my $tmpfilename = "/tmp/obviusimage_$$.$magick";

    if($magick eq 'gif') {
        $image->Write(filename=>$tmpfilename);
    } else {
        $image->[0]->Write(filename=>$tmpfilename);
    }

    local $/ = undef;
    open(FH, $tmpfilename);
    my $value = <FH>;
    close(FH);

    unlink($tmpfilename);

    return ($value, $mimetype);

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
