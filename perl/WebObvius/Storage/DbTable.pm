package WebObvius::Storage::DbTable;

########################################################################
#
# DbTable.pm - Database table storage-type for edit engine.
#
# Copyright (C) 2004 Magenta Aps, Denmark (http://www.magenta-aps.dk/)
#
# Authors: Jens K. Jensen (jensk@magenta-aps.dk),
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

use Carp;

use WebObvius::Storage;

our @ISA = qw( WebObvius::Storage );
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

# Internal methods:

sub new {
    my ($class, $options, $obvius)=@_;

    my $this=$class->SUPER::new(%$options, obvius=>$obvius);

    # Perform sanity-check; does the table exist, do the identifier(s)?
    if (!$obvius->table_exists($this->param('source'))) {
        carp __PACKAGE__ . '::new called with non-existing table: ' . $this->param('source');
        return undef;
    }
    if (!$obvius->fieldnames_exist($this->param('source'), $this->param('identifiers'))) {
        carp __PACKAGE__ . '::new called with at least one non-existing fieldname (source: ' . $this->param('source') . ')';
        return undef;
    }

    return $this;
}


sub lookup {
    my ($this, %how)=@_;

    my @existing_identifiers = grep {exists $how{$_}} @{$this->param('identifiers')};

    my $object = {
                  map {
                      $_ => $how{$_}
                  } @existing_identifiers
                 };

    if (scalar(@existing_identifiers) != scalar(@{$this->param('identifiers')})) {
        return ($object, undef);
    }
    else {
        my $record_data = $this->param('obvius')->get_table_record($this->param('source'), \%how) if %how;
        my $record =  {
                       map { $_ => {
                                    value => $record_data->{$_},
                                    status => 'OK',
                                   }
                         } keys %$record_data
                      };
        return ($object, $record);
    }
}


# Public methods:

sub create {
    my ($this, $data, $session, $path_prefix)=@_;

    use Data::Dumper; print STDERR 'DbTable->create $data: ' . Dumper($data);


    my $success=0;
    my $error=0;
    my $results;
    # Create all objects

    my @object_identifiers = keys %{$data->{$path_prefix}};
    foreach my $object_id (@object_identifiers) {

        # Retrieve object data
        my $object = $data->{$path_prefix}->{$object_id};

        my $ids = $this->key_to_identifiers($object_id);

        # Add non-anonymous identifiers to object data
        $object = {
                   %$object,
                   %$ids,
                  };

        my $LastSerial = $this->param('obvius')->insert_table_record($this->param('source'), $object);

        # Replacing 'anonymous' part of object_id with $LastSerial requires sorting??
        my @missing_identifiers = grep { !defined $ids->{$_} } @{$this->param('identifiers')};
        my $anonymous = shift @missing_identifiers;
        if (scalar(@missing_identifiers) > 1) {
            warn "DbTable.pm: Unable to determine newly created object!\n";
        }
        elsif ($anonymous) {
            $object = { %$object, $anonymous => $LastSerial };
        }

        # Modify the object_id in case of anonymous objects
        my $new_object_id = $this->object_key($object);

        # [!] Note: The full object should be stored for return here
        $results->{$new_object_id} = $object;

        if (defined $LastSerial) {
            $success++;
        }
        else {
            $error++;
        }
    }

    return ('ERROR', "Could not create $error of the " . ($error+$success) . " entries", $results) if $error > 0;
    return ('OK', "$success entries created", $results);
}


sub update {
    my ($this, $data, $session, $path_prefix)=@_;

    # Update all objects
    foreach my $object_id (keys %{$data->{$path_prefix}}) {

        my $ids = $this->key_to_identifiers($object_id);

        my $id_values=$this->check_identifiers_in_data($ids);
        unless ($id_values) {
            warn 'Identifiers not specified for update';
            next;
        }

        # Get object
        my $object=$data->{$path_prefix}->{$object_id};

        # Reuse old data as requested
        if (defined $this->param('reuse') and scalar(@{$this->param('reuse')})) {
            my $previous_object = $this->param('obvius')->get_table_record($this->param('source'), $ids);
            foreach my $param (@{$this->param('reuse')}) {
                $object->{$param} = $previous_object->{$param} unless $object->{$param};
            }
        }

        # Add non-anonymous identifiers to object data
        $object = {
                   %$object,
                   %$ids,
                  };

        $this->param('obvius')->update_table_record($this->param('source'), $object, $id_values);
    }
}


