package Obvius::Tables;

########################################################################
#
# Obvius.pm - Content Manager, database handling
#
# Copyright (C) 2001 Magenta Aps, Denmark (http://www.magenta-aps.dk/)
#                    aparte A/S, Denmark (http://www.aparte.dk/),
#
# Authors: René Seindal (rene@magenta-aps.dk),
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

use strict;
use warnings;

our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

########################################################################
#
#       Table(List) functions
#
########################################################################

sub get_table_data {
    my ($this, $table) = @_;

    $this->tracer($table) if ($this->{DEBUG});

    my $set = DBIx::Recordset->SetupObject({'!DataSource' => $this->{DB},
					    '!Table'      => $table,
					   } );
    $set->Search;

    my @records;
    while (my $rec = $set->Next) {
	my %new=(%$rec);
	push(@records, \%new);
    }
    $set->Disconnect;

    return \@records;
}

sub get_table_data_hash_array {
    my ($this, $table, $colname) = @_;

    return $this->get_table_data_hash($table, $colname, 'ARRAY');
}

# If cols is a ref to an array, the hash will contain keys for each record
# for each of the columns - if the columns share values/domain this will
# silently cause problems.
sub get_table_data_hash {
    my ($this, $table, $cols, $type) = @_;

    $this->tracer($table) if ($this->{DEBUG});

    $cols=[$cols] unless ref($cols) eq 'ARRAY';
    $type ||= '';

    my $set = DBIx::Recordset->SetupObject({'!DataSource' => $this->{DB},
					    '!Table'      => $table,
					    '!TieRow'     => 0,
					   } );
    $set->Search;

    my %records;
    while (my $rec = $set->Next) {
	my %new=(%$rec);
	foreach my $colname (@$cols) {
	    my $key=$rec->{$colname};
	    if (defined $key) {
		if ($type eq 'ARRAY') {
		    defined $records{$key} ? (push @{$records{$key}}, \%new)
			: ($records{$key}=[\%new]);
		}
		else {
		    warn("Duplicate key $colname:$key in table, wrong use of get_table_data_hash.")
			if (defined $records{$key});
		    $records{$key}=\%new;
		}
	    }
	    else {
		warn("No key $colname in record in table $table, wrong use of get_table_data_hash.");
	    }
	}
    }
    $set->Disconnect;

    return \%records;
}

sub get_table_record {
    my ($this, $table, $how) = @_;

    $this->tracer($table, %$how) if ($this->{DEBUG});

    my $set = DBIx::Recordset->SetupObject({'!DataSource' => $this->{DB},
					    '!Table'      => $table,
					   } );
    $set->Search($how);

    if (wantarray) {
	my @records;
	while (my $rec = $set->Next) {
	    push(@records, $rec);
	}
	$set->Disconnect;

	return @records;
    }
    my $rec = $set->First;
    $set->Disconnect;

    return $rec;
}

sub insert_table_record { # Used by a mason-component, should perhaps be changed...
    my ($this, $table, $rec) = @_;

    $this->tracer($table, %$rec) if ($this->{DEBUG});

    my $set = DBIx::Recordset->SetupObject({'!DataSource' => $this->{DB},
					    '!Table'      => $table,
					   } );

    $set->Insert($rec);
    $set->Disconnect;

    return $set->LastSerial;
}


1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Obvius::Tables - Table(List) functions for Obvius.

=head1 SYNOPSIS

  use Obvius;
  use Obvius::Config;

  my $config = new Obvius::Config("configname");
  my $obvius = new Obvius($config);

  $obvius->get_table_data();

  etc.


=head1 DESCRIPTION

This module contains functions dealing with extra database tables in Obvius,
typically used by the TableList documenttype.
It is not intended for use as a standalone module.

=head2 EXPORT

None.


=head1 AUTHORS

Adam Sjøgren E<lt>adam@aparte.dkE<gt>

Jørgen Ulrik B. Krag, E<lt>jubk@magenta-aps.dkE<gt>

=head1 SEE ALSO

L<Obvius>.

=cut
