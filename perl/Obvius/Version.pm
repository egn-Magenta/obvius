package Obvius::Version;

########################################################################
#
# Version.pm - Version of a Document
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

use Obvius::Data;

our @ISA = qw( Obvius::Data );
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

use Carp;



our %validate =
    (
     docid	      => \&Obvius::Data::is_int_nonnegative,
     version	      => \&Obvius::Data::is_datetime,
     type	      => \&Obvius::Data::is_int_positive,
     lang	      => \&Obvius::Data::is_lang_code,
     public	      => '[01]',
     valid	      => '[01]',
    );

sub new {
    my ($class, $rec) = @_;

    my $self = $class->SUPER::new($rec);

    $self->{FIELDS} = undef;

    return $self;
}


#
# AUTOLOAD - special for fetching the fields
#
sub AUTOLOAD {
    my ($this, $value) = @_;
    my $type = ref($this) or return undef;

    our $AUTOLOAD;
    my ($name) = $AUTOLOAD =~ /::_(\w+)$/;
    ( $name ) = $AUTOLOAD =~ /::([A-Z]\w*)$/ unless (defined $name);

    confess "Method $AUTOLOAD not defined" unless (defined $name);

    $name = uc $name;

    # don't look for vfields unless it seems resonable
    if ($this->{FIELDS} and exists $this->{FIELDS}->{$name}) {
	return $this->field($name);
    }

    unless (defined $value) {
	carp ref($this).": $name not known" unless (exists $this->{$name});
	return $this->{$name};
    }

    my $oldvalue = $this->{$name};
    $this->{$name} = $value;
    return $oldvalue;
}


sub fields {
    my ($this, $type) = @_;
    $type=(defined $type ? $type : 'FIELDS');

    $this->tracer() if ($this->{DEBUG});

    return $this->{$type};
}

sub field {
    my ($this, $name, $value, $type) = @_;
    $type=(defined $type ? $type : 'FIELDS');

    $this->tracer($name, $value, $type) if ($this->{DEBUG});

    $this->{$type} = new Obvius::Data unless ($this->{$type});
    return $this->{$type}->param($name, $value);
}

sub publish_fields {
    my($this)=@_;
    return $this->fields('PUBLISH_FIELDS');
}

sub publish_field {
    my ($this, $name, $value) = @_;
    $this->field($name, $value, 'PUBLISH_FIELDS');
}

1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Obvius::Version - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Obvius::Version;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Obvius::Version, created by h2xs. It looks like the
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
