package Obvius::DocType::Fiskevand_forside;

########################################################################
#
# Fiskevand_forside.pm - Fiskevand_forside Document Type
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
use Net::SMTP;


our @ISA = qw( Obvius::DocType );
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub action {
    my ($this, $input, $output, $doc, $vdoc, $obvius) = @_;

    if ($input->{MODE} and $input->{MODE} eq 'edit') {
	my $fiskevand_doctype = $obvius->get_doctype_by_name("Fiskevand");
	my $fiskevand_doctypeid = $fiskevand_doctype->Id;

	my $edit_doc;
	$edit_doc = $obvius->get_doc_by_id($input->{DOCID}) if $input->{DOCID};
	my $edit_vdoc;
	$edit_vdoc = $obvius->get_public_version($edit_doc) if $edit_doc;

	return OBVIUS_OK unless $edit_vdoc;
	return OBVIUS_OK unless ($fiskevand_doctypeid == $edit_vdoc->Type);

	$obvius->get_version_fields($edit_vdoc, 256);
	$output->param(edit_vdoc=>$edit_vdoc);

    } elsif ($input->{MODE} and $input->{MODE} eq 'save_version') {
	my $docid = $input->{DOCID};
	my $vand_doc  = $obvius->get_doc_by_id($docid);
	my $vand_vdoc = $obvius->get_public_version($vand_doc);
	my $changes = $this->save_version($input, $obvius, $vand_doc, $vand_vdoc);

	my $url   = $obvius->get_doc_uri($vand_doc);
	my $title = $obvius->get_version_field($vand_vdoc, 'title');
	$output->param('docurl'=>$url);
	$output->param('doctitle'=>$title);

	# do not send any mail if there is no changes
	return OBVIUS_OK unless (@$changes);

	# everything is ok, send a mail to the administrator
	my $mail = $obvius->get_version_field($vdoc, 'mailadr');

	$this->send_change_mail($mail, "webmaster\@sportsfiskerforbundet.dk", $title, $url, $changes);

	$output->param('clear_cache' => 1);
    }
    return OBVIUS_OK;
}

sub save_version {
    my ($this, $input, $obvius, $doc, $vdoc) = @_;

    my $fields = new Obvius::Data;
    $fields = $obvius->get_version_fields($vdoc, 256);

    my @changed;
    # check to see what's been changed

    use Data::Dumper;

    # the imagetext is not neccessary
    my @datatypes = qw(adresse stedbetegnelse postnummer bynavn telefon fax hjemmeside mail adresse korselsvejl beskrivelse priser salgssteder fiskestrak fangstmulig abningstider);

#	print STDERR Dumper($fields);

    for (@datatypes) {
	# be sure to remove \r's
	$input->{uc($_)} =~ s/\r//g;
	$fields->{$_} =~ s/\r//g if ($fields->{$_});
	
	if ($input->{uc($_)} and ($input->{uc($_)} ne $fields->{uc($_)})) {
	    push (@changed, $_);
	}
    }

    $fields = $this->return_fields($input, $fields);

    # save the image
    if ($input->{_INCOMING_PICTURE}) {
	my $uri = $obvius->get_doc_uri($doc);
	$uri =~ s/\/$//;

	push (@changed, "BILLEDE");

	my $image_doc;
	if ($fields->param('billede')) {
	    $image_doc = ($obvius->get_doc_by_path($fields->param('billede')))[-1];
	}

	if ($image_doc) {
	    # vi har en ny version
	    $this->create_image($obvius, $image_doc, "", $input->{_INCOMING_PICTURE}, 1, $fields->param('billedtext'));
	} else {
	    # der skal oprettes et nyt billede
	    #my $parent = ($obvius->get_doc_by_id($doc->{PARENT}));
	    my $parent = $doc;
	    $this->create_image($obvius, $parent, "billede", $input->{_INCOMING_PICTURE}, 0, $fields->param('billedtext'));
	    my $uri = $obvius->get_doc_uri($doc);
	    $fields->param('billede'=> $uri . "billede.jpg");
	}
    }

    # save the new version if something has changed
    if (@changed) {
	my $backup_user = $obvius->{USER};
	$obvius->{USER} = 'admin';
	$obvius->create_new_version($doc, $doc->Type, "da", $fields);
	$obvius->{USER} = $backup_user;
    }
    return \@changed;

#    my $new_vdoc = $obvius->get_latest_version($doc);

#    my $fiskevand_ar = $obvius->get_doctype_by_name("Fiskevand");
#    my @fields = keys %{$fiskevand_ar->publish_fields};
#    $obvius->get_version_fields($new_vdoc, \@fields,'PUBLISH_FIELDS');
#
#    $new_vdoc->{PUBLISH_FIELDS}->{PUBLISHED}=strftime('%Y-%m-%d %H:%M:%S', localtime);
#    $obvius->{USER} = 'admin';
#    $obvius->publish_version($new_vdoc);
#    $obvius->{USER} = $backup_user;
}

