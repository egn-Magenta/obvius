package Obvius::Document;

########################################################################
#
# Document.pm - Document
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

sub new {
    my ($class, $rec) = @_;

    my $self = $class->SUPER::new($rec);

    $self->{VERSIONS} = new Obvius::Data;

    return bless $self, $class;
}

sub list_valid_keys {
    my ($this) = @_;

    return [
	    { id => $this->{ID} },
	    { parent => $this->{PARENT}, name => $this->{NAME} }
	   ];
}


#
# Niceness
#
sub versions {
    my($this) = @_;

    return $this->{VERSIONS};
}

sub version {
    my($this, $id, $version) = @_;

    return $this->{VERSIONS}->param($id => $version);
}

1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Obvius::Document - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Obvius::Document;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Obvius::Document, created by h2xs. It looks like the
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
