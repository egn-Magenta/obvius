package Obvius::DocType::FileUpload;

use strict;
use warnings;

use Obvius;
use Obvius::DocType;
use Digest::MD5 qw( md5_hex );

use WebObvius::Cache::Cache;
use Obvius::Hostmap;
use File::Path;
use Obvius::CharsetTools qw(mixed2utf8);

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

    my $cache = WebObvius::Cache::Cache->new($obvius);

    if ($cache->can_request_use_cache_p($req)) {
        $req->content_type($vdoc->field('mimetype') || "application/octet-stream");
        my $filename = path_to_filename($path, $vdoc);
        $cache->copy_file_to_cache($req, $path, $filename);

        my $uri = $vdoc->field('uploadfile');
        $uri =~ s!^\s+!!;
        $uri =~ s!\s+$!!;
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

    my $cache = WebObvius::Cache::Cache->new($obvius);

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

sub place_file_in_upload {
    my ($this, $obvius, $fh, $type, $filename) = @_;

    # Make sure that we always save utf8 file names
    $filename = mixed2utf8($filename);

    my $id = md5_hex($filename);
    my $content_type = $type;
    $content_type =~ s!"!!g; $content_type =~ s!'!!g;
    $content_type = 'unknown/unknown' unless ($content_type =~ s|^([a-zA-Z0-9.-]+/[a-zA-Z0-9.-]+).*|$1|);
    
    my $docs_dir = $obvius->config->param('docs_dir');
    $docs_dir =~ s!/$!!;
    
    my $upload_dir = $docs_dir . "/upload/$content_type";
    $upload_dir =~ s!/+!/!g;
    
    sub make_dir {
        my $id = shift;
        return substr($id, 0, 2) . "/" . substr($id, 2, 2) . "/" . substr($id, 0, 8);
    }
    
    $filename =~ s!^.*[/\\]([^/\\]+)$!$1!;
    my $final_dir = make_dir($id);
    while ( -f "$upload_dir/$final_dir/$filename") {
        $final_dir = make_dir(md5_hex(rand() . rand()));
    }
    
    $upload_dir = "$upload_dir/$final_dir";
    unless(-d $upload_dir) {
        mkpath($upload_dir, 0, 0775) or die "Couldn't create dir: $upload_dir";
    }
    
    my $full_file_path = "$upload_dir/$filename";

    {
        local $/ = undef;
        open(FILE, '>', $full_file_path);
        print FILE <$fh>;
        close(FILE);
    }

    # Make sure we don't remove the first / in /upload
    $full_file_path =~ s!^$docs_dir!!;

    return $full_file_path;
}

1;
