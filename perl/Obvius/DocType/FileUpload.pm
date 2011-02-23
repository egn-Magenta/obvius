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

sub internal_redirect {
    my ($this, $doc, $vdoc, $obvius, $req, $output) = @_;

    # Can't handle requests with args, so skip them and let raw_document_data
    # redirect them.
    return undef if($req->args and $req->args !~ m!^\s*$!);
    
    $obvius->get_version_fields($vdoc, ['mimetype', 'title', 'uploadfile']);
    my $path = get_full_path($vdoc->field('uploadfile'), $obvius);
    return undef unless ($path && -r $path);

    my $cache = WebObvius::Cache::ApacheCache->new($obvius);

    if ($cache->can_request_use_cache_p($req)) {
        $req->content_type($vdoc->field('mimetype') || "application/octet-stream");
        my $filename = path_to_filename($path, $vdoc);
        $cache->copy_file_to_cache($req, $path, $filename);

        my $uri = $vdoc->field('uploadfile');
        $uri =~ s!^\s+!!;
        $uri =~ s!\s+!!;
        return $uri;
    } else {
        # Serve admin files this way?
        return undef;
    }
}


sub raw_document_data {
    my ($this, $doc, $vdoc, $obvius, $req, $output) = @_;
   
    # Redirect to url without arguments so to cache
    # it instead.
    if ($req->args && $req->args !~ /^\s*$/) { 
       goto redirect;
    }

    $obvius->get_version_fields($vdoc, ['mimetype', 'title', 'uploadfile']);
    my $path = get_full_path($vdoc->field('uploadfile'), $obvius);
    return undef if !$path;

    my $filename = path_to_filename($path, $vdoc);
    my $mime_type = $vdoc->field('mimetype');

    my $data;
    do {
        local $/;
        my $fh;
        open $fh, $path or die "File not found: $path";
        $data = <$fh>;
        close $fh;
    };

    my $cache = WebObvius::Cache::ApacheCache->new($obvius);

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

sub get_full_path {
    my ($path, $obvius) = @_;
    return undef unless($path);
    $path =~ s!^\s+!!;
    $path =~ s!\s+$!!;    

    $path = $obvius->{OBVIUS_CONFIG}{DOCS_DIR} . $path;
    $path =~ s|/+|/|g;
    
    return $path;
}

sub path_to_filename {
    my ($path, $vdoc) = @_;

    my ($filename) = $path =~ m|/([^/]+)$|;
    $filename ||= $vdoc->field('title');
    
    $filename =~ s/^\s+|\s+$//g;
    $filename =~ s/\s+/_/g;

    return $filename;
}

1;
