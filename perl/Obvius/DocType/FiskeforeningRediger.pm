package Obvius::DocType::FiskeforeningRediger;

########################################################################
#
# Standard.pm - Standard Document Type
#
# Copyright (C) 2001-2003 aparte, Denmark (http://www.aparte.dk/)
#
# Author: Mads Kristensen,
#         Adam Sjøgren (asjo@aparte-test.dk)
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
use Net::SMTP;

use POSIX qw(strftime);

our @ISA = qw( Obvius::DocType );
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub action {
    my ($this, $input, $output, $doc, $vdoc, $obvius) = @_;

    my $session = $input->param('SESSION') || {};

    if($session->{_session_id}) {
        $output->param('SESSION_ID' => $session->{_session_id});
    }

    my $mode = $input->param('mode') || "login";

    if ($mode eq "tilsend_password") {
	#tilsend passwordet
	my $parent_doc = $obvius->get_doc_by_id($doc->Parent);
	my $parent_vdoc;
	$parent_vdoc = $obvius->get_public_version($parent_doc) if ($parent_doc);
	$obvius->get_version_fields($parent_vdoc, [qw(admin_mail id)]) if ($parent_vdoc);

	my $to = $parent_vdoc->Admin_mail;
	my $from = "webmaster\@sportsfiskerforbundet.dk";

	my $message = $this->send_password_mail($to, $from, $parent_vdoc->Id);
	$mode= "login";
	$output->param('password_sendt'=>1);
	$output->param('message' => $message || "Passwordet er sendt til adressen $to");
    } elsif ($mode eq "choose_edit" and $session->{login} != $vdoc->Docid) {
	my $username = $input->{'USERNAME'};
	my $password = $input->{'PASSWORD'};

	my $parent_doc = $obvius->get_doc_by_id($doc->Parent);
	my $parent_vdoc;
	$parent_vdoc = $obvius->get_public_version($parent_doc) if ($parent_doc);
	$obvius->get_version_fields($parent_vdoc, [qw(id password)]) if ($parent_vdoc);

	if (($username eq "dsf" || $username eq "DSF") and ($password eq $parent_vdoc->{FIELDS}->{ID})) {
	    $mode = "choose_edit";

	    $session->{login} = $vdoc->Docid;
	    $session->{data} = $this->fill_session($parent_vdoc, $obvius);

	    # save the session on the disk
	    $output->param('SESSION' => $session);

	    # Make session notice the changes to ->{login}
	    $session->{login} = $session->{login};
	}
	else {
	    $mode = "login";
	}
    }
    elsif ($session->{login} == $vdoc->Docid) {
        my $page=$input->param('page') || '';
        if ($page) {
            if ($page =~ /^(formand|kasserer|klublokale|medlem)$/) {
                $session->{data}->{$page} = $this->upgrade_session($input, $page);
                $session->{data} = $session->{data};
            }
            elsif ($page eq "klubben") {
                $session->{data}->{klubben} = $this->upgrade_session_klubben($input, "klubben", $obvius);
                $session->{data} = $session->{data};
            }
            elsif ($page eq "fiskesteder") {
                $session->{data}->{fiskesteder} = $this->upgrade_session_fiskesteder($input, "fiskesteder");
                $session->{data} = $session->{data};
            }
            elsif ($page eq "andet") {
                $session->{data}->{andet} = $this->upgrade_session_andet($input, "andet");
                $session->{data} = $session->{data};
            }
        }

	# save the data about the club
	if ($input->param('mode') eq "save_version") {
	    my $error = $this->save_version($session, $obvius);
	    $output->param('error' => $error);
	    $output->param('notify_message' => 'Dine ændringer til klubben er nu gemt');
            $output->param('send_email_notification'=>1);
	    $mode = "choose_edit";
	    $output->param('clear_cache' => 1);
	}

	# get the default data about the club
	if ($input->param('mode') eq "choose_edit") {
	    my $parent_doc = $obvius->get_doc_by_id($doc->Parent);
	    my $parent_vdoc;
	    $parent_vdoc = $obvius->get_public_version($parent_doc) if ($parent_doc);

	    $session->{data} = $this->fill_session($parent_vdoc, $obvius);
	    $session->{data} = $session->{data};
	}

	# save the new version of the nyhed
	if (($page eq "edit_nyhed" || $page eq "edit_arrangement")
	    && $this->is_subdoc($obvius, $input->param('docid'), $session->{login})) {

	    my $input_doc = $obvius->get_doc_by_id($input->param('docid'));
	    my $input_vdoc = $obvius->get_public_version($input_doc);
	    $obvius->get_version_fields($input_vdoc, [qw(picture title)]);
	    my $picture = $input_vdoc->Picture;
	    $input->{'PICTURE'} = $picture;

	    if (my $data = $input->param('_incoming_picture')) {
		# we've got a new picture
		if ($picture) {
		    my @image_doc = $obvius->get_doc_by_path($picture);
		    my $image_doc_name = $image_doc[-1]->{'NAME'};
		    $image_doc_name =~ s/\.jpg$//;

		    $this->create_image($obvius, $image_doc[-1], $image_doc_name, $data, "1");
		} else {
		    my $parent_doc = $obvius->get_doc_by_id($input_doc->{'PARENT'});
		    my $path = $obvius->get_doc_uri($input_doc);
		    $path =~ s#/$#\.jpg#;
		    $input->{'PICTURE'} = $path;

		    $this->create_image($obvius, $parent_doc, $input_doc->{'NAME'}, $data);
		}

	    }
	    $this->change_version_seq ($obvius, $input->param('docid'), "1", $input);

	    $mode = "nyheder_vis";
	    if ($page =~ /arrangement/) {
		$mode = "arrangementer_vis";
	    }
	    $output->param('clear_cache' => 1);
	}

	# save the FiskeforeningNyhed
	if ($page eq "opret_nyhed") {
	    my $error = $this->save_document($input, $obvius, "nyheder", "FiskeforeningNyhed");
	    $output->param($error);
	    $mode = "nyheder_vis";
	    $output->param('clear_cache' => 1);
	}

	# save the FiskeforeningArrangement
	if ($page eq "opret_arrangement") {
	    my $error = $this->save_document($input, $obvius, "arrangementer", "FiskeforeningArrangement");
	    $output->param($error);
	    $mode = "arrangementer_vis";
	    $output->param('clear_cache' => 1);
	}

	# en historie/arrangement slettes/skjules/offentliggøres
	if ($page eq "vis_dokumenter" && $this->is_subdoc($obvius, $input->param('version'), $session->{login})) {
	    if ($input->param('todo') eq "delete") {
		$this->delete_document($obvius, $input->param('version'), '1');
	    }
	    if ($input->param('todo') eq "hide") {
		$this->change_version_seq($obvius, $input->param('version'), "-1");
	    }
	    if ($input->param('todo') eq "publish") {
		$this->change_version_seq($obvius, $input->param('version'), "1");
	    }
	    if ($input->param('todo') eq "edit_arrangement") {
		my $return_doc = $obvius->get_doc_by_id($input->param('version'));
		my $return_vdoc = $obvius->get_public_version($return_doc);
		$output->param('edit_version'=>$return_vdoc);
		$mode = "arrangementer";
	    }
	    if ($input->param('todo') eq "edit_nyhed") {
		my $return_doc = $obvius->get_doc_by_id($input->param('version'));
		my $return_vdoc = $obvius->get_public_version($return_doc);
		$output->param('edit_version'=>$return_vdoc);
		$mode = "nyheder";
	    }
	    $output->param('clear_cache' => 1);
	}
    }
    else {
	# he's not invited :-)
	$mode = "login";
    }

    $output->param('mode' => $mode);
    $output->param('data' => $session->{data});
    return OBVIUS_OK;
}

