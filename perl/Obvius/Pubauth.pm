package Obvius::Pubauth;

########################################################################
#
# Obvius::Pubauth.pm - Public authentication methods for Obvius.
#
# Copyright (C) 2001 Magenta Aps, Denmark (http://www.magenta-aps.dk/)
#
# Authors: Jørgen Ulrik B. Krag <jubk@magenta-aps.dk>
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

use Data::Dumper;

our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub get_public_users {
    my ($this, $where) = @_;

    my $set=DBIx::Recordset->SetupObject(
                                            {
                                                '!DataSource' => $this->{DB},
                                                '!Table'     => 'public_users',
                                            }
                                        );


    $set->Search($where);

    my @result;

    while(my $rec = $set->Next) {
        push(@result, $rec);
    }

    return (scalar(@result) ? \@result : undef);

}

sub update_public_users {
    my ($this, $data, $where) = @_;

    my $set=DBIx::Recordset->SetupObject(
                                            {
                                                '!DataSource' => $this->{DB},
                                                '!Table'     => 'public_users',
                                            }
                                        );


    return $set->Update($data, $where);
}

sub create_public_user {
    my ($this, $data) = @_;

    my $set=DBIx::Recordset->SetupObject(
                                            {
                                                '!DataSource' => $this->{DB},
                                                '!Table'     => 'public_users',
                                            }
                                        );


    return $set->Insert($data);
}

sub delete_public_users {
    my ($this, $where) = @_;

    my $set=DBIx::Recordset->SetupObject(
                                            {
                                                '!DataSource' => $this->{DB},
                                                '!Table'     => 'public_users',
                                            }
                                        );


    return $set->Delete($where);
}

1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 Obvius::Pubauth

Obvius::Pubauth - Public authentication methods form Obvius.

=head1 SYNOPSIS

  use Obvius;
  use Obvius::Config;
  my $conf = new Obvius::Config('confname');
  my $obvius = new Obvius($conf);

  my $pub_user = $obvius->get_public_user($hashref_where);

  $obvius->create_public_user($hashref_data);

  $obvius->update_public_user($hasref_data, $hashref_where);

=head1 DESCRIPTION

Provides Obvius with methods for accessing the public_users database
table.

=head2 EXPORT

None by default.


=head1 AUTHOR

Jørgen Ulrik B. KragE<lt>jubk@magenta-aps.dkE<gt>

=head1 SEE ALSO

L<perl>.
L<Obvius>.

=cut
