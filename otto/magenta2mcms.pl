#!/usr/bin/perl

# $Id$

use strict;
use warnings;
use vars qw($VERSION @ISA @EXPORT);

#use lib '/var/www/root/perl';
#use lib '/usr/lib/perl/5.6.0/';

use lib '/home/brother/radar.www/perl';

require Exporter;

@ISA = qw(Magenta::ContentMgr Exporter);

( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;


use Data::Dumper;
use POSIX qw(strftime);
use Image::Size qw(imgsize);

use Getopt::Long;

use constant FALSE => 0;
use constant TRUE => 1;

use locale;

use Carp;
my ($magenta, $obvius,  $debug) = (undef,undef,0);

GetOptions('magenta=s'      => \$magenta,
	   'obvius=s'      => \$obvius,
	   'debug'       => \$debug,
	  );


########################################################################
#
# Konfigurerbare variable
#
########################################################################

# Alt dette bør nok kunne sættes på komandolinjen

my $docroot = '/tmp/portal.fi.dk/docs';        # Hvor skal den finde uploadede filer

# Deltræer der skal konverteres. Liste af par hvor første tal er det
# gamle docid og det andet tal er hvor det skal placeres.

my @todo = (
	    [8, 1],    # /forbrugerinformationen
	    [9, 1],    # /presse
	    [19, 1],   # /test
	    [43, 1],   # /intranet
	    [72, 1],   # /links
	    [89, 1],   # /copyrights
	    [210, 1],  # /hjælp
	    [280, 1],  # /publikationer
	    [466, 1],  # /jul
	    [651, 1],  # /projekter
	    [676, 1],  # /reklamefabrikken
	    [1485, 1], # /boern
	    [1486, 1], # /mad
	    [1487, 1], # /hjemmet
	    [1488, 1], # /ret
	    [1489, 1], # /økonomi
	    [1490, 1], # /etik
	    [1491, 1], # /priser
	    [1527, 1], # /skoletjenesten (ACHTUNG: skal den med?)
	    [1528, 1], # /unge
	    [2161, 1], # /faq
	    [2948, 1], # /forbrugerskolen
	    [3694, 1], # /favicon.ico
	    [4287, 1], # /juleprik
	    [4289, 1], # /bestil
	    [4358, 1], # /nyret
	    );


########################################################################
#
# Opsætning af Magenta (gamle system)
#
########################################################################

use Magenta::NormalMgr;
use Magenta::NormalMgr::Document;
use Magenta::NormalMgr::Image;
use Magenta::NormalMgr::Subscriber;

use Magenta;
use Magenta::ContentMgr::Version;

croak ("No site defined")
  unless (defined($magenta));

eval "use ${magenta}::ContentMgr";
croak "$@" if ($@);

my $cfg_func;

eval {
  no strict;
  $cfg_func = *{"${magenta}::ContentMgr::configuration"}{CODE};
};

my %conf = &$cfg_func(database=>'dsn',
		      normal_db_login=>'user',
		      normal_db_passwd=>'password',
		      document_type=>'doctype',
		      version_type=>'versiontype',
                      mail_templates => 'mail_templates',
                     );

croak ("mail_template not set on site $magenta: Go fix now, dammit!!!!\n")
  unless ($conf{'mail_templates'});

$magenta  = new Magenta::NormalMgr (%conf);

my $magenta_db = $magenta->connect;


########################################################################
#
# Opsætning af Obvius (nyt system)
#
########################################################################

use Obvius;
use Obvius::Config;
use Obvius::Data;

croak ("No site defined")
  unless (defined($obvius));

my $conf = new Obvius::Config($obvius);
#print Dumper($conf);
croak ("Could not get config for $obvius")
  unless(defined($conf));

$obvius = new Obvius($conf);
#print Dumper($obvius);
croak ("Could not get Obvius object for $obvius")
  unless(defined($obvius));

$obvius->{USER} = 'admin';


########################################################################
#
# Generel opsætning...
#
########################################################################

my ($owner, $group) = (1,1);
my $error;

########################################################################
#
# MIME-snask
#
########################################################################

my %mimetypes = (  pdf => 'application/pdf',
		   gif => 'image/gif',
		   jpg => 'image/jpeg',
		   txt => 'text/plain',
		   html => 'text/html',
		   htm => 'text/html',
		   ram => 'audio/x-pn-realaudio',
		   );

sub guess_mime {
    my ($filename) = @_;
    $filename =~ /.*\.(.*?)$/;
    
    my $ext = $1;

    return $mimetypes{$ext} || 'application/octet-stream';
}

########################################################################
#
# Something
#
########################################################################

my %subscribeable = (
		  auto => 'automatic',
		  manual => 'manual',
		  immediate => 'automatic',
		  );

my %sortorder = (
		 sequence => '+seq',
		 titlerev => '-title',
		 title    => '+title',
		 docdate  => '+docdate',
		 version  => '+version',
		 'versionrev' => '-version',
		);
		 

my %image_map = ();

my %doctype2keywords = (
			test => 43,
			note => 46,
			note1 => 46,
			note2 => 46,
			note3 => 46,
			note4 => 46,
			note5 => 46,
			note6 => 46,
			note7 => 46,
			note8 => 46,
			husmodertip => 44,
			Relateret => 42,
			infopaq => 45,
			'note 1' => 46,
			);

sub convert_document {
  my ($parent, $doc) = @_;

  my $vdoc = $doc->public_version($magenta->{VERSIONTYPE});
  $vdoc  ||= $doc->get_version($magenta->{VERSIONTYPE}, $doc->latest_version);

  my $doctype = 2; # Standard....
  my $lang = $vdoc->lang || 'da';


  my $categories = list Magenta::NormalMgr::Category($doc->id, $magenta->{DB});
  my @categories = map { $_->id } @$categories;

  my $keywords = list Magenta::NormalMgr::Keyword($doc->id, $magenta->{DB});
  my @keywords = map { $_->id } @$keywords;

  push @keywords, $doctype2keywords{$vdoc->doctype} if exists $doctype2keywords{$vdoc->doctype}; 

  my $fields = new Obvius::Data(title => $vdoc->title,
			      short_title => $vdoc->short_title,
			      expires => $vdoc->expires,

			      mimetype => 'text/html',
			      teaser => $vdoc->teaser,
			      content => $vdoc->content,
			      author => $vdoc->author,
			      expires => $vdoc->expires,
			      seq => $doc->seq,
			      category => \@categories,
			      keyword => \@keywords,
			      contributors => $vdoc->contributors,
			      docref => $vdoc->docref,
			      source => $vdoc->source,
			      docdate => $vdoc->docdate,
			      sortorder => $sortorder{$doc->sortorder},
			      subscribeable => $subscribeable{$doc->subscribeable},
			      picturetop => $vdoc->image
			     );

  if ($doc->pagesize) {
      $fields->param(pagesize => $doc->pagesize);
  }

  if ($doc->helptext =~ /require=teaser/) {
      $fields->param(subdocs_with_teaser => 1);
  }

  my $images = list Magenta::NormalMgr::Image ($doc->id, $magenta->{DB});

 SWITCH: for ($doc->default_op) {
      
    /^$/             && do { $doctype = add_standard($doc,$vdoc,$fields) || $doctype; last SWITCH };
    /^combo_search$/ && do { $doctype = add_combo($doc,$vdoc,$fields) || $doctype; last SWITCH };
    /^keywords$/     && do { $doctype = add_keywords($doc,$vdoc,$fields) || $doctype; last SWITCH };
    /^quiz$/         && do { $doctype = add_quiz($doc,$vdoc,$fields) || $doctype; last SWITCH };
#    /^multi_choice$/ && do { $doctype = add_multi($doc,$vdoc,$fields) || $doctype; last SWITCH };
      
    print STDERR "Kan ikke konvertere dokumenttype (",$doc->default_op,$doc->id,")\n";
    return undef;
  }
    
    
  my $new_doc = $obvius->create_new_document($parent, $doc->name, $doctype, $lang, $fields, $owner, $group, \$error);
  $new_doc = $obvius->get_doc_by_id($new_doc->[0]);

  map { 
      my $image = $_;
      local $/;
      open FH, "<".$docroot.$image->file;
      my $content = <FH>;

      my ($w,$h) = imgsize($docroot.$image->file);

      my $fields = new Obvius::Data(title => $image->name,
				  align => $image->align,
				  data => $content,
				  width => $w,
				  size => length($content),
				  height => $h,
				  seq => -1.0,
				  docdate => $vdoc->docdate,
				  mimetype => guess_mime($docroot.$image->file),
				  );
      
      my $new_image = $obvius->create_new_document($new_doc, $image->link, 16, 'da', $fields, $owner, $group, \$error);
      $new_image = $obvius->get_doc_by_id($new_image->[0]);

      $image_map{$image->id} = $new_image; 

      my $vimage = $obvius->get_latest_version($new_image);
      $obvius->get_version_fields($vimage, 255, 'PUBLISH_FIELDS');
      my $publish_fields = $vimage->publish_fields;
      $publish_fields->param(PUBLISHED => strftime('%Y-%m-%d %H:%M:%S', localtime));


      $obvius->publish_version($vimage,\$error);

  } @$images;


  if ($doc->public) {

      my $new_vdoc = $obvius->get_latest_version($new_doc);
      $obvius->get_version_fields($new_vdoc, 255, 'PUBLISH_FIELDS');
      my $publish_fields = $new_vdoc->publish_fields;
      $publish_fields->param(PUBLISHED => $doc->published); # strftime('%Y-%m-%d %H:%M:%S', localtime));
      $publish_fields->param(front_dura => $doc->gduration);
      $publish_fields->param(front_prio => $doc->gprio);
      $publish_fields->param(sec_dura => $doc->lduration);
      $publish_fields->param(sec_prio => $doc->lprio);
      $publish_fields->param(in_subscribtion => 0);

      $obvius->publish_version($new_vdoc,\$error);
  }

   # Hvis dokumentet er relateret viden tilføjes det til parent-dokumentet:

   if ($vdoc->doctype eq 'Relateret') {
       my $vparent = $obvius->get_latest_version($parent);
       my $fields = $obvius->get_version_fields($vparent, 255);
       my $rel = $fields->param('rel_box') || '';
       $rel .= "L<" . $doc->title . ";" . $doc->name . ">\n\n";

       print $rel, "\n";
      
       $fields->param(rel_box => $rel);

       sleep 2;

       $vparent = $obvius->create_new_version($parent, $vparent->Type, 'da', $fields);
       $vparent = $obvius->get_version($parent,$vparent);
       $obvius->get_version_fields($vparent, 255, 'PUBLISH_FIELDS');
       my $publish_fields = $vparent->publish_fields;
       $publish_fields->param(PUBLISHED => strftime('%Y-%m-%d %H:%M:%S', localtime));
       $obvius->publish_version($vparent,\$error);

   }

  return $new_doc;    
}


sub convert_tree {
  my ($parent, $doc) = @_;
  
  $parent = convert_document($parent, $doc);
  
  unless (defined($parent)) {
    print STDERR "Kunne ikke konvertere ", $doc->id, "\n";
    return;
  }
  
  map { print STDERR "Konverterer $_\n"; convert_tree($parent, $magenta->fetch_doc_id($_)) } 
    $doc->get_subdocs("all");
}

sub add_standard {
    my ($doc,$vdoc,$fields) = @_;

    my $doctype;

    if ($vdoc->template == 2) {
	$doctype = 6;
	$fields->param( html_content => $fields->param('content'));
	$fields->param( bare => 0 );
    }
    if ($vdoc->template == 3) {
	$doctype = 6;
	$fields->param( html_content => $fields->param('content'));
	$fields->param( bare => 1 );
    }
    if ($vdoc->template == 4) {
	$doctype = 6;
	$fields->param( html_content => $fields->param('content'));
	$fields->param( bare => 0 );
    }
    if ($vdoc->template == 20) {
	$doctype = 6;
	$fields->param( html_content => $fields->param('content'));
	$fields->param( bare => 1 );
    }

    if ($vdoc->url ne '') {
	print "Konverterer felt med webadresse: ", $vdoc->url, "\n";
	if ($vdoc->url =~ /^=(.*)/) { # Uploaded dokument...
	    print "Uploadet dokument: $1\n";
	    local $/;
	    $doctype = 7;
	    my $filnavn = "<".$docroot.$1; print STDERR "Filnavn... $filnavn\n";
	    open FH, $filnavn || warn "Kunne ikke åbne fil: $@\n";
	    my $content = <FH>;
	    my $mime = guess_mime($docroot.$1);

	    if ($mime =~ /image/) {
		$doctype = 16;
		my ($w,$h) = imgsize($docroot.$1);
		$fields->param(data => $content);
		$fields->param(width => $w);
		$fields->param(size => length($content));
		$fields->param(height => $h);
		$fields->param(data => $content);
	    } else {		
		$fields->param(uploaddata => $content);
	    }
	    $fields->param(mimetype=> $mime);

	} else {
	    $doctype = 17 unless ($vdoc->template == 15);
	    $fields->param(url => $vdoc->url);
	}
    }

    return $doctype;

}
sub add_combo {
    my ($doc,$vdoc,$fields) = @_;
    my $doctype = 4;

    $fields->param(search_expression => $doc->helptext,);

    return $doctype;
}
sub add_keywords {
    my ($doc,$vdoc,$fields) = @_;
    my $doctype = 5;

    # Artikler under listen over nyhedsbrevet (gammel docid 59) skal ikke vere keywordsearch.
    my @path = $magenta->get_doc_path($doc);
    foreach (@path) {
#	return add_standard($doc,$vdoc,$fields,1) if ($_->id == 59);
	return undef if ($_->id == 59);
    }

    $doc->helptext =~ /^base=(.*?)$/m;
    my $base = $1;

    my $base_doc = $obvius->lookup_document($base);

    unless (defined $base_doc) {
	$base_doc = $obvius->get_root_document;
	print "Base for KeywordSearch ikke fundet. Gammelt docid: ", $doc->id, "\n";
    }

    $doc->helptext =~ /^keyword=(.*?)$/m;
    my $keyword = $1;

    $fields->param(search_type => 'keyword');
    $fields->param(search_expression => $keyword);
    $fields->param(base => $base_doc->param('id'));

    return $doctype;
}
sub add_quiz {
    my ($doc,$vdoc,$fields) = @_;
    my $doctype;

    return $doctype;
}
sub add_multi {
    my ($doc,$vdoc,$fields) = @_;
    my $doctype = 10;

    return $doctype;
}

########################################################################
#
# Main Logic
#
########################################################################

map { convert_tree(
		   $obvius->get_doc_by_id($_->[1]),
		   $magenta->fetch_doc_id($_->[0]), 
		   ) 
     } @todo;

# use Obvius::DocType::ComboSearch::Parser qw(combo_search_parse);
# my ($where, @fields) = combo_search_parse(q{keyword=Relateret});


# my $rel_docs = $obvius->search(['keyword'], $where);

# my @rel_docs = grep { $obvius->is_public_document($_) }
#                map  { print STDERR "bang"; $obvius->get_doc_by_id($_->Docid) }
#                @$rel_docs;

# my %docs_with_rel = ();



# foreach (@rel_docs) {
#   print STDERR "Foobar";
#   my $dl = $docs_with_rel{$_->parent} || [];
#   push @$dl, $_;
# }

# print STDERR Dumper \%docs_with_rel;

# foreach (keys %docs_with_rel) {
#   my $parent = $obvius->get_doc_by_id($_);
#   my $vparent = $obvius->get_latest_version($parent);
#   my $fields = $obvius->get_version_fields($vparent, 255);
#   my $rel = '';
#   foreach (@{$docs_with_rel{$_}}) {
#     $rel .= "L<" . $_->title . ";" . $_->name . ">\n\n";
#   }

#   $fields->param(rel_box => $rel);

#   $vparent = $obvius->create_new_version($parent, $vparent->Type, 'da', $fields);
#   $vparent = $obvius->get_version($parent,$vparent);
#   $obvius->get_version_fields($vparent, 255, 'PUBLISH_FIELDS');
#   my $publish_fields = $vparent->publish_fields;
#   $publish_fields->param(PUBLISHED => strftime('%Y-%m-%d %H:%M:%S', localtime));
#   $obvius->publish_version($vparent,\$error);
# }



exit(0);

    