sub fill_session {
    my ($this, $vdoc, $obvius) = @_;
    $obvius->get_version_fields($vdoc, 256);

    my %klubben = (
		   title =>         $vdoc->Title || '',
		   teaser =>        $vdoc->Teaser || '',
		   adresse=>        $vdoc->Adresse || '',
		   stedbetegnelse=> $vdoc->Stedbetegnelse || '',
		   postnummer=>     $vdoc->Postnummer || '',
		   bynavn =>        $vdoc->Bynavn || '',
		   telefon =>       $vdoc->Telefon || '',
		   fax =>           $vdoc->Fax || '',
		   hjemmeside=>     $vdoc->Hjemmeside || '',
		   mail =>          $vdoc->Mail || '',
		   klublogo =>      $vdoc->Klublogo || ''
		  );

    my %formand = (
		   formand_navn =>  $vdoc->Formand_navn || '',
		   formand_adresse => $vdoc->Formand_adresse || '',
		   formand_stedbetegnelse=> $vdoc->Formand_stedbetegnelse || '',
		   formand_postnummer => $vdoc->Formand_postnummer || '',
		   formand_bynavn => $vdoc->Formand_bynavn || '',
		   formand_telefon => $vdoc->Formand_telefon || '',
		   formand_mail => $vdoc->Formand_mail || '',
		  );

    my %kasserer = (
		   kasserer_navn =>  $vdoc->Kasserer_navn || '',
		   kasserer_adresse => $vdoc->Kasserer_adresse || '',
		   kasserer_stedbetegnelse=> $vdoc->Kasserer_stedbetegnelse || '',
		   kasserer_postnummer => $vdoc->Kasserer_postnummer || '',
		   kasserer_bynavn => $vdoc->Kasserer_bynavn || '',
		   kasserer_telefon => $vdoc->Kasserer_telefon || '',
		   kasserer_mail => $vdoc->Kasserer_mail || '',
		  );


    my %klublokale = (
		      lokale_navn =>  $vdoc->Lokale_navn || '',
		      lokale_adresse => $vdoc->Lokale_adresse || '',
		      lokale_stedbetegnelse=> $vdoc->Lokale_stedbetegnelse || '',
		      lokale_postnummer => $vdoc->Lokale_postnummer || '',
		      lokale_bynavn => $vdoc->Lokale_bynavn || '',
		     );

    my %medlem = (
		  medlemsoptagelse => $vdoc->Medlemsoptagelse || '',
		  medlemstegnere   => $vdoc->Medlemstegnere || '',
		  kontigent        => $vdoc->Kontigent || ''
		 );


    my %fiskesteder = (
		       kortsalg => $vdoc->Kortsalg || '',
		       rel_fiskesteder=>$vdoc->Rel_fiskesteder || []
		      );

    my %andet = (
		 password  => $vdoc->Id || '',
		 klubber   => $vdoc->Klubber || '',
		 admin_mail => $vdoc->Admin_mail || '',
		);


    return { 
	    klubben => \%klubben,
	    formand => \%formand,
	    kasserer => \%kasserer,
	    klublokale=> \%klublokale,
	    medlem =>\%medlem,
	    fiskesteder=>\%fiskesteder,
	    andet =>\%andet
	   };
}

