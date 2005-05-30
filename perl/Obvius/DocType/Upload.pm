package Obvius::DocType::Upload;

########################################################################
#
# Upload.pm - Upload document type - all other files than images.
#
# Copyright (C) 2001-2005 Magenta Aps, Denmark (http://www.magenta-aps.dk/)
#                         aparte A/S, Denmark (http://www.aparte.dk/)
#
# Authors: Jørgen Ulrik B. Krag (jubk@magenta-aps.dk),
#          René Seindahl,
#          Adam Sjøgren (asjo@magenta-aps.dk)
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

use Obvius;
use Obvius::DocType;

our @ISA = qw( Obvius::DocType );
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

# XXX consider adding an alternate_location-method that, if we are not
# in admin and the url ends in a slash, redirects to the url without
# the slash. This would probably help at least MSIE and Adobe Reader.

# raw_document_data - given the standard objects for document, version
#                     and obvius, returns either a list containing
#                     mime-type, raw_data and - if the document has a
#                     '.' in its name - the name.
sub raw_document_data {
    my ($this, $doc, $vdoc, $obvius) = @_;

    $this->tracer($doc, $vdoc, $obvius) if ($this->{DEBUG});

    my $fields = $obvius->get_version_fields($vdoc, ['mimetype', 'uploaddata', 'contentdisposition']);

    my $name = $doc->Name || '';
    if($name =~ /\.\w+$/) {
        my $con_disp = $vdoc->field('contentdisposition') || 'attachment';
        return ($fields->param('mimetype'), $fields->param('uploaddata'), $name, $con_disp);
    } else {
        return ($fields->param('mimetype'), $fields->param('uploaddata'));
    }
}


1;
__END__

=head1 NAME

Obvius::DocType::Upload - document type for file uploads.

=head1 SYNOPSIS

  used automatically by Obvius.

=head1 DESCRIPTION

This document type is special in that it can be used to store files of
all kinds. The raw data is returned when the document is retrieved.

Magically a Content-Disposition is set if the name has a '.' in it(!)

=head1 AUTHOR

Jørgen Ulrik B. Krag (jubk@magenta-aps.dk),
René Seindahl,
Adam Sjøgren (asjo@magenta-aps.dk)

=head1 SEE ALSO

L<Obvius::DocType>.

=cut
