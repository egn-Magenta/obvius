package WebObvius::Storage::Temporary;

########################################################################
#
# Temporary.pm - session-storagetype for the edit engine
#
# Copyright (C) 2005 Magenta Aps, Denmark (http://www.magenta-aps.dk/)
#
# Authors: Adam Sjøgren (asjo@magenta-aps.dk)
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

use WebObvius::Storage;

our @ISA = qw( WebObvius::Storage );
our $VERSION="1.0";

sub new {
    my ($class, $options, $obvius, $session)=@_;

    my $this=$class->SUPER::new(%$options, obvius=>$obvius);

    return undef unless (defined $session);
    return undef unless (exists $options->{source});

    # All the temporary stuff is stored in the hash-ref
    # named by source in the options inside the session:
    $session->{$options->{source}}={} unless (exists $session->{$options->{source}});

    $this->param('source'=>$options->{source});
    $this->param('temporary_session'=>$session);
    # XXX Do we need to remember the session_id as well?

    return $this;
}

# internal for Temporary:

sub session {
    my ($this)=@_;

    return $this->param('temporary_session');
}

sub storage {
    my ($this)=@_;

    return $this->session->{$this->param('source')};
}

# internal for edit engine:
sub lookup {
    my ($this, %how)=@_;

    return ({ key=>$how{key} }, $this->element(%how));
}

sub list {
    my ($this, $object, $options)=@_;

    # XXX object is a hash-ref, only include elements in the list that
    #     match the object.

    my $ret=[ map { $this->element(key=>$_) } keys %{$this->storage()} ];

    # Sort:
    $ret=[ sort { $a->{$options->{sort}}->{value} cmp $b->{$options->{sort}}->{value} } @$ret ]
        if ($options->{sort});
    $ret=[ reverse @$ret ] if ($options->{reverse});

    # Limit:
    my $total=scalar(@$ret);
    my ($first, $last)=(0, $total-1);

    $first=$options->{start} if (defined $options->{start});
    $last=$first+$options->{max}-1 if (defined $options->{max} and $last>($first+$options->{max}-1));

    $ret=[ @$ret[$first..$last] ] if ($first!=0 or $last!=$total-1);

    return $ret, $total;
}

sub element {
    my ($this, %how)=@_;

    my $values=$this->storage->{$how{key}};

    # Convert to the output-format wanted (XXX consider using this
    # format internally as well):
    my $ret={
             (map { $_=>{ value=>$values->{$_} } } keys %{$values}),
             key=>{ value=>$how{key} },
            };

    return $ret;
}

# Public:

sub create {

    return ('OK', 'Not implemented');
}

sub save {
    my ($this, $data, $session, $path_prefix)=@_;

    my $object=$this->_get_object($data, $path_prefix);

    my $store=$this->storage();
    foreach my $key (keys %{$data->{$path_prefix}}) {
        my $identifiers=$this->key_to_identifiers($key);
        # Clean out storage:
        $store->{$identifiers->{key}}={};
        # Save new:
        map { $store->{$identifiers->{key}}->{$_}=$object->{$_} } keys %$object;
    }

    return ('OK', 'Entry stored');
}

sub save_and_publish {
    my ($this, $data, $session, $key) = @_;

    $this->save($data, $session, $key);
    $key =~ s!save_and_publish!save!g;

    return $this->save($data, $session, $key)
}

sub preview {
     return save(@_);
}

sub remove {

    return ('OK', 'Not implemented');
}

1;
__END__

=head1 NAME

WebObvius::Storage::Temporary - Perl extension implementing a temporary storage class.

=head1 SYNOPSIS

  use WebObvius::Storage::Temporary;

=head1 DESCRIPTION

The Temporary storage-class stores it's information on the
session-object - so as soon as the session is gone, to is the
data. Thus the name 'Temporary' :-)

This is useful when you want to use the editengine for data-entry and
checking, but you really don't need to store the data directly (maybe
you want to have someone enter some data for an email to be sent, or
something like that).

[META: This could be done by an 'Email' storage-class, couldn't it?
"Store" means send, then...?]

=head1 AUTHOR

Adam Sjøgren, E<lt>asjo@magenta-aps.dkE<gt>

=head1 SEE ALSO

L<WebObvius::Storage>.

=cut
