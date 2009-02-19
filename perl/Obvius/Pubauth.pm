package Obvius::Pubauth;

########################################################################
#
# Obvius::Pubauth.pm - Public authentication methods for Obvius.
#
# Copyright (C) 2004-2005 Magenta Aps, Denmark (http://www.magenta-aps.dk/)
#
# Authors: Jørgen Ulrik B. Krag <jubk@magenta-aps.dk>
#          Adam Sjøgren <asjo@magenta-aps.dk>
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

use POSIX qw(strftime);

our $VERSION="1.0";

# get_public_users($how) -
# Gets a list of public users matching the $how statement. Returns
# the list of users or undef if no users were found.
sub get_public_users {
    my ($this, $where) = @_;

    my $set=DBIx::Recordset->SetupObject(
                                            {
                                                '!DataSource' => $this->{DB},
                                                '!Table'     => 'public_users',
                                                '!TieRow'    => 0,
                                            }
                                        );


    $set->Search($where);

    my @result;

    while(my $rec = $set->Next) {
        push(@result, $rec);
    }

    return (scalar(@result) ? \@result : undef);

}

# update_public_users($datahashrefs, $where) -
# Updates the public users specified by $where with the data in
# $datahashref.
sub update_public_users {
    my ($this, $data, $where) = @_;

    my $set=DBIx::Recordset->SetupObject(
                                            {
                                                '!DataSource' => $this->{DB},
                                                '!Table'     => 'public_users',
                                                '!TieRow'    => 0,
                                            }
                                        );


    return $set->Update($data, $where);
}

# create_public_user($datahashref) -
# Creates a public user using the data in $datahasref.
# Returns the id of the new public user.
sub create_public_user {
    my ($this, $data) = @_;

    my $set=DBIx::Recordset->SetupObject(
                                            {
                                                '!DataSource' => $this->{DB},
                                                '!Table'     => 'public_users',
                                                '!TieRow'    => 0,
                                                '!Serial'   => 'id'
                                            }
                                        );


    $set->Insert($data);

    return $set->LastSerial;
}


# delete_public_users($where) -
# Deletes the public users specified by $where.
sub delete_public_users {
    my ($this, $where) = @_;

    my $set=DBIx::Recordset->SetupObject(
                                            {
                                                '!DataSource' => $this->{DB},
                                                '!Table'     => 'public_users',
                                                '!TieRow'    => 0,
                                            }
                                        );


    return $set->Delete($where);
}

# Metadata

# insert_public_user_metadata($user, $metadataname, $metadatavalueref) -
# inserts a list of metadata values for a given user
# and metadata name.
sub insert_public_user_metadata {
    my ($this, $user, $name, $values) = @_;

    return undef unless($user);
    return undef unless(ref($values) and ref($values) eq 'ARRAY');

    my $set=DBIx::Recordset->SetupObject(
                                            {
                                                '!DataSource' => $this->{DB},
                                                '!Table'     => 'public_users_metadata',
                                                '!TieRow'    => 0,
                                            }
                                        );
    for my $value (@$values) {
        $set->Insert({user_id => $user->{id}, name => $name, value => $value});
    }

    return 1;
}

# insert_public_user_metadata_values($user, $nameslistref) -
# Lookups the metadata specified in by the nameslistref
# and put the values on the $user object.
sub get_public_user_metadata {
    my ($this, $user, $nameslist) = @_;

    return undef unless($user);
    return undef unless(ref($nameslist) and ref($nameslist) eq 'ARRAY');

    my $set=DBIx::Recordset->SetupObject(
                                            {
                                                '!DataSource' => $this->{DB},
                                                '!Table'     => 'public_users_metadata',
                                                '!TieRow'    => 0,
                                            }
                                        );
    for my $name (@$nameslist) {
        $set->Search({user_id => $user->{id}, name => $name});

        my @result;
        while(my $rec = $set->Next) {
            push(@result, $rec->{value});
        }

        $user->{$name} = \@result;
    }

    $set->Disconnect;

    return 1;
}

