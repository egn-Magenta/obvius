package Obvius::DocType::Virksomhedsforside;

########################################################################
#
# Virksomhedsforside.pm - Virksomhedsforside Document Type
#
# Copyright (C) 2001 Magenta Aps, Denmark (http://www.magenta-aps.dk/)
#
# Author: Jørgen Ulrik B. Krag (jubk@magenta-aps.dk)
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

    my $is_admin = $input->param('IS_ADMIN');
    my %search_options = (
                            'public' => !$is_admin,
                            'notexpired' => !$is_admin,
                            'nothidden' => !$is_admin,
                            'sortvdoc' => $vdoc,
                            'needs_document_fields' => ['parent']
                        );

    my @fields;
    my $where;

    # Kun virksomheder
    my $article_type = $obvius->get_doctype_by_name('Virksomhed');
    die('Virksomhed doctype does not exist!\n') unless($article_type);
    $where = "type = '" . $article_type->Id . "' AND parent = " . $doc->Id;

    # Andre interesante felter
    push(@fields, 'title', 'short_title', 'teaser');

    my $docs = $obvius->search(\@fields, $where, %search_options) || [];

    my @out_docs;
    for(@$docs) {
        my $data;
        $data->{title} = $_->Title;
        $data->{short_title} = $_->Short_Title;
        my $picture = $obvius->get_version_field($_, 'fp_picture');
        if($picture and $picture ne '/') {
            $data->{picture} = $picture;
        }
        $data->{teaser} = $_->Teaser if($_->Teaser);

        my $doc = $obvius->get_doc_by_id($_->DocId);
        $data->{url} = $obvius->get_doc_uri($doc);

        push(@out_docs, $data);
    }

    $output->param(doc_rows => \@out_docs);
    return OBVIUS_OK;
}

1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Obvius::DocType::Virksomhedsforside - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Obvius::DocType::Virksomhedsforside;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Obvius::DocType::Virksomhedsforside, created by h2xs. It looks like the
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
