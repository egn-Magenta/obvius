package Obvius::DocType::EkspertseminarForside;

########################################################################
#
# EkspertSeminarForside.pm - Seminar frontpage
#
# Copyright (C) 2002 aparte, Denmark (http://www.aparte.dk/)
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

    my $eks_doctype = $obvius->get_doctype_by_name('Ekspertseminar');

    $output->param(Obvius_DEPENDENCIES => 1);
    my $subdocs = $obvius->search(
                                    [], "type = " . $eks_doctype->Id . " AND parent = " . $doc->Id,
                                    public => 1,
                                    needs_document_fields => [ 'parent' ]
                            ) || [];
    my @result;
    for(@$subdocs) {
        $obvius->get_version_fields($_, ['docdate', 'enddate', 'authmethod', 'title']);
        my $docdate = $_->field('docdate');
        my $enddate = $_->field('enddate') || '9999-99-99 99:99:99';
        my $nowdate = strftime('%Y-%m-%d 00:00:00', localtime);
        my $active = ($docdate le $nowdate and $enddate ge $nowdate);

        if($enddate eq '9999-99-99 99:99:99' or $enddate eq '0000-00-00 00:00:00') {
            $enddate = '?';
        } else {
            $enddate =~ s/^(\d\d\d\d)-(\d\d)-(\d\d).*$/$3\.$2\.$1/;
        }

        $docdate =~ s/^(\d\d\d\d)-(\d\d)-(\d\d).*$/$3\.$2\.$1/;


        my $authmethod = $_->field('authmethod');
        my $locked = 0;
        $locked = 1 if($authmethod and $authmethod eq 'explicit');
        $output->param(Obvius_SIDE_EFFECTS => 1) if ($locked);

        my $d = $obvius->get_doc_by_id($_->DocId);
        my $url = $obvius->get_doc_uri($d);

        push(@result, {
                        locked => $locked,
                        startdate => $docdate,
                        enddate => $enddate,
                        active => $active,
                        name => $_->field('title'),
                        url => $url
                    }
                );

    }

    $output->param('result' => \@result);

    return OBVIUS_OK;
}

1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Obvius::DocType::EkspertseminarForside - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Obvius::DocType::EkspertseminarForside;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Obvius::DocType::EkspertseminarForside, created by h2xs. It looks like the
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
