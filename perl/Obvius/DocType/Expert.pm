package Obvius::DocType::Expert;

########################################################################
#
# Expert.pm - Expert
#
# Copyright (C) 2001 aparte, Denmark (http://www.aparte.dk/)
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

    $output->param('is_admin' => 1) if($input->param('IS_ADMIN'));

    my $lecture_doctype = $obvius->get_doctype_by_name('Lecture');

    $output->param(Obvius_DEPENDENCIES => 1);
    my $lectures = $obvius->search(
                                    [ 'title' ],
                                    "type = " . $lecture_doctype->Id . " AND parent = " . $doc->Id,
                                    public => 1,
                                    notexpired => 1,
                                    needs_document_fields => [ 'parent' ]
                                ) || [];
    my @lectures;
    for(@$lectures) {
        my $d = $obvius->get_doc_by_id($_->DocId);
        my $url = $obvius->get_doc_uri($d);
        push(@lectures, {title => $_->Title, url => $url, docid => $_->DocId});
    }

    $output->param('lectures' => \@lectures) if(scalar(@lectures));

    return OBVIUS_OK;
}

sub alternate_location {
    my ($this, $doc, $vdoc, $obvius) = @_;

    $this->tracer($doc, $vdoc, $obvius) if ($this->{DEBUG});

    $obvius->get_version_fields($vdoc);

    my $url = $vdoc->field('url');
    return undef unless ($url);

    my $content = $vdoc->field('content');
    return (defined $content and length($content) == 0) ? $url : undef;
}

1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Obvius::DocType::Expert - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Obvius::DocType::Expert;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Obvius::DocType::Expert, created by h2xs. It looks like the
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
