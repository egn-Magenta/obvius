package Obvius::DocType::FileUpload;

use strict;
use warnings;

use Obvius;
use Obvius::DocType;
use Digest::MD5 qw( md5_hex );

use WebObvius::Cache::ApacheCache;
use Obvius::Hostmap;

our @ISA = qw( Obvius::DocType );
our $VERSION="1.0";


sub raw_document_data {
     my ($this, $doc, $vdoc, $obvius, $req, $output) = @_;
     
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

     my $data;
     do {
	 local $/;
	 my $fh;
	 open $fh, $path or die "File not found: $path";
	 $data = <$fh>;
	 close $fh;
     };

     my $cache = WebObvius::Cache::ApacheCache->new($obvius);
     
     # Redirect to url without arguments so to cache
     # it instead.
     if ($req->args && $req->args !~ /^\s*$/) { 
	 goto redirect;
     }
     
     if (!$cache->can_request_use_cache_p($req) || $req->notes('is_admin')) {
	 return ($mime_type, \$data, $filename);
     }

     $req->content_type($mime_type || "application/octet-stream");
     $cache->save_request_result_in_cache($req, \$data, $filename);

   redirect:
     my $hostmap = Obvius::Hostmap->new_with_obvius($obvius);
     $output->param(redirect => "http://" . $hostmap->absolute_uri($req->uri));
     return OBVIUS_OK;
}

1;
