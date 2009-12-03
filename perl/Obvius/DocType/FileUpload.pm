package Obvius::DocType::FileUpload;

use strict;
use warnings;

use Obvius;
use Obvius::DocType;
use Digest::MD5 qw( md5_hex );
our @ISA = qw( Obvius::DocType );
our $VERSION="1.0";

sub raw_document_data {
     my ($this, $doc, $vdoc, $obvius, $req, $output) = @_;
     my $data =	$req->hostname . ':' . $req->the_request;
     
     $obvius->get_version_fields($vdoc, ['mimetype', 'title', 'uploadfile']);
     my $path = $vdoc->field('uploadfile');
     return undef if !$path;

     $path = $obvius->{OBVIUS_CONFIG}{DOCS_DIR} . $path;
     $path =~ s|/+|/|g;
     
     my $mime_type = $vdoc->field('mimetype');
     
     
     my ($filename) = $path =~ m|/([^/]+)$|;
     $filename ||= $vdoc->field('title');
     
     $filename =~ s/^\s+|\s+$//g;
     $filename =~ s/\s+/_/g;

     local $/;
     my $fh;
     open $fh, $path or die "File not found: $path";
     $data = <$fh>;
     close $fh;
     return ($mime_type, \$data, $filename);
}

1;