sub remove {
    my ($this, $data, $session, $path_prefix)=@_;

    use Data::Dumper; print STDERR 'DbTable->remove $data: ' . Dumper($data);

    my $success=0;
    my $error=0;
    # Remove all objects
    foreach my $object_id (keys %{$data->{$path_prefix}}) {

        # Object identification
        my $object = $this->key_to_identifiers($object_id);

        # Check and retrieve object identifiers
        my $id_values=$this->check_identifiers_in_data($object);
#        ('ERROR', 'Identifiers not specified for remove') unless ($id_values);
        unless ($id_values) {
            $error++;
            next;
        }

        if ($this->param('obvius')->delete_table_record($this->param('source'), $object, $id_values)) {
            $success++;
        }
    }
    return ('ERROR', "Could not delete $error of the " . ($error+$success) . " entries") if $error > 0;
    return ('OK', "$success entries deleted");

}


sub check_identifiers_in_data {
    my ($this, $data)=@_;

#   Check and return object identifiers
    my %values=();
    foreach my $identifier (@{$this->param('identifiers')}) {
        if (!defined $data->{$identifier}) {
            carp __PACKAGE__ . ' called without required identifier: ' . $identifier . ' in data (source: ' . $this->param('source') . ')';
            return undef;
        }
        else {
            $values{$identifier} = $data->{$identifier};
        }
    }
#use Data::Dumper; print STDERR '\%values: ' . Dumper(\%values);

    return \%values;
}


# list - returns an array-ref to the elements and the total number of
#        elements in the entire list.
#        Options can be one or more of:
#         * start=>N          (first element is number N)
#         * max=>M            (at most return M elements; can return less)
#         * sort=>'fieldname' (sort by fieldname)
#         * reverse=>0|1      (reverse the sort)
sub list {
    my ($this, $object, $options)=@_;

    my @where = map {"$_='$object->{$_}'"} keys %$object;
    push @where, $this->param('where') if $this->param('where');
    $options->{where} = join(' and ', @where) if @where;

    my ($table_data, $total) = $this->param('obvius')->get_table_data($this->param('source'), %$options);
    my @list;
    foreach my $entry (@$table_data) {
        push @list, {
                     map { $_ => {
                                  value => $entry->{$_},
                                  status => 'OK',
                                 }
                       } keys %$entry
                    };
    }
    return \@list, $total;
}

# sub checklist {
#     my ($this, %options)=@_;

#     my $where = join " and ", map {"$_='$options{$_}'"} keys %options;
#     print STDERR '$where:' , $where;
#     my %db_options = (
#                       where => $where,
#                      );
#     return $this->param('obvius')->get_table_data($this->param('source'), %db_options);
# }

sub element {
    my ($this, %how)=@_;

    # Return in case of undefined object
    return {} unless scalar(keys %how);

    # Check for partial object
    my @missing_identifiers = grep { !defined $how{$_} } @{$this->param('identifiers')};
    if (scalar(@missing_identifiers)) {
        my $partial_object = {
                              map { $_ => {
                                           value => $how{$_},
                                           status => 'OK',
                                          }
                                } keys %how
                             };
        return $partial_object;
    }

    my $record_data = $this->param('obvius')->get_table_record($this->param('source'), \%how);
    my $record =  {
                   map { $_ => {
                                value => $record_data->{$_},
                                status => 'OK',
                               }
                     } keys %$record_data
                  };
    return $record;
}

1;
__END__

=head1 NAME

WebObvius::Storage::DbTable - container class for editengine storage-types.

=head1 SYNOPSIS

  use WebObvius::Storage::DbTable;

  my ($elements, $total)=$storage->list(start=>10, max=>10, sort=>'name', reverse=>1);

=head1 DESCRIPTION

This class stores data in database tables.

=head1 AUTHORS

Jens K. Jensen (jensk@magenta-aps.dk),
Adam Sjøgren (asjo@magenta-aps.dk).

=head1 SEE ALSO

L<WebObvius::Storage>

=cut
