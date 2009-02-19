package Obvius::Annotations;

########################################################################
#
# Annotations.pm - version annotations handling
#
# Copyright (C) 2004 Magenta Aps, Denmark (http://www.magenta-aps.dk/)
#
# Authors: Adam Sjøgren (asjo@magenta-aps.dk),
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

use strict;
use warnings;

our $VERSION="1.0";

sub get_annotation {
    my ($obvius, $vdoc)=@_;
    return undef unless (defined $vdoc);

    return $obvius->get_table_record('annotations', { docid=>$vdoc->Docid, version=>$vdoc->Version });
}

sub create_annotation {
    my ($obvius, $vdoc, $text)=@_;
    return undef unless (defined $vdoc);
    return undef unless (defined $text);

    return $obvius->insert_table_record('annotations', {
                                                      docid=>$vdoc->Docid,
                                                      version=>$vdoc->Version,
                                                      user=>$obvius->user->Id,
                                                      text=>$text,
                                                     });
}

sub delete_annotation {
    my ($obvius, $vdoc)=@_;
    return undef unless (defined $vdoc);

    return $obvius->delete_table_record('annotations', undef, { docid=>$vdoc->Docid, version=>$vdoc->Version });
}

sub update_annotation {
    my ($obvius, $vdoc, $text)=@_;
    return undef unless (defined $vdoc);
    return undef unless (defined $text);

    return $obvius->update_table_record('annotations', {
                                                      docid=>$vdoc->Docid,
                                                      version=>$vdoc->Version,
                                                      user=>$obvius->user->Id,
                                                      text=>$text,
                                                     },
                                      { docid=>$vdoc->Docid, version=>$vdoc->Version });
}

1;
__END__

=head1 NAME

Obvius::Annotations - handle annotations for versions.

=head1 SYNOPSIS

  use Obvius::Annotations;

=head1 DESCRIPTION

=head2 EXPORT

None by default.

=head1 AUTHOR

Adam Sjøgren E<lt>asjo@magenta-aps.dkE<gt>

=head1 SEE ALSO

L<Obvius>.

=cut
