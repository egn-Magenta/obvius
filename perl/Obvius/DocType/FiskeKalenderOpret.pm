package Obvius::DocType::FiskeKalenderOpret;

########################################################################
#
# FiskeKalenderOpret.pm - Calendar Event Document Type
#
# Copyright (C) 2002 aparte, Denmark (http://www.aparte.dk/)
#
# Author: Mads Kristensen
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

    if ($mode eq "save") {
	# validate the input
	if (!$this->validate_input($input)) {
	    return OBVIUS_OK;
	}

	# insert the document and publish it
	my $parent_path = $obvius->get_version_field($vdoc, 'base') || '/';

	if (my $new_vdoc = $this->save_document($input, $output, $obvius, $parent_path)) {
	    my $return = {
			  username => $new_vdoc->{DOCID},
			  password => $input->{PASSWORD},
			 };
	    $output->param('clear_cache'=>1);
	    $output->param(return=>$return);
	} else {
	    return OBVIUS_OK;
	}

	# all is great, set new mode
	$mode = "thanks";
    } else {
	my $kalender_doctype = $obvius->get_doctype_by_name('FiskeKalenderArrangement');
	my $where = "type = " . $kalender_doctype->param('ID') . " and fradato >= \'" . strftime('%Y-%m-%d', localtime) . "\'";

	my $is_admin = $input->param('IS_ADMIN');
	
	my %options = (
		       order=>" fradato, title ",
		       public => !$is_admin,
		       notexpired => !$is_admin,
		       append=> "limit 5"
		      );

        $output->param(Obvius_DEPENDENCIES => 1);
	my $result = $obvius->search(['title', 'fradato'], $where, %options);
	$result = [] unless($result);

	for (@$result) {
	    my $resultdoc = $obvius->get_doc_by_id($_->{DOCID});
	    $_->{URL} = $obvius->get_doc_uri($resultdoc);
	}
	$result = [] unless $result;

	$output->param("next_events" => $result);
    }
    $output->param(mode=>$mode);
    return OBVIUS_OK;
}

sub validate_input {
    my ($this, $input) = @_;

    # the rest has been validated in javascript, so only check the dates
    # (if people would cheat the system, they're welcome, as long as the date is correct)
    return 0 unless ($input->{FRADATO} =~ /\d\d-\d\d-\d\d\d\d/);
    return 0 unless ($input->{TILDATO} =~ /\d\d-\d\d-\d\d\d\d/);
    return 1;
}


sub save_document {
    my ($this, $input, $output, $obvius, $parent_path) = @_;

    my $fields = $this->return_fields($input);

    my $parent = ($obvius->get_doc_by_path($parent_path))[-1] || return 0;
    my $kalender_ar = $obvius->get_doctype_by_name("FiskeKalenderArrangement");
    $output->param(Obvius_DEPENDENCIES => 1);
    my $arrangement_doc = $obvius->search(['title'],
				  " parent = " . $parent->Id . " and type= " . $kalender_ar->Id,
				  needs_document_fields => ['parent', 'name']
				 );

    my $name = 0;
    if ($arrangement_doc && @$arrangement_doc) {
	for (@$arrangement_doc) {
	    if ($_->{NAME} > $name) {
		$name = $_->{NAME};
	    }
	}
    }
    $name++;

    # save the image
    if ($input->{_INCOMING_PICTURE}) {
	$this->create_image($output, $obvius, $parent, $name, $input->{_INCOMING_PICTURE});
	$fields->param('picture' => "$parent_path$name" . ".jpg");
    }

    # insert the document
    my $backup_user = $obvius->{USER};
    $obvius->{USER} = 'admin';
    $output->param(Obvius_SIDE_EFFECTS => 1);
    my @doc = $obvius->create_new_document($parent, $name, $kalender_ar->Id, "da", $fields, 'admin', 'admin') or die "Cannot create doc: $name";
    $obvius->{USER} = $backup_user;

    my $new_doc = $obvius->get_doc_by_id($doc[0]);
    my $new_vdoc = $obvius->get_latest_version($new_doc);

    my @fields = keys %{$kalender_ar->publish_fields};
    $obvius->get_version_fields($new_vdoc, \@fields,'PUBLISH_FIELDS');

    $new_vdoc->{PUBLISH_FIELDS}->{PUBLISHED}=strftime('%Y-%m-%d %H:%M:%S', localtime);
    $obvius->{USER} = 'admin';
    $obvius->publish_version($new_vdoc);
    $obvius->{USER} = $backup_user;

    $output->param('new_url'=>"$parent_path$name/");
    $output->param('new_title'=>$fields->param('title'));

    return ($new_vdoc);
}

# used internally by save_document and save_version
sub return_fields {
    my ($this, $input) = @_;
    my $fields = new Obvius::Data;
    # indsætter felter på objektet (tjek editpages.txt)
    $fields->param('expires'=>'9999-01-01 00:00:00');
    $fields->param('seq'=>'-10.00');

    $fields->param('title'=>escape_html($input->{TITLE}));
    $fields->param('short_title'=>escape_html($input->{TITLE}));
    $fields->param('tema'=>escape_html($input->{TEMA}));
    $fields->param('adresse'=>escape_html($input->{ADRESSE}));

    $fields->param('fradato' => format_date($input->{FRADATO}));
    $fields->param('tildato' => format_date($input->{TILDATO}));

    $fields->param('frakl'=>escape_html($input->{FRAKL}));
    $fields->param('tilkl'=>escape_html($input->{TILKL}));
    $fields->param('teaser'=>escape_html($input->{TEASER}));
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
    my ($this, $output, $obvius, $doc, $name, $data, $version, $size)= @_;

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

    $output->param(Obvius_SIDE_EFFECTS => 1);
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
#    s/&/&amp;/g;
#    s/</&lt;/g;
#    s/>/&gt;/g;
#    s/\"/&quot;/g;
#    s/\n/<br>/g;
#    return $_;
}


1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Obvius::DocType::FiskeKalenderOpret - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Obvius::DocType::FiskeKalenderOpret;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Obvius::DocType::FiskeKalenderOpret, created by h2xs. It looks like the
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
