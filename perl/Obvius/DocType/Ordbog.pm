package Obvius::DocType::Ordbog;

########################################################################
#
# Ordbog.pm - Ordbog Document Type
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


    $output->param(input => $input);

    $this->tracer($input, $output, $doc, $vdoc, $obvius) if ($this->{DEBUG});

    my $prefix = $output->param('PREFIX');
    my $is_admin = $input->param('IS_ADMIN');

    $obvius->get_version_fields($vdoc, [qw(base)]);

    my $basedoc=$doc;
    my $baseid=$doc->Id;
    if ($basedoc=$obvius->lookup_document($vdoc->Base)) {
	$baseid=$basedoc->Id;
    }
	
    my $kwdocs;

    my %options=(
		 needs_document_fields => [ 'parent' ],
		 sortvdoc => $vdoc,
		 notexpired=>!$is_admin,
		 public=>!$is_admin,
		 order=>'title'
		);

    $kwdocs = $obvius->search(
			    [ 'title', 'teaser' ],
			    "parent = ". $baseid,
			    %options,
			   );

    for (@$kwdocs) {
	my $doc = $obvius->get_doc_by_id($_->Docid);
	my $url = $obvius->get_doc_uri($doc);
	$_->{URL} = "$url";
    }

    $output->param('kwdocs'=>$kwdocs);

    return OBVIUS_OK;
}

1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Obvius::DocType::Ordbog - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Obvius::DocType::Ordbog;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Obvius::DocType::Ordbog, created by h2xs. It looks like the
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
