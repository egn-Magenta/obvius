package Obvius::DocType::Image;

########################################################################
#
# Image.pm - document type representing an Image; includes thumbnailing.
#
# Copyright (C) 2001-2004 Magenta Aps, Denmark (http://www.magenta-aps.dk/)
#                         aparte A/S, Denmark (http://www.aparte.dk/),
#                         FI, Denmark (http://www.fi.dk/)
#
# Authors: Jason Armstrong,
#          Jørgen Ulrik B. Krag (jubk@magenta-aps.dk)
#          René Seindal,
#          Adam Sjøgren (asjo@magenta-aps.dk),
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2, or (at your option)
# any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software Foundation,
# Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
#
########################################################################

# $Id$

use strict;
use warnings;

use Obvius;
use Obvius::DocType;

use Image::Magick;
use File::Path;

our @ISA = qw( Obvius::DocType );
our $VERSION="1.0";

sub get_data {
    my ($this,$vdoc,$obvius) = @_;
    $obvius->get_version_fields($vdoc, ['data', 'uploadfile']);
    my $data;
    if (my $path = $vdoc->field('uploadfile')) {
	$path = $obvius->{OBVIUS_CONFIG}{DOCS_DIR} . '/' . $path;
	$path =~ s!/+!/!g;
	my $fh;
	open $fh, $path || die "File not found: $path";
	eval {
	    local $/ = undef;
	    $data = <$fh>;
	};
	close $fh;
	if ($@) {
	    die $@;
	}
    } else {
	$data = $vdoc->field('data');
    }
    return $data;
}
	
    
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

    my $fields = $obvius->get_version_fields($vdoc, ['mimetype']);
    return ($fields->param('mimetype'), $this->get_data($vdoc, $obvius));
}

sub get_resized_data {
    my($this, $size, $vdoc, $obvius, $r) = @_;

    my $siteobj = $r->pnotes('site');
    my $cachedir = $obvius->{OBVIUS_CONFIG}{CACHE_DIRECTORY};

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
        my $org_data = $this->get_data($vdoc, $obvius);

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
            # requesting huge pictures. The 300px limit can be
            # overruled in the config file with max_image_width and
            # max_image_height.
            $new_width = 300 if($new_width > ($obvius->config->param('max_image_width') || 300));
            $new_height = 300 if($new_height > ($obvius->config->param('max_image_height') || 300));

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

# create_new_version_handler - doesn't do anything. Why it is still
#                              here is hard to tell.
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

=head1 NAME

Obvius::DocType::Image - Perl module handling images in Obvius.

=head1 SYNOPSIS

  use'd automatically by Obvius

=head1 DESCRIPTION

The Image document type provides a raw_document_data()-method instead
of an action, because an Image document doesn't return a piece of
(X)HTML to be included in a page, but rather provides an image-file.

If the parameter "size" is given, a scaled version - "thumbnail" - of
the image is returned.

TODO: Image::Magick has a tendency to segfault when scaling/handling
      animated gifs, so skipping scaling of such images might be in
      order. Perhaps look at MCMS::DocType::Image to see how it is
      done there.

META: Document how the scaled versions are stored, maintained and
      retrieved.

=head2 DEPENDS

L<Image::Magick>

=head2 EXPORT

None by default.

=head1 AUTHOR

Jason Armstrong
Jørgen Ulrik B. Krag <gt>jubk@magenta-aps.dk<lt>
René Seindal
Adam Sjøgren <gt>asjo@magenta-aps.dk<lt>

=head1 SEE ALSO

L<Obvius::DocType>, L<Image::Magick>.

=cut