sub upgrade_session {
    my ($this, $input, $upgrade) = @_;

    my $old_values = $input->{SESSION}->{data}->{$upgrade};

    my %new_values;
    for (keys %$old_values) {
	$new_values{$_} = $input->{uc($_)};
    }

    return \%new_values;
}

sub upgrade_session_klubben {
    my ($this, $input, $upgrade, $obvius) = @_;

    # if the logo should be deleted
    if ($input->{'DELETE_IMAGE'}) {
	$this->delete_document($obvius, $input->{'DELETE_IMAGE'});
	$input->{'KLUBLOGO'} = "";
    }

    # if there's a logo
    if(my $data = $input->param('_incoming_picture')) {
	if ($input->{'KLUBLOGO'} !~ /^(\/)$|^()$/) {
	    # it's an upgrade
	    my @image_doc = $obvius->get_doc_by_path(($input->param('klublogo')));
	    my $image_doc_name = $image_doc[-1]->{'NAME'};
	    $image_doc_name =~ s/\.jpg$//;
	    $this->create_image($obvius, $image_doc[-1], $image_doc_name, $data, "1", "150");
	} else {
	    # it's a new logo
	    my $edit_doc = $obvius->get_doc_by_id($input->{'SESSION'}->{login});
	    my $parent_doc = $obvius->get_doc_by_id ($edit_doc->{'PARENT'});

	    my $image_path = $this->create_image($obvius, $parent_doc, "logo", $data, "0", "150");

	    my $path = $obvius->get_doc_uri($parent_doc);
	    $path = $path . "logo.jpg";

	    $input->{'KLUBLOGO'} = $path;
	}
    }

    my $old_values = $input->{SESSION}->{data}->{$upgrade};

    my %new_values;
    for (keys %$old_values) {
	$new_values{$_} = $input->{uc($_)};
    }

    return \%new_values;
}

