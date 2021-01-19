package Obvius::Data;

########################################################################
#
# Data.pm - Generic data container.
#
# Copyright (C) 2001-2004 Magenta Aps, Denmark (http://www.magenta-aps.dk/)
#
# Authors: René Seindal (rene@magenta-aps.dk)
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

our @ISA = ();
our $VERSION="1.0";

use Carp;

# new (\%hash)
# new ($param1, $value1, $param2, $value2, ... )
#    - creates a new Data object.
#      new can be called with different types of arguments:
#
#        1) new can be called with a reference to a hash or to an
#           object that has a "param" method.  If new is called with a
#           reference to an object, the object's param method is used
#           to construct a hash of its parameters and values
#
#       2n) new can be called with a list of pairs of parameter name
#           with corresponding value
#
sub new {
    my $class = shift;

    my %self;
    my $src;

    if (scalar(@_) == 1) {
	my $data = shift;
	return undef unless (ref $data);
	if (ref $data eq 'HASH') {
	    $src = $data;
	} elsif ($data->UNIVERSAL::can('param')) {
	    for ($data->param) {
		$self{uc $_} = $data->param($_);
	    }
	} else {
	    return undef;
	}
    } else {
	$src = { @_ };
    }

    if ($src) {
	$self{uc $_} = $src->{$_} for (keys %$src);
    }

    return bless \%self, $class;
}

# clear () - deletes all parameters of the object
#
sub clear {
    my ($this) = @_;

    %$this = ();
}

# param () - return an array of all existing parameters
#
# param ($param) - return the value of the parameter named $param
#
# param ($param, $value) - assigns a new $value to the $param and
#                          returns the old value
#
sub param {
    my ($this, $name, $value) = @_;

    return keys %$this unless (defined $name);

    $name = uc $name;
    return $this->{$name} unless (defined $value);

    my $oldvalue = $this->{$name};
    $this->{$name} = $value;
    return $oldvalue;
}

# delete ($param) - deletes a named parameter and return its value
#
sub delete {
    my ($this, $name) = @_;

    $name = uc $name;
    my $oldvalue;
    if (defined $name) {
	$oldvalue=$this->{$name};
	delete $this->{$name};
    }

    return $oldvalue;
}

# params(@keys) - returns a hash(-ref) of keys/values. Notice that
#                 this is not the same as calling param() with no
#                 arguments.
sub params {
    my $this = shift;
    my %values = map { $_ => $this->{uc $_} } @_;
    return wantarray ? %values : \%values;
}

sub exists {
    my ($this, $name) = @_;
    return exists $this->{uc $name};
}

sub DESTROY {}

sub AUTOLOAD {
    my ($this, $value) = @_;
    my $type = ref($this) or return undef;

    our $AUTOLOAD;
    my ( $name ) = $AUTOLOAD =~ /::_(\w+)$/;
    ( $name ) = $AUTOLOAD =~ /::([A-Z]\w*)$/ unless (defined $name);

    confess "Method $AUTOLOAD not defined" unless (defined $name);

    $name = uc $name;
    unless (defined $value) {
	carp ref($this).": $name not known" unless (exists $this->{$name});
	return $this->{$name};
    }

    my $oldvalue = $this->{$name};
    $this->{$name} = $value;
    return $oldvalue;
}

sub validate {
    my ($this, $fields) = @_;

    $this->tracer($fields||'NULL') if ($this->{DEBUG});

    my $validate;
    eval {
	no strict 'refs';
	my $name = ref($this) . '::validate';
	$validate = \%$name if (%$name);
    };

    return () unless ($validate);

    $fields ||= [ keys %{$validate}];

    my @error;
    for (@$fields) {
	next unless (exists $validate->{$_});
	push(@error, $_) unless ((
				  ref $validate->{$_} eq 'CODE'
				  and $validate->{$_}->($this->{uc $_})
				 ) or (
				  not ref $validate->{$_}
				  and defined $this->{uc $_}
				  and $this->{uc $_} =~ /$validate->{$_}/
				 )
				);
    }

    return @error
}

# is_int_01 - Returns true if the argument is an integer with the value 0 or 1
sub is_int_01 {
    my $id = shift;
    return defined($id) && ($id =~ /^[01]$/);
}

# is_int_positive - Return true if the supplied value is a positive integer
sub is_int_positive {
    my $id = shift;
    return defined($id) && ($id =~ /^\d+$/) && ($id > 0);
}

# is_int_nonnegative - Return true if an integer is larger or equal to 0
sub is_int_nonnegative {
    my $id = shift;
    return defined($id) && ($id =~ /^\d+$/) && ($id >= 0);
}

# is_word - Return true if the argument is an empty string or matches the word
#           character (alphanumeric plus "_").
sub is_word {
    my $id = shift;
    return defined($id) && ($id =~ /^\w*$/);
}

# is_word_nonnull - Return true if argument matches the word character (alphanumeric plus "_").
sub is_word_nonnull {
    my $id = shift;
    return defined($id) && ($id =~ /^\w+$/);
}

# is_lang_code - Return true if the argument is a language code (eg. "en" or "en_UK").
sub is_lang_code {
    my $id = shift;
    return defined($id) && ($id =~ /^\w\w(_\w\w)?$/);
}

# is_data - Return true if the argument is a date in the format "xxxx-xx-xx". Note that no actual
#           validation of the date takes place. Only the format gets checked.
sub is_date {
    my $id = shift;
    return defined($id) && ($id =~ /^\d\d\d\d-\d\d-\d\d$/);
}

# is_time - Return true if the argument is a time value in the format "xx:xx:xx". The actual value
#           is not validated - only its format.
sub is_time {
    my $id = shift;
    return defined($id) && ($id =~ /^\d\d:\d\d:\d\d$/);
}

# is_datetime - Return true if the argument matches the date-time format "xxxx-xx-xx xx:xx:xx".
#               The actual value is not validated - only its format.
sub is_datetime {
    my $id = shift;
    return defined($id) && ($id =~ /^\d\d\d\d-\d\d-\d\d \d\d:\d\d:\d\d$/);
}

sub tracer {
    my $this = shift;
    return unless ($this->{DEBUG});

    my ($package, $filename, $line, $subroutine) = caller(1);
    local $" = ", ";
    print STDERR "- $subroutine($this, @_)\n\tat $filename: $line\n";
}

sub TO_JSON { return { %{ shift() } }; }

1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Obvius::Data - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Obvius::Data;

  # Usages of new:
  %hash = {
    param1 => value1,
    param2 => value2,
  };
  my $obj = Obvius::Data->new(\%hash);
  my $obj = Obvius::Data->new( param1 => value1, param2 => value2 );

  # Usage of clear:
  $obj->clear();

  # Usages of param:
  $obj->param(); # Returns [param1, param2]
  $obj->param('param1'); # Returns value1
  $obj->param('param1' => $new_value); # Assigns $new_value and returns value1

  # Usages of params:
  $param_hash_ref = $obj->params('param1', 'param2');
  %param_hash = $obj->params('param1', 'param2');

  # Usage of delete:
  $obj->('param2'); # Deletes param2 and returns value2

=head1 DESCRIPTION

Stub documentation for Obvius::Data, created by h2xs. It looks like the
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
