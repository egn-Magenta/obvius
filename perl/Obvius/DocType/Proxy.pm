package Obvius::DocType::Proxy;

########################################################################
#
# Proxy.pm - document type that proxies one or more external pages.
#
# Copyright (C) 2004 Magenta Aps, Denmark (http://www.magenta-aps.dk/)
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
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub action {
    my ($this, $input, $output, $doc, $vdoc, $obvius) = @_;

    print STDERR __PACKAGE__, "->action\n";

    $obvius->get_version_fields($vdoc, [qw(url prefixes)]);
    my ($url, $prefixes)=($vdoc->field('url'), $vdoc->field('prefixes'));

    $output->param(url=>$url);
    $output->param(prefixes=>$prefixes);


    return OBVIUS_OK;
}

1;
__END__

=head1 NAME

Obvius::DocType::Proxy - Perl module implementing a proxy document type.

=head1 SYNOPSIS

  used automatically by Obvius.

=head1 DESCRIPTION

=head1 AUTHOR

Adam Sjøgren, E<lt>asjo@magenta-aps.dkE<gt>

=head1 SEE ALSO

L<Obvius::DocType>.

=cut
