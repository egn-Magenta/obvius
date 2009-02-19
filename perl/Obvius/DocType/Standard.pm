package Obvius::DocType::Standard;

########################################################################
#
# Standard.pm - Standard Document Type
#
# Copyright (C) 2001-2004 Magenta Aps, Denmark (http://www.magenta-aps.dk/)
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

# action - simply returns 'everything is fine'.
sub action {
    my ($this, $input, $output, $doc, $vdoc, $obvius) = @_;

    return OBVIUS_OK;
}

# alternate_location - checks if the content-field is empty and the
#                      url-field is non-empty, and if so returns the
#                      url to which redirection should take place.
sub alternate_location {
    my ($this, $doc, $vdoc, $obvius) = @_;

    $this->tracer($doc, $vdoc, $obvius) if ($this->{DEBUG});

    $obvius->get_version_fields($vdoc);

    my $url = $vdoc->field('url');
    return undef unless ($url);

    my $content = $vdoc->field('content');
    return (defined $content and length($content) == 0) ? $url : undef;
}

1;
__END__

=head1 NAME

Obvius::DocType::Standard - Perl module implementing the Standard document type

=head1 SYNOPSIS

  use'd automatically.

=head1 DESCRIPTION

The Standard document type doesn't do anything, it merely holds data -
which is then displayed by the templating system.

For backwards compability with the original MCMS-system, there is one
exception though: if the field "content" is empty and there is a field
called "url" that isn't, the document redirects to that url.

Note that this special behaviour is for backwards compability only,
redirection should be done by using the document type "Link".

=head1 AUTHOR

Adam Sjøgren, E<lt>asjo@magenta-aps.dkE<gt>

=head1 SEE ALSO

L<Obvius::DocType::Link>, L<Obvius::DocType>.

=cut
