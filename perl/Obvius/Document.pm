package Obvius::Document;

########################################################################
#
# Document.pm - Document
#
# Copyright (C) 2001-2005 Magenta Aps, Denmark (http://www.magenta-aps.dk/)
#
# Authors: Jørgen Ulrik Balslev Krag (jubk@magenta-aps.dk),
#          René Seindal,
#          Adam Sjøgren (asjo@magenta-aps.dk)
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

our @ISA = qw( Obvius::Data );
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

use Obvius::Data;

our %validate =
    (
     id	     => \&Obvius::Data::is_int_nonnegative,
     parent  => \&Obvius::Data::is_int_positive,
     owner   => \&Obvius::Data::is_int_positive,
     grp     => \&Obvius::Data::is_int_positive,
     name    => sub {
	 my $name = shift;
	 print STDERR "Testing XXXXX $name\n";
	 return ($name and $name =~ /^[a-zA-Z0-9._-]+$/);
     },
    );

# new - creates a new Obvius::Document instance. $rec is used to fill
#       in values, if present. It can be a hash, a hash-ref or an
#       object with a param-method. Returns the new object on success,
#       undef on failure.
sub new {
    my ($class, $rec) = @_;

    my $self = $class->SUPER::new($rec);

    $self->{VERSIONS} = new Obvius::Data;

    return bless $self, $class;
}

# list_valid_keys - returns an array-ref to hash-refs representing
#                   unique ways to identify an Obvius::Document object.
sub list_valid_keys {
    my ($this) = @_;

    return [
	    { id => $this->{ID} },
	    { parent => $this->{PARENT}, name => $this->{NAME} }
	   ];
}



# versions - returns the versions stored in the document object in an
#            Obvius::Data object.
sub versions {
    my($this) = @_;

    return $this->{VERSIONS};
}

# version - given a string for an identifier (field-name) and a string
#           with a version, returns that version from the versions
#           stored in the document.
sub version {
    my($this, $id, $version) = @_;

    return $this->{VERSIONS}->param($id => $version);
}

1;
__END__

=head1 NAME

Obvius::Document - class for document objects in Obvius.

=head1 SYNOPSIS

  use Obvius::Document;

=head1 DESCRIPTION

This is a simple container-class for documents in Obvius. The
definitions of keys and such are used by the built in object-cache.

=head1 AUTHOR

Jørgen Ulrik Balslev Krag, E<lt>jubk@magenta-aps.dkE<gt>,
René Seindal,
Adam Sjøgren, E<lt>asjo@magenta-aps.dkE<gt>

=head1 SEE ALSO

L<Obvius>.

=cut
