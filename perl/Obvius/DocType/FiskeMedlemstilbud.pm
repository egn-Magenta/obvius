package Obvius::DocType::FiskeMedlemstilbud;

########################################################################
#
# FiskeMedlemstilbud.pm - FiskeMedlemstilbud Document Type
#
# Copyright (C) 2001-2003 aparte, Denmark (http://www.aparte.dk/)
#
# Author: Mads Kristensen,
#         Adam Sjøgren (asjo@aparte.dk)
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
use Net::SMTP;
use POSIX qw(strftime);

our @ISA = qw( Obvius::DocType );
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub action {
    return OBVIUS_OK;
}


1;
__END__

=head1 NAME

Obvius::DocType::FiskeMedlemstilbud - Order items

=head1 SYNOPSIS

  (use'd by Obvius by itself)

=head1 DESCRIPTION

FiskeMedlemstilbud is an element in a list shown by FiskeMedlemstilbudOversigt.

=head1 AUTHOR

 Mads Kristensen,
 Adam Sjøgren <asjo@aparte.dk>

=head1 SEE ALSO

L<Obvius>.

=cut
