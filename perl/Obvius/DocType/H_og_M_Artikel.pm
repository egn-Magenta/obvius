package Obvius::DocType::H_og_M_Artikel;

########################################################################
#
# H_og_M_Artikel.pm - H_og_M_Artikel Document Type
#
# Copyright (C) 2001 Magenta Aps, Denmark (http://www.magenta-aps.dk/)
#
# Author: J�rgen Ulrik B. Krag (jubk@magenta-aps.dk)
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

    my $primary_group = $obvius->get_version_field($vdoc, 'primary_group');
    return OBVIUS_OK unless($primary_group);

    my $last_changed = $vdoc->Version;

    my $fields = [
                    'category',
                    'docdate',
                    'title',
                    'primary_group',
                ];

    my $infopaq_doctype = $obvius->get_doctype_by_name('InfopaqNyhed');

    my $where = "type = " . $infopaq_doctype->Id . " AND " .
                "category = '$primary_group'";

    my $docs = $obvius->search($fields, $where,
                                public => 1,
                                notexpired => 1,
                                nothidden => 1,
                                order => 'docdate DESC',
                                append => 'LIMIT 6'
                            ) || [];

    $last_changed = $docs->[0]->Docdate if($docs->[0] and $docs->[0]->Docdate gt $last_changed);

    my @docs;
    for(@$docs) {
        my $doc = $obvius->get_doc_by_id($_->DocId);
        my $url = $obvius->get_doc_uri($doc);
        my $date = $_->Docdate;
        $date =~ s/^\d\d(\d\d)-(\d\d)-(\d\d).*/$3.$2.$1/;
        push(@docs, {
                        title => $_->Title,
                        url => $url,
                        date => $date,
                        group => $_->Primary_Group
                    }
                );
    }

    $output->param(otherdocs => \@docs) if(scalar(@docs));

    $output->param('primary_group' => $primary_group);

    $output->param('override_last_changed' => $last_changed);

    return OBVIUS_OK;
}

1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Obvius::DocType::H_og_M_Artikel - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Obvius::DocType::H_og_M_Artikel;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Obvius::DocType::H_og_M_Artikel, created by h2xs. It looks like the
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
