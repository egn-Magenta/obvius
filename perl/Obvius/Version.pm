package Obvius::Version;

########################################################################
#
# Version.pm - Version of a Document
#
# Copyright (C) 2001-2004 Magenta Aps, Denmark (http://www.magenta-aps.dk/)
#                         aparte A/S (http://www.aparte.dk/)
#
# Authors: Jørgen Ulrik B. Krag (jubk@magenta-aps.dk),
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

use Obvius::Data;
use WebObvius::InternalProxy;

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

sub list_valid_keys {
    my ($this) = @_;

    return [
	    { docid=>$this->{DOCID}, version=>$this->{VERSION}, lang=>$this->{LANG} },
	   ];
}

sub real_doctype {
     my ($this, $obvius) = @_;
     my $ip = WebObvius::InternalProxy->new($obvius);

     if($ip->is_internal_proxy_document($vdoc->Docid)) {
	  return $obvius->get_doctype_by_name('InternalProxy');
     } else {
	  return $obvius->get_doctype_by_id($this->Type);
     }
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

# field - takes a fieldname, an optional value and an optional
#         type. If value is defined, the field is set to value in the
#         relevant type of fields (either 'FIELDS' or
#         'PUBLISH_FIELDS') and the old value is returned. If value
#         isn't defined, the current value is returned.  Note that the
#         type-argument shouldn't be used by any other method than
#         Obvius::Version->publish_field(s). Thank you.
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

=head1 NAME

Obvius::Version - Perl object for a version (vdoc).

=head1 SYNOPSIS

  my $cur_value=$vdoc->field('title');
  my $old_value=$vdoc->field(title=>'New text');
  $vdoc->publish_field(lprio=>3);
  my $p_value=$vdoc->publish_field('ldura');

=head1 DESCRIPTION

This implements the version-object for Obvius by extending the generic
Obvius::Data with specialized AUTOLOAD and field-methods..

=head1 AUTHORS

Jørgen Ulrik B. Krag E<lt>jubk@magenta-aps.dkE<gt>,
René Seindal,
Adam Sjøgren E<lt>asjo@magenta-aps.dkE<gt>

=head1 SEE ALSO

L<Obvius::Document>, L<Obvius::Data>.

=cut
