package WebObvius::Cache;

use strict;
use warnings;
use Apache::Constants qw(:common);

require Exporter;
our @ISA = qw( Exporter );
our @EXPORT_OK = qw( handler );

our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub handler {
    my $r = shift;
    my $prefix = $r->dir_config('CachePrefix') || '/cache/';
    my $filename = $r->filename;

    $filename =~ s/^$prefix//;
    $filename =~ m|([^/]*/[^/]*)|; 
    $r->content_type($1);

    # Most browsers doesn't understand get filenames ending in a slash.
    # Therefore we should tell them what filename to use.
    if($r->uri =~ m!/([^/]+\.\w+)/$!) {
        $r->header_out("Content-Disposition", "attachment; filename=$1");
    }

    return OK;
}

1;
__END__

=head1 NAME

WebObvius::Cache - Perl module for setting content-type from cache-dir
                   path.
