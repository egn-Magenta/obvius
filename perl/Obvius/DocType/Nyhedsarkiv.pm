package Obvius::DocType::Nyhedsarkiv;

########################################################################
#
# Nyhedsarkiv.pm - Nyhedsarkiv Document Type
#
# Copyright (C) 2001 Magenta Aps, Denmark (http://www.magenta-aps.dk/)
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

    my $title = $obvius->get_version_field($vdoc, 'title');

    my $do_new_search = 0;
    my $session = $input->param('SESSION');
    my $newstype=$input->param('newstype');
    if($session) {
        if(defined($newstype)) {
            $do_new_search = 1 unless(defined($session->{newstype}) and $session->{newstype} == $newstype);
        } else {
            $newstype = $session->{newstype};
        }
    } else {
        $do_new_search = 1;
    }

    if($do_new_search) {
        my $is_admin = $input->param('IS_ADMIN');
        my %search_options = (
                                'public' => !$is_admin,
                                'notexpired' => !$is_admin,
                                'nothidden' => !$is_admin,
                                'order' => 'docdate DESC',
                                'needs_document_fields' => ['parent']
                            );

        my @fields;
        my $where;

        my $hm_type = $obvius->get_doctype_by_name('H_og_M_Artikel');
        my $other_type = $obvius->get_doctype_by_name('InfopaqNyhed');


        if($newstype) {
            if($newstype == 1) {
                $where = "type = '" . $hm_type->Id . "'";
                $title .= " - Internationalt overblik";
                $session->{newstype} = 1;
            } else {
                $where = "type = '" . $other_type->Id ."'";
                $title .= " - Dansk presse";
                $session->{newstype} = 2;
            }
        } else {
            $where = "type IN ('" . $hm_type->Id . "','" . $other_type->Id . "')";
            $newstype = 0;
            $title .= " - Alle nyheder";
            $session->{newstype} = 0;
        }


        # Kun fra denne gruppe
        my $group = $obvius->get_version_field($vdoc, 'group');
        if($group) {
            push(@fields, 'primary_group', 'category');
            $where .= " AND (primary_group = '$group' OR category = '$group')";
            $output->param(group => $group);
        }

        # Andre interesante felter
        push(@fields, 'title', 'short_title', 'teaser', 'docdate');

        $session->{docs} = $obvius->search(\@fields, $where, %search_options) || [];
        $session->{pagesize} = $obvius->get_version_field($vdoc, 'pagesize');

        # Save title
        $session->{'override_title'} = $title;

        # If it's a new session put it on the output object...
        # otherwise just export the session ID
        if($session->{_session_id}) {
            $output->param('SESSION_ID' => $session->{_session_id});
        } else {
            $output->param('SESSION' => $session);
        }
    } else {
        # Carry on session_id
        $output->param('SESSION_ID' => $input->param('obvius_session_id'));
    }

    if($session->{docs} and scalar(@{$session->{docs}})) {
        if ($session->{pagesize}) {
            my $page = $input->param('p') || 1;
            $this->export_paged_doclist(
                                        $session->{pagesize},
                                        $session->{docs},
                                        $output, $obvius,
                                        name=>'newsdocs',
                                        page=>$page,
                                        require=>'teaser'
                                    );
        } else {
            $this->export_doclist(
                                    $session->{docs},
                                    $output, $obvius,
                                    name=>'newsdocs',
                                    require=>'teaser'
                                );
        }

        # Save title
        $output->param('override_title' => $session->{'override_title'}) if($session->{'override_title'});
    } else {
        $output->param('no_results' => 1);
    }

    $output->param(newstype => $newstype ? $newstype : 0);

    return OBVIUS_OK;
}

1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Obvius::DocType::Nyhedsarkiv - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Obvius::DocType::Nyhedsarkiv;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Obvius::DocType::Nyhedsarkiv, created by h2xs. It looks like the
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
