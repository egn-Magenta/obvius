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
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Obvius::Cache, created by h2xs. It looks like the
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
