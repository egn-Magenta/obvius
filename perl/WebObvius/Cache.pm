package WebObvius::Cache;

########################################################################
#
# Cache.pm - simple perl-module that sets content-type from the path.
#
# Copyright (C) 2002-2004 ForbrugerInformationen,
#                         Magenta Aps, Denmark (http://www.magenta-aps.dk/)
#                         aparte A/S, Denmark (http://www.aparte.dk/),
#
# Authors: Peter Makholm (pma@fi.dk)
#          Adam Sjøgren (asjo@magenta-aps.dk).
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
    my $mimetype=$1; # Using $1 directly below sometimes, only sometimes, fails, it seems.
    $r->content_type($mimetype);

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

WebObvius::Cache - mod_perl module for fixing the mime-type of cache-files.

=head1 SYNOPSIS

<Directory /var/www/www.website/docs/cache>
    PerlTypeHandler WebObvius::Cache
    PerlSetVar CachePrefix /var/www/www.website/docs/cache/
</Directory>

=head1 DESCRIPTION

Parses the path for the mime-type, sets the content_type on the
request.

=head1 AUTHORS

Peter Makholm <pma@fi.dk>
Adam Sjøgren <asjo@magenta-aps.dk>

=head1 SEE ALSO

=cut
