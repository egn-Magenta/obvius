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
# 	    [19, 1],   # /test
#	    [43, 1],   # /intranet
	    [72, 1],   # /links
	    [89, 1],   # /copyrights
	    [210, 1],  # /hjælp
	    [280, 1],  # /publikationer
	    [466, 1],  # /jul
#	    [651, 1],  # /projekter
	    [676, 1],  # /reklamefabrikken
	    [1485, 1], # /boern
	    [1486, 1], # /mad
	    [1487, 1], # /hjemmet
	    [1488, 1], # /ret
	    [1489, 1], # /økonomi
	    [1490, 1], # /etik
# 	    [1491, 1], # /priser
	    [1527, 1], # /skoletjenesten (ACHTUNG: skal den med?)
	    [1528, 1], # /unge
	    [2161, 1], # /faq
	    [2948, 1], # /forbrugerskolen
#	    [3694, 1], # /favicon.ico
	    [4287, 1], # /juleprik
#	    [4289, 1], # /bestil
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

sub process_document {
  my ($doc) = @_;

  my $vdoc = $doc->public_version($magenta->{VERSIONTYPE});
  $vdoc  ||= $doc->get_version($magenta->{VERSIONTYPE}, $doc->latest_version);

  my ($enkel) = (0);

  if ($vdoc->template == 9) {
      $enkel = 1;

  }


  if ($enkel) {
      my @tmp = $obvius->get_doc_by_path($magenta->get_doc_uri($doc));
      my $obvius_doc = $tmp[-1]; 
      unless (defined($obvius_doc)) {
	  print STDERR "FEJL!!!\n";
	  print STDERR Dumper \@tmp;
	  #     print STDERR Dumper \$doc;
	  
	  exit 1;
      }
      my $obvius_vdoc = $obvius->get_latest_version($obvius_doc);
      

      my $doctype = $obvius_doc->Type;

      return unless ($doctype == 2);

      my $lang = $obvius_vdoc->Lang;

      my $fields = $obvius->get_version_fields($obvius_vdoc, 255);
      $fields->param('show_subdocs' => 1);


      $obvius_vdoc = $obvius->create_new_version($obvius_doc, $doctype, $lang, $fields);
      
      # Utypede sprog er dejlige:
      $obvius_vdoc = $obvius->get_version($obvius_doc,$obvius_vdoc);
      
      $obvius->get_version_fields($obvius_vdoc, 255, 'PUBLISH_FIELDS');
      my $publish_fields = $obvius_vdoc->publish_fields;
      $publish_fields->param(PUBLISHED => strftime('%Y-%m-%d %H:%M:%S', localtime));
      $obvius->publish_version($obvius_vdoc,\$error);
  } else {
      print STDERR "Dokument uændret";
  }

}


sub process_tree {
  my ($doc) = @_;
  
  process_document($doc);
  
  map { print STDERR "Konverterer $_\n"; process_tree($magenta->fetch_doc_id($_)) } 
    $doc->get_subdocs("all");
}

########################################################################
#
# Main Logic
#
########################################################################

map { process_tree(
		   $magenta->fetch_doc_id($_->[0]), 
		   ) 
     } @todo;



exit(0);

    