# delete_public_user_metadata -
# Deletes metadata for a given user and metadata name.
sub delete_public_user_metadata {
    my ($this, $user, $name) = @_;

    my $set=DBIx::Recordset->SetupObject(
                                            {
                                                '!DataSource' => $this->{DB},
                                                '!Table'     => 'public_users_metadata',
                                                '!TieRow'    => 0,
                                            }
                                        );
    return $set->Delete({user_id => $user->{id}, name => $name});

}

## Handle public_users_areas:

# create_public_user_area - adds the supplied user to the given
#                           area. Returns an error if the user
#                           couldn't be added or if the user is
#                           already a member.
sub create_public_user_area {
    my ($obvius, $user, $area)=@_;
    return undef if ($obvius->get_public_user_area($user, $area));

    my $now=strftime('%Y-%m-%d %H:%M:%S', localtime);

    return $obvius->insert_table_record('public_users_areas',
                                        {
                                         public_userid=> $user->{id},
                                         docid=>         $area->{docid},
                                         created=>       $area->{created} || $now,
                                         modified=>      $area->{modified} || $now,
                                         activated=>     $area->{activated} || '0000-01-01 00:00:00',
                                         expires=>       $area->{expires} || '0000-01-01 00:00:00',
                                        }
                                       );

}

# get_public_user_areas - returns an array-refs to hash-refs of the
#                         areas that the given user belongs
#                         to. Returns the empty list if none, returns
#                         error if the user does not exist.
sub get_public_user_areas {
    my ($obvius, $user)=@_;
    return undef unless ($obvius->get_public_user({ id=>$user->{id} }));

    my @areas=$obvius->get_table_record('public_users_areas', { public_userid=>$user->{id} }); # array context
    return \@areas;
}

# get_public_user_area - returns a hash-refs of the area for the
#                        user. Error if the user doesn't exist or if
#                        the user isn't in the area.
sub get_public_user_area {
    my ($obvius, $user, $area)=@_;
    return undef unless ($obvius->get_public_user({ id=>$user->{id} }));
    #return undef unless (); # Check area? get_area(?) ?

    return $obvius->get_table_record('public_users_areas', { public_userid=>$user->{id}, docid=>$area->{docid} });
}

# get_public_users_area - returns an array-ref containing the matching
#                         users in the area. If the area does not
#                         specifiy a docid, matching users in all
#                         areas are returned. Returns an empty
#                         array-ref if there are none.
sub get_public_users_area {
    my ($obvius, $area, %options)=@_;

    my $now=strftime('%Y-%m-%d %H:%M:%S', localtime);

    my @users=();
    my %search_options;
    $search_options{docid}=$area->{docid} if (defined $area->{docid});
    my @recs=$obvius->get_table_record('public_users_areas', \%search_options);

    my $ret=1;
    foreach my $rec (@recs) {
        if ($options{activated}) {
            my $take=1;
            $take=0 if ($rec->{activated} eq '0000-01-01 00:00:00'); # Not activated
            $take=0 unless ($rec->{activated} le $options{activated} and # Activated before now
                            $options{activated} lt $rec->{expires});     # and now is before expiry

            next unless ($options{not} ? !$take : $take);
        }
        if ($options{expires}) { # Either a date...
            if ($options{expires}=~/^[+](\d+)d$/) { # or "+Nd" for N days
                $options{expires}=strftime('%Y-%m-%d %H:%M:%S', localtime(time()+$1*24*60*60));
            }
            next unless ($rec->{expires} ge $now and $rec->{expires} le $options{expires}); # Today 'till option
        }

        if (my $user=$obvius->get_public_user({ id=>$rec->{public_userid} })) {
            push @users, $user;
        }
        else {
            $ret=0;
            $obvius->log->warn('In area ', $area->{docid}, ' the public_userid ', $rec->{public_userid}, ' exists, but it can\'t be found in public_users!');
        }
    }

    return \@users;
}

# get_public_user_area_docs - returns an array-ref to a list
#                             containing document-objects for the
#                             areas available.
sub get_public_user_area_docs {
    my ($obvius, $doctypename)=@_;

    my $doctype=$obvius->get_doctype_by_name($doctypename);
    return undef unless ($doctype);

    my @list=();

    my $vdocs=$obvius->search([], 'type=' . $doctype->Id, public=>1, notexpired=>1);
    foreach my $vdoc (@$vdocs) {
        my $doc=$obvius->get_doc_by_id($vdoc->Docid);
        push @list, $doc if ($doc);
    }

    return \@list;
}

