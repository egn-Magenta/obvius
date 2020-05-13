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
use Data::Dumper;

use Obvius::Data;
use WebObvius::InternalProxy;

our @ISA = qw( Obvius::Data );
our $VERSION="1.0";

our %SOLR_MAPS = ();
our %SOLR_FIELD_LISTS = ();

our %NEWS_FEED_FIELD_MAPS = ();

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

     if($obvius->dbprocedures->is_internal_proxy_document($this->Docid)) {
	  return $obvius->get_doctype_by_name('InternalProxy');
     } else {
	  return $obvius->get_doctype_by_id($this->Type);
     }
}

##############################
####### Export to JSON #######
##############################
sub export_to_news_feed {
    my ($self, $obvius, $hostmap) = @_;

    my $doctype = $obvius->get_doctype_by_id($self->Type);
    $hostmap ||= $obvius->config->param('hostmap') || Obvius::Hostmap->new_with_obvius($obvius);

    # These are used as function arguments when processing values
    my %context = ('hostmap' => $hostmap, 'obvius' => $obvius);

    # Load cached fieldmap if possible, set cache otherwise
    my $fieldmap = $NEWS_FEED_FIELD_MAPS{$doctype->Id};
    if (!$fieldmap) {
        $fieldmap = $NEWS_FEED_FIELD_MAPS{$doctype->Id} = $doctype->get_news_feed_fields();
    }

    # We preload vfield data to avoid individual calls to get_version_fields
    # For fields with source marked as 'vfield', use the overridden field name or the key itself
    my @vfield_list = map { $fieldmap->{$_}->{field_name} || $_ } grep { $fieldmap->{$_}->{source} eq 'vfield' } keys %{$fieldmap};
    $obvius->get_version_fields($self, \@vfield_list);

    my $result = {};
    # Iterate over keyvalpairs in fieldmap
    while (my ($name, $field_spec) = each %{$fieldmap}) {
        my $source = $field_spec->{source};
        my $field_name = $field_spec->{field_name} || $name;
        my $raw_value = '';
        if ($source eq 'vfield') {
            $raw_value = $self->field($field_name);
        } elsif ($source eq 'version') {
            $raw_value = $self->$field_name;
        }

        # If field has a custom function defined
        if ((my $func = $field_spec->{function})) {
            # Allow loading %context into function
            my $extra_arg_names = $field_spec->{function_extra_args};
            my %extra_args;
            if ($extra_arg_names) {
                %extra_args = %{ {map { $_ => $context{$_}} @$extra_arg_names }};
            }
            # Call function with optional extra args
            $result->{$name} = $func->($raw_value, %extra_args);
        } else {
            $result->{$name} = $raw_value;
        }
    }
    return $result;
}

####################################################
######## Export to SOLR
####################################################
sub export_to_solr {
    my($self, $obvius, $doc) =  @_;

    ### Get document if not supplied
    $doc = ($doc && ref($doc) eq 'Obvius::Document' ? $doc : 
	    $obvius->get_doc_by_id($self->DocId));
    my $doctype = $obvius->get_doctype_by_id($self->Type);

    #### Get specs (either from "cache" og by asking doctype object)
    my $fieldsmap = $SOLR_MAPS{$doctype->Id};
    my $fieldlist = $SOLR_FIELD_LISTS{$doctype->Id};
    unless ( $fieldsmap ) {
	if ( $doctype->Name =~ /^GeoNat/ ) {
	    print STDERR "GotOne\n";
	}
	$fieldsmap = $SOLR_MAPS{$doctype->Id} = $doctype->get_solr_fields($obvius);
	$fieldlist = [];
	foreach my $mkey ( keys(%$fieldsmap) ) {
	    my $spec = $fieldsmap->{$mkey};
	    push(@$fieldlist, $mkey) if ( $spec->[0] eq 'f' );
	    push(@$fieldlist, $spec->[4]) if ( ($spec->[3] || '') eq 'f' );
	}
	$SOLR_FIELD_LISTS{$doctype->Id} = $fieldlist;
    }

    #### Get version fields
    $obvius->get_version_fields($self, $fieldlist);

    my $specs = {};
    foreach my $key ( keys(%$fieldsmap) ) {
	my $entry = $fieldsmap->{$key};
	$key =~ s/^\*+|\*+$//g;
	my $conv = $entry->[2];
	my $value;
	if ( $entry->[0] eq 'd' ) {
	    $value = $doc->$key;
	} elsif ( $entry->[0] eq 'v' ) {
	    $value = $self->$key;
	} elsif ( $entry->[0] eq 'f' ) {
	    $value = $self->field($key);
	}
	if ( (!ref($value) && $value) || (ref($value) eq 'ARRAY' && $#$value > -1) ) {
	    $specs->{$entry->[1]} = $conv ? $conv->($value) : $value;
	}
	else {
	    #### Check for alternative CMS value and use it if so
	    if ( $key = $entry->[4] ) {
		if ( $entry->[3] eq 'd' ) {
		    $value = $doc->$key;
		} elsif ( $entry->[3] eq 'v' ) {
		    $value = $self->$key;
		} elsif ( $entry->[3] eq 'f' ) {
		    $value = $self->field($key);
		}
		if ( (!ref($value) && $value) || (ref($value) eq 'ARRAY' && $#$value > -1) ) {
		    $specs->{$entry->[1]} = $conv ? $conv->($value) : $value;
		}
	    }
	}
    }

    return $specs;
}

sub delete_from_solr {
    my($self, $obvius, $doc) =  @_;

    my $specs = { 'id' => $self->DocId };
    print STDERR Dumper($specs);
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
