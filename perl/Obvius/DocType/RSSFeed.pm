package Obvius::DocType::RSSFeed;

########################################################################
#
# RSSFeed.pm - Document type for creating RSS feeds in Obvius
#
# Copyright (C) 2005 Magenta Aps, Denmark (http://www.magenta-aps.dk/)
#
# Author: Martin Skøtt (martin@magenta-aps.dk)
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

use 5.006;
use strict;
use warnings;

use Obvius;
use Obvius::DocType;

our @ISA = qw( Obvius::DocType );
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;;


# Preloaded methods go here.

1;
__END__

=head1 NAME

Obvius::DocType::RSSFeed - Perl module for the RSSFeed doctype

=head1 SYNOPSIS

  use Obvius::DocType::RSSFeed;
  blah blah blah

=head1 DESCRIPTION

This is the perl module of the document type RSSFeed. The document type enables you to 
provide RSS feeds from your Obvius site.

Blah blah blah.

=head2 EXPORT

None by default.


=head1 AUTHOR

Martin Skøtt, E<lt>martin@magenta-aps.dkE<gt>

=head1 SEE ALSO

L<perl>.

=cut
