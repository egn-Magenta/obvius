package Obvius::DocType::SearchExpertDb;

########################################################################
#
# SearchExpertDb.pm - SearchExpertDb Document Type
#
# Copyright (C) 2001 Magenta Aps, Denmark (http://www.magenta-aps.dk/)
#
# Author: Jørgen Ulrik B. Krag (krag@aparte.dk)
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

    my $mode;
    return OBVIUS_OK unless($mode = $input->param('mode'));

    $output->param(mode => $mode);

    if($mode eq 'expertsearch') {
        return $this->expertsearch($input, $output, $doc, $vdoc, $obvius);
    } elsif($mode eq 'lecturesearch') {
        return $this->lecturesearch($input, $output, $doc, $vdoc, $obvius);
    } else {
        $output->param(mode => '');
        return OBVIUS_OK;
    }
}

sub expertsearch {
    my ($this, $input, $output, $doc, $vdoc, $obvius) = @_;

    return OBVIUS_OK unless($input->param('submit'));

    my $expert_doctype = $obvius->get_doctype_by_name('Expert');
    my @fields;
    my $where = "type = " . $expert_doctype->Id;

    push(@fields, ('title', 'institution', 'expert_db')); # For sorting
    $where .= " AND expert_db > 0";

    if(my $text = $input->param('text')) {
        $text =~ s/'/\\'/g;
        $text =~ s/"/\\"/g;

        push(@fields, ('area_other', 'research_area'));
        $where .= " AND (area_other LIKE '%$text%' OR research_area LIKE '%$text%')";
    }

    if(my $name = $input->param('name')) {
        push(@fields, 'name');
        $where .= " AND name LIKE '%$name%'";
    }

    if(my $category = $input->param('category')){
        $category =~ s/^10 //;
        $category =~ s/Ø/O/;
        push(@fields, 'level_' . $category);
        $where .= " AND level_$category = 3";
    }

    if(my $institution = $input->param('institution')) {
        $where .= " AND institution = '$institution'";
    }

    my $is_admin = $input->param('IS_ADMIN');

    my $result = $obvius->search(\@fields, $where,
                                        'order' => 'title',
                                        'public' => !$is_admin,
                                        'notexpired' => !$is_admin,
                                        'nothidden' => !$is_admin); # !$is_admin
    if($result) {
        my @results;
        for(@$result) {
            my $doc = $obvius->get_doc_by_id($_->DocId);
            my $url = $obvius->get_doc_uri($doc);
            push(@results, {
                            title => $_->Title,
                            institution => $_->Institution,
                            url => $url,
                            docid => $_->DocId
                        });
        }
        $output->param(results => \@results);
    } else {
        $output->param(no_results => 1);
        # Preserve form state
        $output->param(text => $input->param('text'));
        $output->param(name => $input->param('name'));
        $output->param(category => $input->param('category'));
        $output->param(institution => $input->param('institution'));
    }

    return OBVIUS_OK;
}

sub lecturesearch {
    my ($this, $input, $output, $doc, $vdoc, $obvius) = @_;

    return OBVIUS_OK unless($input->param('submit'));

    my $lecture_doctype = $obvius->get_doctype_by_name('Lecture');
    my @fields;
    my @valid_experts;
    my $where = "type = " . $lecture_doctype->Id;

    my $is_admin = $input->param('IS_ADMIN');
    my %search_options = (
                            'public' => !$is_admin,
                            'notexpired' => !$is_admin,
                            'nothidden' => 0,
                            'needs_document_fields' => [ 'parent' ]
                        );

    push(@fields, 'title'); # For sorting

    # Text search in title and content fields
    if(my $text = $input->param('text')) {
        $text =~ s/'/\\'/g;
        $text =~ s/"/\\"/g;

        push(@fields, 'content');
        $where .= " AND (title LIKE '%$text%' OR content LIKE '%$text%')";
    }

    # Audience - category on lecture document
    if(my $audience = $input->param('audience')) {
        push(@fields, 'category');
        $where .= " AND category LIKE '%$audience%'";
    }

    # Category - category on expert (parent) document.
    # Do this search by finding a list of experts with
    # the right category. Then search on lecture
    # document's parent field.
    if(my $category = $input->param('category')){

        my $expert_doctype = $obvius->get_doctype_by_name('Expert');

        my $result = $obvius->search([ 'category' ], "type = " . $expert_doctype->Id . " AND category = '$category'", %search_options);

        if($result) {
            my $match = join(',', map { $_->DocId } @$result);
            $where .= " AND parent IN ($match)";
        } else {
            $where .= " AND parent = '-1'"; # Should give nu result
        }
    }

    if(my $country_part = $input->param('country_part')) {
        push(@fields, 'country_parts');
        $where .= " AND country_parts = '$country_part'";
    }

    $search_options{order} = 'title';
    $search_options{nothidden} = !$is_admin;

    my $result = $obvius->search(\@fields, $where, %search_options); # !$is_admin
    if($result) {
        my @results;
        for(@$result) {
            my $doc = $obvius->get_doc_by_id($_->DocId);
            my $url = $obvius->get_doc_uri($doc);
            my $parent_doc = $obvius->get_doc_by_id($_->Parent);
            my $parent_vdoc = $obvius->get_public_version($parent_doc);
            my $expert_title = $obvius->get_version_field($parent_vdoc, 'title');
            push(@results, {
                            title => $_->Title,
                            expert_title => $expert_title,
                            url => $url,
                            docid => $_->DocId
                        });
        }
        $output->param(results => \@results);
    } else {
        $output->param(no_results => 1);
        # Preserve form state
        $output->param(text => $input->param('text'));
        $output->param(name => $input->param('name'));
        $output->param(category => $input->param('category'));
        $output->param(institution => $input->param('institution'));
    }

    return OBVIUS_OK;
}

1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Obvius::DocType::SearchExpertDb - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Obvius::DocType::SearchExpertDb;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Obvius::DocType::SearchExpertDb, created by h2xs. It looks like the
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
