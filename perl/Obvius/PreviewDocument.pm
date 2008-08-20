package Obvius::PreviewDocument;

use strict;
use warnings;

use Obvius::Document;
use Data::Dumper;

our $preview_base_path = '/admin/previews/';
our @ISA = qw( Obvius::Document );

sub create_new_preview {
     my ($obvius, $doc, $fields, $lang) = @_;
     my ($docid, $version);
     my $preview_path = $preview_base_path . $doc->Id;

     my $preview_doc = $obvius->lookup_document($preview_path);
     if (!$preview_doc) {
	  my $parent = $obvius->lookup_document($preview_base_path);
	  
	  die "No such document: $preview_path\n" if (!$parent);
	  
	  my $userid = $obvius->get_userid( $obvius->{USER});
	  ($docid, $version) = $obvius->create_new_document($parent, $doc->Id, $doc->Type, $lang, $fields, $userid || $doc->Id, $doc->Grp);
	  $preview_doc = $obvius->get_doc_by_id($docid);
	  eval { $obvius->set_access_data($preview_doc, $doc->Owner, $doc->Grp, 'ALL=view,create,edit,publish,delete,modes'); };
     } else {
	  $docid = $preview_doc->Id;
	  $version = $obvius->create_new_version($preview_doc, $doc->Type, $lang, $fields);
     }
     
# Be sure to not make any extra work.
     my $res = $obvius->just_publish_fucking_version($docid, $version);
}
     
sub new {
     my ($class, $obvius, $docid) = @_;
     
     my $doc = $obvius->get_doc_by_id($docid);
     my $preview_doc = $obvius->lookup_document($preview_base_path . $docid);
     
     die "Error reading some document" if (!$doc || ! $preview_doc);

     my $self = {preview_doc => $preview_doc, doc => $doc} ;
     
     return bless $self, $class;
}

sub Id {
     my $this = shift;

     my $i= 0;
     my @caller = caller 1;
     my $caller = $caller[3];
	  
     return $this->{doc}->{ID} if ($caller =~ /docparam/i);
     
     return $this->{preview_doc}->{ID};
}
     
sub param {
     my ($this, $name, $value) = @_;
     if (lc $name eq 'id' ) {
	  my @caller = caller 1;
	  my $caller = $caller[3];
	  return $this->{doc}->{ID} if ($caller =~ /docparam/i);
     }
     
     return $this->{preview_doc}->param($name, $value);
}

sub AUTOLOAD {
     my ($this, @list) = @_;     
     our $AUTOLOAD;

     my ($name) = $AUTOLOAD =~ /::([^:]+)$/;
     
     return $this->{preview_doc}->$name(@list);
}
