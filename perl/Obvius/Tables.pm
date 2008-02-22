package Obvius::Tables;

########################################################################
#
# Tables.pm - generic database-table handling
#
# Copyright (C) 2001-2004 Magenta Aps, Denmark (http://www.magenta-aps.dk/)
#                         aparte A/S, Denmark (http://www.aparte.dk/),
#
# Authors: René Seindal,
#          Adam Sjøgren (asjo@magenta-aps.dk),
#          Jørgen Ulrik B. Krag (jubk@magenta-aps.dk)
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

use Carp;

our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

########################################################################
#
#       Table(List) functions
#
########################################################################

# get_table_data - given a tablename and some option-pairs, search the
#                  table in the database and returns either an
#                  array-ref to hash-refs with the data (scalar
#                  context) or the array-ref and the total number of
#                  rows in the table (array context).
#                  Options can be:
#                   * start   - offset into the list
#                   * max     - maximum number of records to return
#                   * sort    - what column to sort the table by (before applying start and max)
#                   * reverse - reverses the sort, if true
#                   * where   - conditions for selection of data
sub get_table_data {
    my ($this, $table, %options) = @_;

    my %search_options=();
    $search_options{'$start'}=$options{start} if (defined $options{start});
    $search_options{'$max'}=$options{max} if (defined $options{max});
    $search_options{'$order'}=$options{sort} if (defined $options{sort});
    $search_options{'$order'}.=' DESC' if (defined $search_options{'$order'} and $options{reverse});

    $search_options{'$where'}=$options{where} if (defined $options{where});

    my $set = DBIx::Recordset->SetupObject({'!DataSource' => $this->{DB},
                                            '!Table'      => $table,
                                            '!TieRow'     => 0,
                                           } );

    $set->Search(\%search_options);

    my @records;
    while (my $rec = $set->Next) {
        my %new=(%$rec);
        push(@records, \%new);
    }
    $set->Disconnect;

    if (wantarray) {
        return (\@records, $this->db_number_of_rows_in_table($table, $search_options{'$where'}));
    }
    else {
        return \@records;
    }
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

# get_table_record - performs a search of the database table using the
#                    key-value pairs of the hash-ref given as the
#                    second argument.
#                    If called in array-context: returns an array of
#                    the matches. In scalar context the first is
#                    returned.
#
#                    XXX add type (ref) check on $how?
sub get_table_record {
    my ($this, $table, $how) = @_;

    $this->db_begin;
    my @records=();
    my $rec=undef;
    my $wantarray=wantarray; # Changes inside the eval!
    eval {
        my $set = DBIx::Recordset->SetupObject({'!DataSource' => $this->{DB},
                                                '!Table'      => $table,
                                                '!TieRow'     => 0,
                                           } );
        $set->Search($how);

        if ($wantarray) {
            while (my $rec = $set->Next) {
                push(@records, $rec);
            }
        }
        else {
            $rec = $set->First;
        }
        $set->Disconnect;

        $this->db_commit;
    };

    my $ev_error=$@;
    if ($ev_error) {
        $this->db_rollback;
        return undef;
    }

    return ($wantarray ? @records : $rec);
}

# insert_table_record ($table, $rec) - Inserts a row into a database table. 
#                                      $rec should be a hash, or a reference to a hash,
#                                      of fieldnames and values to be inserted into
#                                      the table.
#                                      Returns true on succes.
#                                      If an error occurs upon insertion the transaction
#                                      is rolled back and the function returns undef.
sub insert_table_record {
    my ($this, $table, $rec) = @_;

    my $ret;
    eval {
        my %conf=(
                  '!DataSource' => $this->{DB},
                  '!Table'      => $table,
                  '!TieRow'     => 0,
                  '!Serial'     => 'id', # Does this break, if the table has no id-column?
                 );
	# XXX assert
	Carp::confess("assert(id==0), please remove") 
		if exists $rec->{id} and $rec->{id} eq '0';
        my $set = DBIx::Recordset->SetupObject(\%conf);

        $ret=$set->Insert($rec);

        my $last_serial=$set->LastSerial;
        $ret=(defined $last_serial ? $last_serial : $ret);

        $set->Disconnect;

    };

    my $ev_error=$@;
    if ($ev_error) {
        return undef;
    }

    return $ret;
}

# XXX asjo TODO: clean up this method, and adjust callers appropriately.

sub delete_table_record {
    my ($this, $table, $rec, $where) = @_;

    return unless (ref $rec eq 'HASH');
    return if (!defined $rec->{id} and !defined $where); # XXX See update_table_record.

    $this->db_begin;
    my $err;
    eval {
        my %set_source=(
                        '!DataSource' => $this->{DB},
                        '!Table'      => $table,
                        '!TieRow'     => 0,
                       );
        $set_source{'!PrimKey'}='id' if (defined $rec->{id});
        my $set = DBIx::Recordset->SetupObject(\%set_source);

        $err=$set->Delete($where); # XXX - Changed, is delete table record in use anywhere? Anyone? Someone? Speak up!
        $set->Disconnect;

        $this->db_commit;
    };

    my $ev_error=$@;
    if ($ev_error) {
        $this->db_rollback;
        return undef;
    }

    $err=0 if ($err eq '0E0');
    return $err;
}

sub update_table_record {
    my ($this, $table, $rec, $where) = @_;

    return unless ($table);
    return unless (ref $rec eq 'HASH');
    return if (!defined $rec->{id} and !defined $where); # XXX This does not check that the $where
                                                         #     supplied only matches one row.

    my %set_source=(
                    '!DataSource' => $this->{DB},
                    '!Table'      => $table,
                    '!TieRow'     => 0,
                   );
    $set_source{'!PrimKey'}='id' if (defined $rec->{id});
    my $set = DBIx::Recordset->SetupObject(\%set_source);

    my $err=$set->Update($rec, $where);
    $set->Disconnect;

    $err=0 if ($err eq '0E0');
    return $err;
}

# table_exists(table) - returns false if the table does not
#                       exist. Otherwise true.
sub table_exists {
    my ($this, $table)=@_;

    return exists $this->{DB}->AllTables->{$table};
}

# fieldnames_exist(table, fieldnames) - returns true if all the
#                                       fieldnames exist in the table,
#                                       returns false
#                                       otherwise. Assumes that $table
#                                       exists.
sub fieldnames_exist {
    my ($this, $table, $fieldnames)=@_;

    return unless ($table and $this->table_exists($table));
    croak 'fieldnames must be a reference to an array' unless (ref $fieldnames eq 'ARRAY');

    my %names=map { $_=>1 } @{$this->{DB}->AllNames($table)};

    foreach my $fieldname (@$fieldnames) {
        return 0 unless ($names{$fieldname});
    }

    return 1;
}

1;
__END__

=head1 NAME

Obvius::Tables - Table(List) functions for Obvius.

=head1 SYNOPSIS

  use Obvius;
  use Obvius::Config;

  my $config = new Obvius::Config("configname");
  my $obvius = new Obvius($config);

  $obvius->get_table_data();

  $bool=$obvius->table_exists($table);
  $bool=$obvius->fieldnames_exist($table, ['fieldname1', 'fieldname2']);

  my $recs=$obvius->get_table_data('comments', start=>10, max=>5, order=>'date', reverse=>1);
  my ($recs, $total)=$obvius->get_table_data('comments');

  my $rec=$obvius->get_table_record('annotations', { docid=>$vdoc->Docid, version=>$vdoc->Version });
  my @recs=$obvius->get_table_record('comments', { docid=>$doc->Id });

  $obvius->insert_table_record('comments', {foo=>'bar', spam=>'ham'});
  my %record = (foo=>'bar', spam=>'ham')
  $obvius->insert_table_record('comments', \%record);

=head1 DESCRIPTION

This module contains functions dealing with extra database tables in Obvius,
typically used by the TableList documenttype.
It is not intended for use as a standalone module.

This module is a bit of a code-bastard - it does not follow the lead
from Obvius and Obvius::DB where only the db_*-functions in Obvius::DB
directly use DBIx::RecordSet to manipulate the database, while the non
db_*-functions in Obvius package their call to db_*s in eval.

=head1 TODO

Do the eval, commit/rollback-thing here as well (see DB.pm). Perhaps
put the direct database-stuff in DB.pm and call it from here inside
eval.

=head2 EXPORT

None.

=head1 AUTHORS

René Seindal
Adam Sjøgren E<lt>asjo@magenta-aps.dkE<gt>
Jørgen Ulrik B. Krag, E<lt>jubk@magenta-aps.dkE<gt>

=head1 SEE ALSO

L<Obvius>, L<Obvius::DB>.

=cut