# delete_public_user_area - remove the supplied user from the given
#                           area. Returns an error if the user is not
#                           in the area or if the deletion didn't work
#                           out.
sub delete_public_user_area {
    my ($obvius, $user, $area)=@_;
    return undef unless ($obvius->get_public_user_area($user, $area));

    return $obvius->delete_table_record('public_users_areas', {}, { public_userid=>$user->{id}, docid=>$area->{docid} });
}

# delete_public_user_areas - removes the supplied user from all
#                            areas. (delete_public_user should call
#                            this).
sub delete_public_user_areas {
    my ($obvius, $user)=@_;
    return undef unless ($obvius->get_public_user({ id=>$user->{id} }));

    return $obvius->delete_table_record('public_users_areas', {}, { public_userid=>$user->{id} });
}

# update_public_user_area - changes the area-registration of the given
#                           user. Returns an error if the update
#                           couldn't be done or if the user is not in
#                           the supplied area.
sub update_public_user_area {
    my ($obvius, $user, $area)=@_;
    return undef unless ($obvius->get_public_user_area($user, $area));

    return $obvius->update_table_record('public_users_areas', $area, { public_userid=>$user->{id}, docid=>$area->{docid} });
}

# update_public_user_areas - given an array-ref of the all the areas
#                            the user should have, deletes the ones
#                            that exist but aren't in the new areas,
#                            updates the ones that are there and
#                            should be, and finally creates new ones.
#                            Returns true if everything went well,
#                            false if there was at least one error.
sub update_public_user_areas {
    my ($obvius, $user, $areas)=@_;
    return undef unless ($obvius->get_public_user({ id=>$user->{id} }));
    return undef unless (ref $areas eq 'ARRAY');

    my $now=strftime('%Y-%m-%d %H:%M:%S', localtime);

    # (Transaction begin)
    my $ret=1;
    #  delete areas that no longer should be there:
    my %areas=map { $_->{docid}=>1 } @$areas;
    my $existing_areas=$obvius->get_public_user_areas($user);
    foreach my $existing_area (@$existing_areas) {
        print STDERR "DELETING AREA $existing_area->{docid}\n" unless ($areas{$existing_area->{docid}});
        if (!$areas{$existing_area->{docid}}) {
            $ret=0 unless ($obvius->delete_public_user_area($user, $existing_area));
        }
    }
    #  update existing/create new:
    foreach my $new_area (@$areas) {
        if (my $existing_area=$obvius->get_public_user_area($user, $new_area)) { # It exists
            # Update the existing area:
            #  set modified to now, copy activated and expires from the new area if they are defined
            #  created is not changed, ever.
            $existing_area->{modified}=$now;
            map { $existing_area->{$_}=$new_area->{$_} if defined $new_area->{$_} } qw(activated expires);
            print STDERR "UPDATING AREA $existing_area->{docid}\n";
            $ret=0 unless ($obvius->update_public_user_area($user, $existing_area));
        }
        else { # It's a brand new one:
            print STDERR "CREATING AREA $new_area->{docid}\n";
            $ret=0 unless ($obvius->create_public_user_area($user, $new_area));
        }
    }
    # (Commit if no errors)

    return $ret;
}

## Missing helpers

# get_public_user - given a hash-ref that matches exactly one public
#                   user, returns a hash-ref with the user-data. If
#                   more than one user or no user matches, then undef
#                   is returned.
sub get_public_user {
    my ($obvius, $how)=@_;

    my $users;
    if ($users=$obvius->get_public_users($how) and scalar(@$users)==1) {
        return $users->[0];
    }

    return undef;
}

1;
__END__

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

=head1 AUTHORS

Jørgen Ulrik B. KragE<lt>jubk@magenta-aps.dkE<gt>
Adam Sjøgren E<lt>asjo@magenta-aps.dkE<gt>

=head1 SEE ALSO

L<perl>.
L<Obvius>.

=cut
