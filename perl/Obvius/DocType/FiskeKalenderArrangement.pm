package Obvius::DocType::FiskeKalenderArrangement;

########################################################################
#
# FiskeKalenderArrangement.pm - FiskeKalenderArrangement Document Type
#
# Copyright (C) 2001 Magenta Aps, Denmark (http://www.magenta-aps.dk/)
#
# Author: Mads Kristensen (mads@magenta-aps.dk)
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

use POSIX qw(strftime);

our @ISA = qw( Obvius::DocType );
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub action {
    my ($this, $input, $output, $doc, $vdoc, $obvius) = @_;

    my $mode = $input->param('mode') || '';
    if ($mode eq "login" or $mode eq "rediger") {
	my $password = $obvius->get_version_field($vdoc, 'password');
	
	if ($input->{PASSWORD} eq $password && $input->{USERNAME} eq $doc->Id) {
	    $mode = "rediger";
	} else {
	    $mode = "login";
	}
    } elsif ($mode eq "save") {
	$this->save_version($input, $obvius, $doc);
	$output->param('clear_cache' => 1);
    } elsif ($mode eq "delete") {
	$this->delete_document($obvius, $doc);
	print STDERR "\n\nSå skal der slettes\n\n\n";
	# delete this doc and the appropiate picture (if there is one)
    }

    $output->param(mode=>$mode);

    return OBVIUS_OK;
}

# also deletes the image
sub delete_document {
    my ($this, $obvius, $doc_to_delete) = @_;

    my $vdoc_to_delete = $obvius->get_public_version($doc_to_delete);
    $obvius->get_version_fields($vdoc_to_delete, ['picture']);

    if (($vdoc_to_delete->Picture) && ($vdoc_to_delete->Picture ne '/')) {
	my @imagedoc = $obvius->get_doc_by_path($vdoc_to_delete->Picture);
	my $imagedoc = $imagedoc[-1];
	# make sure it ends with .jpg
	if ($imagedoc->{NAME} =~ /\.jpg$/) {
	    $this->delete_document($obvius, $imagedoc);
	}
    }

    my $backup_user = $obvius->{USER};
    $obvius->{USER} = 'admin';
    $obvius->delete_document($doc_to_delete);
    $obvius->{USER} = $backup_user;
}

sub save_version {
    my ($this, $input, $obvius, $doc) = @_;

    my $fields = $this->return_fields($input);

    # save the image
    if ($input->{_INCOMING_PICTURE}) {
	my $uri = $obvius->get_doc_uri($doc);
	$uri =~ s/\/$//;
	$fields->param('picture'=> $uri . ".jpg");
	
	my $image_doc = ($obvius->get_doc_by_path($fields->param('picture')))[-1];
	if ($image_doc) {
	    # vi har en ny version
	    $this->create_image($obvius, $image_doc, "", $input->{_INCOMING_PICTURE}, 1);
	} else {
	    # der skal oprettes et nyt billede
	    my $parent = ($obvius->get_doc_by_id($doc->{PARENT}));
	    $this->create_image($obvius, $parent, $doc->{NAME}, $input->{_INCOMING_PICTURE});
	}
    }

    # save the new version
    my $backup_user = $obvius->{USER};
    $obvius->{USER} = 'admin';
    $obvius->create_new_version($doc, $doc->Type, "da", $fields);
    $obvius->{USER} = $backup_user;

    my $new_vdoc = $obvius->get_latest_version($doc);

    my $kalender_ar = $obvius->get_doctype_by_name("FiskeKalenderArrangement");
    my @fields = keys %{$kalender_ar->publish_fields};
    $obvius->get_version_fields($new_vdoc, \@fields,'PUBLISH_FIELDS');

    $new_vdoc->{PUBLISH_FIELDS}->{PUBLISHED}=strftime('%Y-%m-%d %H:%M:%S', localtime);
    $obvius->{USER} = 'admin';
    $obvius->publish_version($new_vdoc);
    $obvius->{USER} = $backup_user;
}

