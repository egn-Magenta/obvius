package Obvius::DocType::Tooltip;

########################################################################
#
# Link.pm - Link Document Type
#
# Copyright (C) 2001-2004 aparte A/S, Denmark (http://www.aparte.dk),
#                         Magenta Aps, Denmark (http://www.magenta-aps.dk/)
#
# Author: Adam Sjøgren (asjo@magenta-aps.dk)
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
use Encode;

our @ISA = qw( Obvius::DocType );
our $VERSION="1.0";

# action - just returns OK, as the "work" of the document type is done
#          by the alternate_location-method.
sub action {
    my ($this, $input, $output, $doc, $vdoc, $obvius) = @_;

    return OBVIUS_OK;
}

sub raw_document_data {
    my ( $this, $doc, $vdoc, $obvius, $input) = @_;
    return unless $input->param('obvius_bare');
    return if (!defined $doc || !defined $vdoc);

    my $text;

    $obvius->get_version_fields($vdoc, ['content', 'parent']);

    # If text is not set, use the parent-text.
    if ($vdoc->field('content') =~ /^\s*$/ && !($vdoc->field('parent') eq '')) {
        $doc = $obvius->lookup_document($vdoc->field('parent'));
        $vdoc = $obvius->get_public_version($doc);
        $vdoc ||= $obvius->get_latest_version($doc);
        my ($mime_type, $parent_text) = raw_document_data($this, $doc, $vdoc, $obvius, $input);

        $text = $parent_text;
    } else {
        $text = "<img src='/grafik/close.gif' class='close' onclick='ajax_hideTooltip();' />\n" . $text;
        $text .= $vdoc->field('content');
    }

    
    return ( 'text/html', decode_db_output($text) );
}

sub decode_db_output {
    my $text = shift;
    my $result = "";
    Encode::_utf8_off($text);
    my $str = Encode::encode('latin-1', $text);
    my $res = "";
    while($str) {
        $res .= Encode::decode('utf-8', $str, Encode::FB_QUIET);
        if($str) {
            $res .= Encode::decode('latin-1', substr($str, 0, 1));
            $str = substr($str, 1);
        }
    }
    $text = $res;
    return Encode::encode('ascii', $text, Encode::FB_HTMLCREF);
}


1;
__END__

=head1 NAME

Obvius::DocType::Tooltip - implements the Tooltip document type for Obvius.

=head1 SYNOPSIS

  use'd automatically by Obvius.

=head1 DESCRIPTION

blah blah blah

=head1 AUTHOR

Ole Hejlskov E<lt>ole@magenta-aps.dkE<gt>

=head1 SEE ALSO

L<Obvius::DocType>.

=cut
