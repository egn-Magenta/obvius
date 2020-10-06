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
use Data::Dumper;

our @ISA = qw( Obvius::DocType );
our $VERSION="1.0";

sub action {
    my ($this, $input, $output, $doc, $vdoc, $obvius) = @_;

    unless($input->param('is_admin')) {
	my $uri = $obvius->get_doc_uri($doc);
	$obvius->log("Not serving HTML-page for image on public website: $uri");
	return OBVIUS_ERROR;
    }

    return OBVIUS_OK;
}

sub get_data {
    my ($this,$vdoc,$obvius) = @_;
    $obvius->get_version_fields($vdoc, ['data', 'uploadfile']);
    my $data;
    if (my $path = $vdoc->field('uploadfile')) {
        $path = $obvius->config->param('DOCS_DIR') . '/' . $path;
        $path =~ s!/+!/!g;
        my $fh;
        $path =~ s{\s+$}{}s;
        open($fh, $path) || die "File not found: $path";
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

    my @result;
    eval {
        @result = $this->raw_document_data_internal($doc, $vdoc, $obvius, $input);
    };
    if(my $error = $@) {
        if($obvius->config->param('upload_maintenance_mode')) {
            my $placeholder_image_path = $obvius->config->param(
                'upload_maintenance_placeholder_image_path'
            ) || '/var/www/obvius/docs/grafik/admin/1x1.gif';
            my $placeholder_image_mimetype = $obvius->config->param(
                'upload_maintenance_placeholder_image_mimetype'
            ) || 'image/gif';
            my $cache_placeholder_image = $obvius->config->param(
                'upload_maintenance_cache_placeholder_images'
            ) || 0;
            open(FH, $placeholder_image_path);
            local $/ = undef;
            my $data = <FH>;
            close(FH);
            @result = ("image/gif", $data);
            # Unless caching of placeholder images are enabled in config, make
            # sure the placeholder image is not cached.
            if(!$cache_placeholder_image &&
                $input && $input->UNIVERSAL::can("notes")) {
                $input->notes(nocache => 1);
            }
        } else {
            die $error;
        }
    }

    return @result;
}

my %sizes = (
    'ombud'         => '90x90',
    'navigator'     => '50x62',
    'icon'          => '55x55',
    'bootstrapform' => '100x',
    'globalmenu'    => '115x',
    'rightbox'      => '235x',
    'listlayout'    => '755x'
);
my %reverse_sizes = reverse(%sizes);

sub valid_qs {
    my ($qs) = @_;
    if ($qs =~ m/^(?:re)?size=(\w+)$/) {
        return valid_size($1);
    }
    return 0;
}

sub valid_size {
    my ($size) = @_;
    if (exists($sizes{$size})) {
        return $sizes{$size};
    }
    if (exists($reverse_sizes{$size})) {
        return $size;
    }
    return undef;
}


sub raw_document_data_internal {
    my ($this, $doc, $vdoc, $obvius, $input) = @_;

    $this->tracer($doc, $vdoc, $obvius) if ($this->{DEBUG});

    # Check for sized data
    if($input) {
        my $sized_data;
        # Handle childish $input behavior :)
        my $apr = ref($input) eq 'Apache' ? Apache::Request->new($input) : $input;

        my $size = $apr->param('size') || '';
        my $resize = $apr->param('resize') || '';

        my $valid_size = valid_size($size);
        if ($valid_size) {
            return $this->get_resized_data($valid_size, $vdoc, $obvius, $apr, 1);
        }
        $valid_size = valid_size($resize);
        if ($valid_size) {
            return $this->get_resized_data($valid_size, $vdoc, $obvius, $apr, 0);
        }

    }

    my $fields = $obvius->get_version_fields($vdoc, ['mimetype']);
    return ($fields->param('mimetype'), $this->get_data($vdoc, $obvius));
}

sub get_resized_data {
    my($this, $size, $vdoc, $obvius, $r, $use_legacy_version) = @_;

    my $cachedir = $obvius->config->param('CACHE_DIRECTORY');

    my $image_cache_dirname = $use_legacy_version ? '/sizedimagecache/' : '/resizedimagecache/';
    my $imagedir = $cachedir . $image_cache_dirname . $vdoc->DocId . '/' . $vdoc->Version . '/';

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


        if($size =~ /^(\d+)x(\d+)$/i) {
            $new_width = $1;
            $new_height = $2;
        } elsif (defined($org_width) && defined($org_height)) {
            if ($size =~ /^(\d+)%$/) {
                $new_width = $org_width * $1 / 100;
                $new_height = $org_height * $1 / 100;
            } elsif ($size =~ /^(\d+)x$/i) {
                $new_width = $1;
                $new_height = $org_height * ($new_width / $org_width);
            } elsif ($size =~ /^x(\d+)$/i) {
                $new_height = $1;
                $new_width = $org_width * ($new_height / $org_height);
            } else {
                $new_width = $org_width;
                $new_height = $org_height;
            }
        }

        # Set initial mimetype; can be overridden with GIF later
        my $mimetype = $obvius->get_version_field($vdoc, 'mimetype');
        my $final_image;

        if(!defined($new_width) || !defined($new_height) || ($new_width == $org_width && $new_height == $org_height)) {
            # Dont perform any scaling
            $final_image = $image;
        } else {
            my ($scaled_width, $scaled_height) = (0, 0);
            if ($use_legacy_version) {
                # Scale the image
                $image->Scale(width => $new_width, height => $new_height);

                # Get the new scaled sizes
                ($scaled_width, $scaled_height) = $image->Get('width', 'height');
            }

            if($scaled_width == $new_width and $scaled_height == $new_height) {
                $final_image = $image;
            } else {
                my $new_img;
                if ($use_legacy_version) {
                    $new_img = $this->convert_to_gif($image, $new_width, $new_height);
                    $mimetype = 'image/gif';
                } else {
                    my $quality = $obvius->config->param('image_quality') || 60;
                    $new_img = $this->resize_image($image, $new_width, $new_height, $quality);
                }

                # Set $image to the new one
                $final_image = $new_img;
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

sub convert_to_gif {
    my ($this, $image, $width, $height) = @_;

    # Make a transparent image exactly width x height (eg. gif type)
    my $new_img = Image::Magick->new();
    $new_img->Set(size=>"${width}x${height}");

    # Add frames one by one.
    for(my $i=0; $image->[$i]; $i++) {
        $new_img->ReadImage('xc:magenta');
        $new_img->Transparent(color=>'magenta');

        # Add the old, resized image to the new one and center it
        $new_img->[$i]->CompositeImage(compose=>'Over', image=>$image->[$i], width=>$width, height=>$height, gravity=>'Center');
    }

    return $new_img;
}

sub resize_image {
    my ($this, $image, $width, $height, $quality) = @_;

    # Only try to set quality if dealing with jpg images
    if ($quality && $image->Get('mime') eq 'image/jpeg') {
        $image->Set(quality => $quality);
    }
    $image->Resize(width => $width, height => $height);
    return $image;
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
