package Obvius::DocType::SchemeRow;

########################################################################
#
# SchemeRow.pm - SchemeRow Document Type
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

    my $doctype = $obvius->get_doctype_by_id($vdoc->Type);
    my @fields = sort map{ lc($_) } grep {/^field/i } keys %{$doctype->{FIELDS}};

    my @doc_fields = @fields;

    push(@doc_fields, qw(title schemerowtype));

    $obvius->get_version_fields($vdoc, \@doc_fields);

    $output->param(type => $vdoc->SchemeRowType);
    $output->param(title => $vdoc->Title);

    my @out_fields;
    for(@fields) {
        my $data = $vdoc->field($_);
        print STDERR $_ ."\n";
        /(\d+)$/;
        my $fieldnr = $1;
        push(@out_fields, { fieldnr => $fieldnr, text => $data }) if($data);
    }
    $output->param(fields => \@out_fields);

    return OBVIUS_OK;
}

1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Obvius::DocType::SchemeRow - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Obvius::DocType::SchemeRow;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Obvius::DocType::SchemeRow, created by h2xs. It looks like the
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
