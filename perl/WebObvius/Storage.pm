package WebObvius::Storage;

########################################################################
#
# Storage.pm - Container class for editengine storage-types.
#
# Copyright (C) 2004 Magenta Aps, Denmark (http://www.magenta-aps.dk/)
#
# Authors: Jens K. Jensen (jensk@magenta-aps.dk),
#          Adam Sjøgren (asjo@magenta-aps.dk),
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

use Obvius::Data;

our @ISA = qw( Obvius::Data );
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub execute {
    my ($this, $function, $data, $session, $path_prefix)=@_;

    my ($status, $message, $results)=$this->$function($data, $session, $path_prefix);

    return ($status, $message, $results);
}

# Internal methods used by subclasses:
sub _get_object {
    my ($this, $data, $path_prefix)=@_;

    # Retrieve full object description
    my ($object_id) = keys %{$data->{$path_prefix}};

    my $object = $data->{$path_prefix}->{$object_id};

    return $object;
}


sub key_to_identifiers {
    my ($this, $key)=@_;

    $key =~ s/anonymous//;

    my @id_value_pairs = split '--', $key;

    my %identifiers;
    map {
        my ($id, $value) = split '::', $_;
        $identifiers{$id} = $value;
    } @id_value_pairs;

    return \%identifiers;
}

sub object_key {
    my ($this, $object)=@_;

    my @identifiers = sort @{$this->param('identifiers')};
    my @keys_values = map {$_ . '::' . $object->{$_}} @identifiers;
    my $object_key = join '--', @keys_values;

    return $object_key;
}

sub check_identifiers_in_data {
    my ($this, $data)=@_;

    # Check and return object identifiers
    my %values=();
    foreach my $identifier (@{$this->param('identifiers')}) {
        if (!defined $data->{$identifier}) {
            print STDERR __PACKAGE__ . ' called without required identifier: ' . $identifier . ' in data (source: ' . $this->param('source') . ')';
            return undef;
        }
        else {
            $values{$identifier} = $data->{$identifier};
        }
    }

    return \%values;
}

# Internal methods that must be implemented by subclasses:
#
# sub lookup ($this, $how)
#
# sub get_element ($this, $how)
#
# sub list ($this, $object, $options) - returns an array-ref to the
#                                       elements and the total number
#                                       of elements in the entire
#                                       list.
sub lookup {
    my ($this)=@_;
    die ref($this) . ' has not implemented lookup() - bug the author! Stopping';
}

sub element {
    my ($this)=@_;
    die ref($this) . ' has not implemented element() - bug the author! Stopping';
}

sub list {
    my ($this)=@_;
    die ref($this) . ' has not implemented list() - but the author! Stopping';
}

# Public methods that must be implemented by subclasses:

1;
__END__

=head1 NAME

WebObvius::Storage - container class for editengine storage-types.

=head1 SYNOPSIS

  use WebObvius::Storage;
  our @ISA=qw( WebObvius::Storage );

=head1 DESCRIPTION

This class is subclassed for the specific storage types available to
the editengine.

=head2 EXPORT

None by default.


=head1 AUTHOR

Jens K. Jensen (jensk@magenta-aps.dk),
Adam Sjøgren (asjo@magenta-aps.dk).

=head1 SEE ALSO

L<WebObvius>, L<Obvius>.

=cut
