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
    return OK;
}
