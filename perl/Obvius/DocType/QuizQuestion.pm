package Obvius::DocType::QuizQuestion;

########################################################################
#
# QuizQuestion.pm - Question for Quiz and Game
#
# Copyright (C) 2001-2002 FI, aparte, Denmark
#
# Authors: Jason Armstrong <jar@fi.dk>
#          Adam Sjøgren <asjo@aparte-test.dk>
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
use Obvius::DocType::Quiz;

our @ISA = qw( Obvius::DocType::Quiz );
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub action {
  my ($this, $input, $output, $doc, $vdoc, $obvius) = @_;

  return OBVIUS_OK;
}

1;
__END__

=head1 NAME

Obvius::DocType::QuizQuestion - Questions for Quiz and game.

=head1 SYNOPSIS

  (use'd automatically by Obvius)

=head1 DESCRIPTION

QuizQuestion inherits from Quiz, so that parse_subqs() is readily
available for use when displaying the question.

=head1 AUTHORS

Jason Armstrong <ja@riverdrums.com>
Adam Sjøgren <asjo@aparte-test.dk>

=head1 SEE ALSO

L<Obvius::DocType::Quiz>, L<Obvius::DocType>.

=cut
