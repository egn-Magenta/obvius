package Obvius::DocType::DanmarksKort;

########################################################################
#
# DanmarksKort.pm - map of Denmark
#
# Copyright (C) 2002 aparte, Denmark (http://www.aparte.dk/)
#
# Author: Jørgen Ulrik Balslev Krag <jubk@magenta-aps.dk>
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

our %typehash = (
                    roe => 'ikon1.gif',
                    kartoffel => 'ikon2.gif',
                    raps => 'ikon4.gif',
                    majs => 'ikon8.gif'
            );

sub action {
    my ($this, $input, $output, $doc, $vdoc, $obvius) = @_;

    $obvius->get_version_fields($vdoc, ['default_year', 'adjust_x', 'adjust_y']);

    my $default_year = $vdoc->Default_Year;

    my $adjust_x = $vdoc->Adjust_X || 0;
    my $adjust_y = $vdoc->Adjust_Y || 0;

    my $year = $input->param('year') || $default_year;

    $output->param('year' => $year);

    my $forsoeg_doctype = $obvius->get_doctype_by_name('ForsoegsSearch');

    $output->param(Obvius_DEPENDENCIES => 1);
    my $docs = $forsoeg_doctype->dkkort_search($obvius, $year);

    $output->param('distinct_years' => $forsoeg_doctype->get_distinct_years($obvius));

    $output->param('produkter' => $forsoeg_doctype->get_produkter($obvius));

    my @result;

    if($docs) {
        for(@$docs) {
            push(@result, {
                            alt => $_->{nr} . " ved " . $_->{stednavn},
                            gif => $_->{ikon},
                            x => ($_->{xpos} + $adjust_x),
                            y => ($_->{ypos} + $adjust_y),
                            url => "g=" . $_->{g_id} . "&udsaetning=" . $_->{u_id},
                        });
        }
    }

    $output->param(ikoner => \@result) if(scalar(@result));

    return OBVIUS_OK;
}


1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Obvius::DocType::DanmarksKort - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Obvius::DocType::DanmarksKort;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Obvius::DocType::DanmarksKort, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head2 EXPORT

None by default.


=head1 AUTHOR

A. U. Thor, E<lt>a.u.thor@a.galaxy.far.far.awayE<gt>

=head1 SEE ALSO

L<perl>.

=cut
