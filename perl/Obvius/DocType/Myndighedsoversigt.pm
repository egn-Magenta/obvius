package Obvius::DocType::Myndighedsoversigt;

########################################################################
#
# Myndighedsoversigt.pm - Myndighedsoversigt Document Type
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
    my $depth=$obvius->get_version_field($vdoc, 'levels') || 2;
    $this->tracer($input, $output, $doc, $vdoc, $obvius) if ($this->{DEBUG});

#    my $top = $obvius->get_root_document();
#    $top = $obvius->get_public_version($top);
    my $elements= [];

    add_to_sitemap($vdoc, 0, $depth, $obvius, $elements);
    $output->param('sitemap' => $elements);
    $output->param('depth' => $depth);
    return OBVIUS_OK;
}

sub add_to_sitemap{
    my ($vdoc, $level, $depth, $obvius, $elements) = @_;

    $obvius->get_version_fields($vdoc, ['Title', 'Short_title', 'Seq']);
    return if ($vdoc->Seq < 0);

    my $title= $vdoc->Short_title || $vdoc->Title;
    my $doc = $obvius->get_doc_by_id($vdoc->DocId);
    my $uri = $obvius->get_doc_uri($doc);

    my $element = {
                    'title' => $title,
                    'url'   => $uri,
                    'level' => $level,
		  };

    push (@$elements, $element) if($level); # Don't include root doc.

    return if ($level++ >= $depth); # HER BLIVER TESTEN UDFØRT

    my $subdocs = $obvius->get_document_subdocs($doc);
    $subdocs = [] unless ($subdocs);

    # XXX modifying the element we have already pushed onto @$elements
    # We can do this because $element is a reference
    $element->{subdocs_marker} = 1 if scalar(@$subdocs);

    for (@$subdocs)
    {
        add_to_sitemap($_, $level, $depth, $obvius, $elements);
    }
    return;
}


1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Obvius::DocType::Myndighedsoversigt - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Obvius::DocType::Myndighedsoversigt;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Obvius::DocType::Myndighedsoversigt, created by h2xs. It looks like the
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
