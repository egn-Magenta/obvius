########################################################################
#
# Cache.pm - Content Manager, database handling
#
# Copyright (C) 2003 Magenta Aps, Denmark (http://www.magenta-aps.dk/)
#                    aparte A/S, Denmark (http://www.aparte.dk/),
#                    FI, Denmark (http://www.fi.dk/)
#
# Authors: Adam Sjøgren (asjo@magenta-aps.dk),
#          Jørgen Ulrik B. Krag (jubk@magenta-aps.dk)
#          Peter Makholm (pma@fi.dk)
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

package Obvius::Cache;

use 5.006;
use strict;
use warnings;

our @ISA = qw();
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub new {
    my ($class) = @_;

    bless {}, $class;
}


sub _make_key {
    my ($this, $key) = @_;

    return join('^A', map { $_.'^B'.$key->{$_} } keys %$key);
}

sub _find_keys {
    my ($this, $obj, $keys) = @_;

    unless ($keys) {
	return () unless ($obj->UNIVERSAL::can('list_valid_keys'));
	$keys = $obj->list_valid_keys;
	return () unless ($keys);
    }

    return map { $this->_make_key($_) } @$keys;
}

sub add {
    my ($this, $obj, $domain, $keys) = @_;

    $domain ||= ref $obj;
    for ($this->_find_keys($obj, $keys)) {
	#print STDERR "CACHE_SET_RECORD $_ -> $obj\n";
	$this->{$domain}->{$_} = $obj;
    }
    return $obj;
}
# find ($domain, $key) - Returns a cache entry based on domain and key.
#                        $key must be a reference. 
#
sub find {
    my ($this, $domain, $key) = @_;

    $key = $this->_make_key($key) if (ref $key);
    #print STDERR "CACHE_GET_RECORD $domain/$key -> $this->{$domain}->{$key}\n" if ($this->{$domain}->{$key});
    return $this->{$domain}->{$key};
}

sub domain_exists {
    my ($this, $domain) = @_;

    return exists($this->{$domain});
}

sub clear {
    my ($this, $domain) = @_;

    if ($domain) {
	undef $this->{$domain};
    } else {
	%$this = ();
    }
}


1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Obvius::Cache - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Obvius::Cache;
  $entry=find($domain, $reftokey);

=head1 DESCRIPTION

Functions for accessing the Obvius cache.

=head2 EXPORT

None by default.


=head1 AUTHOR

Adam Sjøgren <lt>asjo@magenta-aps.dk<gt>
Jørgen Ulrik B. Krag <lt>jubk@magenta-aps.dk<gt>

=head1 SEE ALSO

L<perl>.

=cut
