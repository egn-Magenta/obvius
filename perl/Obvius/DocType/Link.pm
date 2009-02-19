package Obvius::DocType::Link;

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

our @ISA = qw( Obvius::DocType );
our $VERSION="1.0";

# action - just returns OK, as the "work" of the document type is done
#          by the alternate_location-method.
sub action {
    my ($this, $input, $output, $doc, $vdoc, $obvius) = @_;

    return OBVIUS_OK;
}

# alternate_location - returns the contents of the url-field, so that
#                      Obvius can redirect to the address stored there.
sub alternate_location {
    my ($this, $doc, $vdoc, $obvius) = @_;

    $this->tracer($doc, $vdoc, $obvius) if ($this->{DEBUG});

    my $url=$obvius->get_version_field($vdoc, 'url');
    return $url;
}

1;
__END__

=head1 NAME

Obvius::DocType::Link - implements the Link document type for Obvius.

=head1 SYNOPSIS

  use'd automatically by Obvius.

=head1 DESCRIPTION

The Link document type allows the system to keep metadata about a
link. It also effectively functions as a simple redirector.

When clicked on the public interface a document of this type redirects
to the address stored in it's url-field.

=head1 AUTHOR

Adam Sjøgren E<lt>asjo@magenta-aps.dkE<gt>

=head1 SEE ALSO

L<Obvius::DocType>.

=cut
