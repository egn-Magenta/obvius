package WebObvius::Storage::Template;

########################################################################
#
# Template.pm - Template storage-type for edit engine.
#
# Copyright (C) 2004 Magenta Aps, Denmark (http://www.magenta-aps.dk/)
#
# Authors: Jens K. Jensen (jensk@magenta-aps.dk),
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

use Carp;

use WebObvius::Storage;

our @ISA = qw( WebObvius::Storage );
our $VERSION = '0.01';

sub new {
    my ($class, $options, $obvius) = @_;
    my $this=$class->SUPER::new(%$options, obvius=>$obvius);
}

sub lookup {
    my ($this, %object) = @_;
    my $record =  {
                   map { $_ => {
                                value => $object{$_},
                                status => 'OK',
                               }
                     } keys %object
                  };
    return (\%object, $record);
}

1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

WebObvius::Storage::Template - Perl extension for blah blah blah

=head1 SYNOPSIS

  use WebObvius::Storage::Template;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for WebObvius::Storage::Template, created by h2xs. It looks like the
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
