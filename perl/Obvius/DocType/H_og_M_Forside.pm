package Obvius::DocType::H_og_M_Forside;

########################################################################
#
# H_og_M_Forside.pm - H_og_M_Forside Document Type
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

use POSIX qw(strftime);

our @ISA = qw( Obvius::DocType );
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub action {
    my ($this, $input, $output, $doc, $vdoc, $obvius) = @_;

    my $last_changed;

    my $is_admin = $input->param('IS_ADMIN');
    my %search_options = (
                            'public' => !$is_admin,
                            'notexpired' => !$is_admin,
                            'nothidden' => !$is_admin,
                            'order' => 'docdate DESC, title'
                        );

    my @fields;
    my $where;

    # Kun artikler fra H & M
    my $article_type = $obvius->get_doctype_by_name('H_og_M_Artikel');
    die('H_og_M_Artikel doctype does not exist!\n') unless($article_type);
    $where = "type = '" . $article_type->Id . "'";

    # Andre interesante felter
    push(@fields, 'show_pic_fp', 'title', 'short_title', 'primary_group', 'docdate');

    # Kun nye artikler.
    my $now = strftime('%Y-%m-%d %H:%M:%S', localtime);
    push(@fields, 'expire_fp');
    $where .= " and expire_fp > '$now'";

    # Kun artikler, der faktisk har en primary_group
    $where .= " and primary_group IS NOT NULL and primary_group != ''";

    my $docs = $obvius->search(\@fields, $where, %search_options) || [];

    # Minimum 6 dokumenter..
    my $num_docs = scalar @$docs;
    if($num_docs < 10) {
        $where =~ s/expire_fp >/expire_fp <=/;
        $search_options{'append'} = " limit " . (10 - $num_docs);
        my $extra_docs = $obvius->search(\@fields, $where, %search_options) || [];
        push(@$docs, @$extra_docs);
    }

    $last_changed = $docs->[0]->Docdate if($docs->[0]);

    # Prøv at finde den samlede version:
    if($docs->[1]) {
        my $docdate = $docs->[1]->DocDate;
        my $result = $obvius->search(
                                    \@fields,
                                    "docdate = '$docdate' and (primary_group IS NULL or primary_group = '')",
                                    %search_options,
                                    append => 'limit 1'
                                ) || [];
        # Tilføj sidst i listen hvis vi finder den.
        push(@$docs, $result->[0]) if($result->[0]);
    }


    my @out_docs;
    for(@$docs) {
        my $data;
        $data->{title} = $_->Short_Title || $_->Title;

        my $date = $_->DocDate;
        $date =~ s/^\d\d(\d\d)-(\d\d)-(\d\d).*/$3.$2.$1/;
        $data->{date} = $date;

        if($_->Show_Pic_Fp) {
            my $pic_path = $obvius->get_version_field($_, 'fp_picture');
            $data->{picture} = $pic_path if($pic_path and $pic_path ne '/');
        }

        my $teaser = $obvius->get_version_field($_, 'teaser');
        $data->{teaser} = $teaser if($teaser);

        $data->{group} = $_->Primary_Group if($_->Primary_Group);

        my $doc = $obvius->get_doc_by_id($_->DocId);
        $data->{url} = $obvius->get_doc_uri($doc);

        $data->{country} = $obvius->get_version_field($_, 'country');

        push(@out_docs, $data);
    }

    $output->param(doc_rows => \@out_docs);


    my $fields = [
                    'category',
                    'docdate',
                    'title',
                    'primary_group'
                ];

    my $infopaq_doctype = $obvius->get_doctype_by_name('InfopaqNyhed');

    my $other_where = "type = " . $infopaq_doctype->Id;

    my $other_docs = $obvius->search($fields, $other_where,
                                public => 1,
                                notexpired => 1,
                                nothidden => 1,
                                order => 'docdate DESC, title',
                                append => 'LIMIT 10'
                            ) || [];

    $last_changed = $other_docs->[0]->Docdate if($other_docs->[0] and (! $last_changed or $other_docs->[0]->Docdate gt $last_changed));

    my @docs;
    for(@$other_docs) {
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

    $output->param('override_last_changed' => $last_changed) if($last_changed);

    return OBVIUS_OK;
}


1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Obvius::DocType::H_og_M_Forside - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Obvius::DocType::H_og_M_Forside;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Obvius::DocType::H_og_M_Forside, created by h2xs. It looks like the
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