# used internally by save_version
sub return_fields {
    my ($this, $input, $fields) = @_;
    # indsætter felter på objektet (tjek editpages.txt)
#    $fields->param('expires'=>'9999-01-01 00:00:00');
#    $fields->param('seq'=>'10.00');

    # editpages page 1
    $fields->param('adresse'=>escape_html($input->{ADRESSE}));
    $fields->param('stedbetegnelse'=>escape_html($input->{STEDBETEGNELSE}));
    $fields->param('postnummer'=>escape_html($input->{POSTNUMMER}));
    $fields->param('bynavn'=>escape_html($input->{BYNAVN}));
    $fields->param('telefon'=>escape_html($input->{TELEFON}));
    $fields->param('fax'=>escape_html($input->{FAX}));
    $fields->param('hjemmeside'=>escape_html($input->{HJEMMESIDE}));
    $fields->param('mail'=>escape_html($input->{MAIL}));
    $fields->param('adresse'=>escape_html($input->{ADRESSE}));
    $fields->param('korselsvejl'=>$input->{KORSELSVEJL});
    $fields->param('billedtext'=>escape_html($input->{BILLEDTEXT}));

    # editpages page 2
    $fields->param('beskrivelse'=>$input->{BESKRIVELSE});
    $fields->param('priser'=>escape_html($input->{PRISER}));
    $fields->param('salgssteder'=>$input->{SALGSSTEDER});
    $fields->param('fiskestrak'=>escape_html($input->{FISKESTRAK}));
    $fields->param('fangstmulig'=>escape_html($input->{FANGSTMULIG}));
    $fields->param('abningstider'=>escape_html($input->{ABNINGSTIDER}));


    return $fields;
}

sub create_image {
    my ($this, $obvius, $doc, $name, $data, $version, $billedtext)= @_;

    # Small hack: data_200x200 kommer til at indeholde thumbnail-versionen
    # data kommer til at indeholde hele billedet
    my $image_doctype=$obvius->get_doctype_by_name("Image");
    my $image_doctypeid = $image_doctype->Id;

    my $image = Image::Magick->new;

    # Read picture from data blob
    $image->BlobToImage($data->param('data'));

    # Resize image to be no more than $size pixels in width or height
    my ($image_height, $image_width) = $image->Get('height', 'width');
    my $org_height = $image_height;
    my $org_width = $image_width;

    my $size = 200;

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
    $fields->param('title'=>"billede");
    $fields->param('short_title'=>"billede");
    $fields->param('teaser'=>escape_html($billedtext));
    $fields->param('expires'=>'9999-01-01 00:00:00');
    $fields->param('seq'=>'-10.00');
    $fields->param('data' => $data->param('data'));
    $fields->param('data_200x200' => $imagedata);
    $fields->param('mimetype'=>$data->param('mimetype'));
    $fields->param('height'=>$org_height);
    $fields->param('width'=>$org_width);
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


#    my @fields = keys %{$image_doctype->publish_fields};
#    $obvius->get_version_fields($new_vdoc, \@fields,'PUBLISH_FIELDS');

#    $new_vdoc->{PUBLISH_FIELDS}->{PUBLISHED}=strftime('%Y-%m-%d %H:%M:%S', localtime);
#    $obvius->{USER} = 'admin';
#    $obvius->publish_version($new_vdoc);
#    $obvius->{USER} = $backup_user;

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
    return $_;
}

sub send_change_mail {
my ($this, $to, $from, $title, $url, $changes) = @_;    

my $change_text = "";
if (@$changes) {
    $change_text .= "Følgende KAN være ændret:\n";

    for (@$changes) {
	$change_text .= "$_ \n";
    }
}

my $message =<<EOF;
From: www.sportfiskeren.dk <$from>
Subject: Fiskevand ændret
To: $to

En bruger har været inde og rette på et fiskevand.
Det drejer sig om: $title
( http://www.sportsfiskeren.dk$url )

$change_text

Med venlig hilsen
www.sportsfiskeren.dk


EOF

my $mail_error;
my $smtp = Net::SMTP->new('localhost', Timeout=>30, Debug => 1);
$mail_error = "Kunne ikke angive afsender [$from]<br>"      unless ($smtp->mail($from));
$mail_error = "Kunne ikke angive modtager [$to]<br>"        unless ($mail_error or $smtp->to($to));
$mail_error = "Kunne ikke sende beskeden<br>"               unless ($mail_error or $smtp->data($message));
$mail_error = "Kunne ikke afslutte postprogram<br>"         unless ($mail_error or $smtp->quit);

return $mail_error;
}


1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Obvius::DocType::Fiskevand_forside - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Obvius::DocType::Fiskevand_forside;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Obvius::DocType::Fiskevand_forside, created by h2xs. It looks like the
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
