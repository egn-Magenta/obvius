package Obvius::DocType::Deltagerliste;

########################################################################
#
# Deltagerliste.pm - list of participants
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

use POSIX qw(strftime);

our @ISA = qw( Obvius::DocType );
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub action {
    my ($this, $input, $output, $doc, $vdoc, $obvius) = @_;

    my $debatleder = $obvius->get_version_field($vdoc, 'debatleder');
    my $lederdoc;
    $lederdoc = $obvius->lookup_document($debatleder) if($debatleder);
    my $leder_id;
    $leder_id = $lederdoc->Id if($lederdoc);

    my $deltager_doctype = $obvius->get_doctype_by_name('Debatdeltager');
    $output->param(Obvius_DEPENDENCIES => 1);
    my $deltagere = $obvius->search(
                                    [], "type = ". $deltager_doctype->Id . " AND parent = " . $doc->Id,
                                    public => 1,
                                    needs_document_fields => ['parent']
                                ) || [];
    my @deltagere;
    for(@$deltagere) {
        $obvius->get_version_fields($_, ['email', 'title', 'stilling', 'content', 'picture']);
        my $data = {
                        navn => $_->field('title'),
                        email => $_->field('email'),
                        stilling => $_->field('stilling'),
                        beskrivelse => $_->field('content'),
                        picture => $_->field('picture')
                    };

        if($leder_id and $_->Docid == $leder_id) {
            $data->{'leder'} = 1;
            unshift(@deltagere, $data);
        } else {
            push(@deltagere, $data);
        }
    }

    $output->param('deltagere' => \@deltagere);

    return OBVIUS_OK;
}

1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Obvius::DocType::Deltagerliste - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Obvius::DocType::Deltagerliste;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Obvius::DocType::Deltagerliste, created by h2xs. It looks like the
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