# used internally by save_version
# XXX using escape_html here is highly suspect!
sub return_fields {
    my ($this, $input) = @_;
    my $fields = new Obvius::Data;
    # indsætter felter på objektet (tjek editpages.txt)
    $fields->param('expires'=>'9999-01-01 00:00:00');
    $fields->param('seq'=>'-10.00');

    $fields->param('title'=>escape_html($input->{TITLE}));
    $fields->param('short_title'=>escape_html($input->{TITLE}));
    $fields->param('tema'=>$input->{TEMA});
    $fields->param('adresse'=>escape_html($input->{ADRESSE}));

    $fields->param('fradato' => format_date(escape_html($input->{FRADATO})));
    $fields->param('tildato' => format_date(escape_html($input->{TILDATO})));

    $fields->param('frakl'=>escape_html($input->{FRAKL}));
    $fields->param('tilkl'=>escape_html($input->{TILKL}));
    $fields->param('teaser'=>$input->{TEASER});
    $fields->param('arrangoer'=>escape_html($input->{ARRANGOER}));
    $fields->param('kontakt_navn'=>escape_html($input->{KONTAKT_NAVN}));
    $fields->param('kontakt_mail'=>escape_html($input->{KONTAKT_MAIL}));
    $fields->param('kontakt_tlf'=>escape_html($input->{KONTAKT_TLF}));
    $fields->param('hjemmeside'=>escape_html($input->{HJEMMESIDE}));
    $fields->param('password'=>$input->{PASSWORD});

    my @related;
    push (@related, $input->{CLAS_AMT})               if $input->{CLAS_AMT};
    push (@related, $input->{CLAS_ANDET})             if $input->{CLAS_ANDET};
    push (@related, $input->{CLAS_FISKEVAND})         if $input->{CLAS_FISKEVAND};
    push (@related, $input->{CLAS_MILJO_OG_POLITIK})  if $input->{CLAS_MILJO_OG_POLITIK};
    push (@related, $input->{CLAS_FISKEMETODE})       if $input->{CLAS_FISKEMETODE};
    push (@related, $input->{CLAS_LAND})              if $input->{CLAS_LAND};

    $fields->param('category' => \@related);
    return $fields;
}

sub create_image {
    my ($this, $obvius, $doc, $name, $data, $version, $size)= @_;

    my $image_doctype=$obvius->get_doctype_by_name("Image");
    my $image_doctypeid = $image_doctype->Id;

    my $image = Image::Magick->new;

    # Read picture from data blob
    $image->BlobToImage($data->param('data'));

    # Resize image to be no more than $size pixels in width or height
    my ($image_height, $image_width) = $image->Get('height', 'width');

    $size = 200 unless ($size);

    if ($image_width > $size) {
	my $cut = $image_width - $size;
	my $cut_percentage = ($cut/$image_width);
	$image_height = int($image_height*(1-$cut_percentage));
	$image_width = int($image_width*(1-$cut_percentage));
    }

    if ($image_height > $size) {
	my $cut = $image_height - $size;
	my $cut_percentage = ($cut/$image_height);
	$image_height = int($image_height*(1-$cut_percentage));
	$image_width = int($image_width*(1-$cut_percentage));
    }
    $image->Resize(width=>$image_width, height=>$image_height, filter=>'Bessel', blur=> 0.01);
    my $imagedata = $image->ImageToBlob();

    my $fields = new Obvius::Data;
    # indsætter felter på objektet (tjek editpages.txt)
    $fields->param('title'=>$name . ".jpg");
    $fields->param('short_title'=>$name);
    $fields->param('expires'=>'9999-01-01 00:00:00');
    $fields->param('seq'=>'-10.00');
    $fields->param('data' => $imagedata);
    $fields->param('mimetype'=>$data->param('mimetype'));
    $fields->param('height'=>$image_height);
    $fields->param('width'=>$image_width);
    $fields->param('docdate' => strftime('%Y-%m-%d', localtime));

    my $backup_user = $obvius->{USER};
    $obvius->{USER} = 'admin';

    my $new_vdoc = undef;
    my $new_doc = undef;

    if ($version) {
	my $temp = $obvius->create_new_version($doc, $image_doctypeid, "da", $fields) or
	    die "Cannot create version (create_image)";
	$new_vdoc = $obvius->get_latest_version($doc);
	$new_doc = $doc;
    } else {
	my @doc = $obvius->create_new_document($doc, $name . ".jpg", $image_doctypeid, "da", $fields, 'admin', 'admin') or
	    die "Cannot create doc: ${name}.jpg";
	$new_doc = $obvius->get_doc_by_id($doc[0]);
	$new_vdoc = $obvius->get_latest_version($new_doc);
    }
    $obvius->{USER} = $backup_user;


    my @fields = keys %{$image_doctype->publish_fields};
    $obvius->get_version_fields($new_vdoc, \@fields,'PUBLISH_FIELDS');

    $new_vdoc->{PUBLISH_FIELDS}->{PUBLISHED}=strftime('%Y-%m-%d %H:%M:%S', localtime);
    $obvius->{USER} = 'admin';
    $obvius->publish_version($new_vdoc);
    $obvius->{USER} = $backup_user;

    return $obvius->get_doc_uri($new_doc);
}


sub format_date {
    my $date = shift;
    $date =~ /(\d\d)-(\d\d)-(\d\d\d\d)/;
    return $3 . "-" . $2 . "-" . $1;
}

sub escape_html {
    $_ = shift;
    s/&/&amp;/g;
    s/</&lt;/g;
    s/>/&gt;/g;
    s/\"/&quot;/g;
    s/\n/<br>/g;
    return $_;
}


1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Obvius::DocType::FiskeKalenderArrangement - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Obvius::DocType::FiskeKalenderArrangement;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Obvius::DocType::FiskeKalenderArrangement, created by h2xs. It looks like the
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