sub upgrade_session_andet {
    my ($this, $input, $upgrade) = @_;


    my $old_values = $input->{SESSION}->{data}->{$upgrade};

    $input->{'KLUBBER'} =~ s/\r//g;
    my @klubber = split /\n/, $input->{'KLUBBER'};
    map {$_ =~ s/\n//;} @klubber;

    my $password = $old_values->{'password'};
    if (($input->{'PASSWORD1'} eq $input->{'PASSWORD2'}) and (length($input->{'PASSWORD1'}) > 2)) {
	$password = $input->{'PASSWORD1'};
    }

    my %new_values;

    $new_values{'admin_mail'} = $input->{'ADMIN_MAIL'};
    $new_values{'kortsalg'} = $input->{'KORTSALG'};
    $new_values{'klubber'} = \@klubber;
    $new_values{'password'} = $password;

    return \%new_values;
}

sub upgrade_session_fiskesteder {
    my ($this, $input, $upgrade) = @_;

    my $old_values = $input->{SESSION}->{data}->{$upgrade};

    $input->{'REL_FISKESTEDER'} =~ s/\r//g;
    my @klubber = split /\n/, $input->{'REL_FISKESTEDER'};
    map {$_ =~ s/\n//;} @klubber;

    my %new_values;

    $new_values{'kortsalg'} = $input->{'KORTSALG'};
    $new_values{'rel_fiskesteder'} = \@klubber;

    return \%new_values;
}



sub save_version {
    my ($this, $session, $obvius) = @_;

    my $docid = $obvius->get_doc_by_id($session->{login});
    my $parent_doc = $obvius->get_doc_by_id($docid->Parent);
    my $parent_vdoc;
    $parent_vdoc = $obvius->get_public_version($parent_doc) if ($parent_doc);

    $obvius->get_version_fields($parent_vdoc, 255);
    my $docfields = $parent_vdoc->fields;

    # save all data on page "klubben"
    my $klubben = $session->{data}->{klubben};

    for (keys %$klubben) {
	$docfields->{uc($_)} = $klubben->{$_};
    }

    # save all data on page "formand"
    my $formand = $session->{data}->{formand};

    for (keys %$formand) {
	$docfields->{uc($_)} = $formand->{$_};
    }

    # save all data on page "kasserer"
    my $kasserer = $session->{data}->{kasserer};

    for (keys %$kasserer) {
	$docfields->{uc($_)} = $kasserer->{$_};
    }

    # save all data on page "klublokale"
    my $klublokale = $session->{data}->{klublokale};

    for (keys %$klublokale) {
	$docfields->{uc($_)} = $klublokale->{$_};
    }

    # save all data on page "bliv medlem"
    my $medlem = $session->{data}->{medlem};

    for (keys %$medlem) {
	$docfields->{uc($_)} = $medlem->{$_};
    }

    # save all data on page "fiskesteder"
    my $fiskesteder = $session->{data}->{fiskesteder};

    for (keys %$fiskesteder) {
	$docfields->{uc($_)} = $fiskesteder->{$_};
    }

    # save all data on page "andet"
    my $andet = $session->{data}->{andet};

    for (keys %$andet) {
	$docfields->{uc($_)} = $andet->{$_} unless ($_ eq 'password');
    }
    $docfields->{'ID'} = $andet->{'password'};

    my $backup_user = $obvius->{USER};
    $obvius->{USER} = 'admin';
    my $version = $obvius->create_new_version($parent_doc, $parent_vdoc->Type, $parent_vdoc->Lang, $docfields);
    $obvius->{USER} = $backup_user;

    my $error;
    unless($version) {
	$error = 'Fejl under oprettelse af ny version af lokalforeningen';
    } else {
	# Publish the version
	my $new_vdoc = $obvius->get_version($parent_doc, $version);
	
	my $publish_error;
	
	# Start out with som defaults
	$obvius->get_version_fields($new_vdoc, 255, 'PUBLISH_FIELDS');
	
	# Set published
	my $publish_fields = $new_vdoc->publish_fields;
	$publish_fields->param(PUBLISHED => strftime('%Y-%m-%d %H:%M:%S', localtime));
	
	$obvius->{USER} = 'admin';
	$obvius->publish_version($new_vdoc, \$publish_error);
	$obvius->{USER} = $backup_user;
	
	if($publish_error) {
	    $error = "Vi kunne ikke offentliggøre dit svar på grund af følgende fejl:\n$publish_error";
	}
    }
    return $error;
}

sub save_document {
    my ($this, $input, $obvius, $branchname, $doctypename) = @_;

    my $docid = $obvius->get_doc_by_id($input->{SESSION}->{login});
    my $parent_doc = $obvius->get_doc_by_id($docid->Parent);
    my $parent_vdoc;
    $parent_vdoc = $obvius->get_public_version($parent_doc) if ($parent_doc);

    my $nyhed_doc = $obvius->search(['title'],
				  " parent = " . $parent_doc->Id . " and title = \'" . $branchname . "\'",
				  public => 1,
				  notexpired => 1,
				  needs_document_fields => ['parent']
				 );

    my $fields = new Obvius::Data;
    # indsætter felter på objektet (tjek editpages.txt)
    $fields->param('title'=>ucfirst($branchname));
    $fields->param('short_title'=>ucfirst($branchname));
    $fields->param('expires'=>'9999-01-01 00:00:00');
    $fields->param('seq'=>'-10.00');
    $fields->param('docdate' => strftime('%Y-%m-%d', localtime));

    if ($nyhed_doc && @$nyhed_doc) {
	if ($input->{TITLE} && $input->{CONTENT}) {
	    my $lf_nyhed_doctype=$obvius->get_doctype_by_name($doctypename);
	    my $lf_nyhed_doctypeid = $lf_nyhed_doctype->Id;

	    $fields->param('title'=>$input->{TITLE});
	    $fields->param('seq'=>'1');
	    $fields->param('content'=>$input->{CONTENT});
            $fields->param('docdate' => $input->{DOCDATE}) if ($input->{DOCDATE});

	    my $nyhed_doc = $obvius->search( ['title'],
					   " parent = " . $parent_doc->Id . " and title = \'" . $branchname . "\'",
					   public => 1,
					   notexpired => 1,
					   needs_document_fields => ['parent']
					 );
	
	    my $parent_doc = $obvius->get_doc_by_id(@$nyhed_doc[0]->{'DOCID'});

	    my $nyhed_docs = $obvius->search( ['title'],
					   " parent = " . $parent_doc->Id . " and type=" . $lf_nyhed_doctypeid,
					   needs_document_fields => ['parent', 'name']
					 );

	    # find largest name
	    my $name = 0;
	    for (@$nyhed_docs) {
		if ($_->{NAME} > $name) {
		    $name = $_->{NAME};
		}
	    }
	    $name++;

	    $fields->param('short_title'=>$name);

	    if(my $data = $input->param('_incoming_picture')) {
		my $image_path = $this->create_image($obvius, $parent_doc, $name, $data);
		$fields->param('picture'=>$image_path);
	    }

	    my $backup_user = $obvius->{USER};
	    $obvius->{USER} = 'admin';
	    my @doc = $obvius->create_new_document($parent_doc, $name, $lf_nyhed_doctypeid, "da", $fields, 'admin', 'admin') or die "Cannot create doc: $name";
	    $obvius->{USER} = $backup_user;

	    my $new_doc = $obvius->get_doc_by_id($doc[0]);
	    my $new_vdoc = $obvius->get_latest_version($new_doc);

	    my @fields = keys %{$lf_nyhed_doctype->publish_fields};
	    $obvius->get_version_fields($new_vdoc, \@fields,'PUBLISH_FIELDS');
	
	    $new_vdoc->{PUBLISH_FIELDS}->{PUBLISHED}=strftime('%Y-%m-%d %H:%M:%S', localtime);
	    $obvius->{USER} = 'admin';
	    $obvius->publish_version($new_vdoc);
	    $obvius->{USER} = $backup_user;
	}
    }
    else {
	# the news-doc is inserted and we try again
	my $standarddoctype=$obvius->get_doctype_by_name("Standard");
	my $standardid = $standarddoctype->Id;

	my $backup_user = $obvius->{USER};
	$obvius->{USER} = 'admin';
	my @doc = $obvius->create_new_document($parent_doc, $branchname, $standardid, "da", $fields, 'admin', 'admin') 
	    or die "Cannot create doc: " . $branchname;
	$obvius->{USER} = $backup_user;

	my $new_doc = $obvius->get_doc_by_id($doc[0]);
	my $new_vdoc = $obvius->get_latest_version($new_doc);

	my @fields = keys %{$standarddoctype->publish_fields};
	$obvius->get_version_fields($new_vdoc, \@fields,'PUBLISH_FIELDS');

	$new_vdoc->{PUBLISH_FIELDS}->{PUBLISHED}=strftime('%Y-%m-%d %H:%M:%S', localtime);
	$obvius->{USER} = 'admin';
	$obvius->publish_version($new_vdoc);
	$obvius->{USER} = $backup_user;

	$this->save_document($input, $obvius, $branchname, $doctypename);
    }
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

# deletes the image as well
sub delete_document {
    my ($this, $obvius, $docid, $delete_image) = @_;

    my $doc_to_delete = $obvius->get_doc_by_id($docid);

    my $vdoc_to_delete = $obvius->get_public_version($doc_to_delete);
    $obvius->get_version_fields($vdoc_to_delete, ['picture']);

    if (($vdoc_to_delete->Picture) && ($vdoc_to_delete->Picture ne '/') && ($delete_image)) {
	my @imagedoc = $obvius->get_doc_by_path($vdoc_to_delete->Picture);
	my $imagedoc = $imagedoc[-1];
	# make sure it ends with .jpg
	if ($imagedoc->{NAME} =~ /\.jpg$/) {
	    $this->delete_document($obvius, $imagedoc->{ID});
	}
    }

    my $backup_user = $obvius->{USER};
    $obvius->{USER} = 'admin';
    $obvius->delete_document($doc_to_delete);
    $obvius->{USER} = $backup_user;
}

sub change_version_seq {
    my ($this, $obvius, $docid, $new_seq, $input) = @_;

    my $doc = $obvius->get_doc_by_id($docid);
    my $vdoc = $obvius->get_public_version($doc);

    $obvius->get_version_fields($vdoc, 256);
    my $existing_fields = $vdoc->{'FIELDS'};
    my $fields = new Obvius::Data;

    if ($input) {
	for (keys %$existing_fields) {
	    $fields->param(lc($_) => $input->{$_});
	}
	$fields->param('picture' => $input->{'PICTURE'});
	$fields->param('seq' => $existing_fields->{'SEQ'} || '1');
	$fields->param('expires'=> $existing_fields->{'EXPIRES'} || '1');
	$fields->param('short_title'=> $existing_fields->{'SHORT_TITLE'} || '1');
    } else {
	# just change the seq
	for (keys %$existing_fields) {
	    $fields->param(lc($_) => $existing_fields->{$_});
	}
	$fields->param('seq' => $new_seq);
    }

    my $backup_user = $obvius->{USER};
    $obvius->{USER} = 'admin';
    my $temp = $obvius->create_new_version($doc, $vdoc->Type, $vdoc->Lang, $fields) or
	die "Cannot create version (change_version_seq)";
    $obvius->{USER} = $backup_user;

    my $new_vdoc = $obvius->get_latest_version($doc);
    $obvius->get_version_fields($new_vdoc, 256, 'PUBLISH_FIELDS');
    $new_vdoc->{PUBLISH_FIELDS}->{PUBLISHED}=strftime('%Y-%m-%d %H:%M:%S', localtime);

    $obvius->{USER} = 'admin';
    $obvius->publish_version($new_vdoc);
    $obvius->{USER} = $backup_user;
}

sub is_subdoc {
    my ($this, $obvius, $docid, $parent_docid) = @_;

    my $doc = $obvius->get_doc_by_id($docid);
    my @path = $obvius->get_doc_path($doc);

    my $rediger_doc = $obvius->get_doc_by_id($parent_docid);
    my $forening_docid = $rediger_doc->{'PARENT'} || 0;

    for (@path) {
	if ($_->{ID} == $forening_docid) {
	    return 1;
	}
    }
    return 0;
}

sub send_password_mail {
my ($this, $to, $from, $password) = @_;    

my $message =<<EOF;
From: www.sportfiskeren.dk <$from>
Subject: Password til foreningens sider
To: $to

Dit password er: \"$password\"

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

Obvius::DocType::FiskeforeningRediger - Perl extension for blah blah blah

=head1 SYNOPSIS

    use Obvius::DocType::FiskeforeningRediger;
blah blah blah

=head1 DESCRIPTION

Stub documentation for Obvius::DocType::FiskeforeningRediger, created by h2xs. It looks like the
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
