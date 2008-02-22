package Obvius::Users;

########################################################################
#
# Users.pm - User/Group handling methods for L<Obvius>.
#
# Copyright (C) 2001-2004 Magenta Aps, Denmark (http://www.magenta-aps.dk/)
#                         aparte A/S, Denmark (http://www.aparte.dk/),
#                         FI, Denmark (http://www.fi.dk/)
#
# Authors: Jørgen Ulrik B. Krag (jubk@magenta-aps.dk),
#          Peter Makholm (pma@fi.dk)
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

use strict;
use warnings;

our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

########################################################################
#
#       User and group information retrieval
#
########################################################################

# get_user - given a user id, returns a hash-ref with the information
#            of the corresponding user, if any.
sub get_user {
    my ($this, $userid) = @_;
    return undef unless (defined $userid);

    return $this->{USERS}->{$userid};
}

# get_userid - given a string containing a username, returns the id of
#              the user.
sub get_userid {
    my ($this, $user) = @_;
    return undef unless (defined $user);

    #my($userid)=grep { $this->{USERS}->{$_}->{login} eq $user } keys %{$this->{USERS}};
    #return $userid;
    return $this->{USERS}->{$user}->{id};
}

sub get_group {
    my ($this, $grpid) = @_;
    return undef unless (defined $grpid);

    return $this->{GROUPS}->{$grpid};
}

# get_grpid - given a string with a group name, returns the
#             corresponding group id, if any.
sub get_grpid {
    my ($this, $grp) = @_;

    my($grpid)=grep { $this->{GROUPS}->{$_}->{name} eq $grp } keys %{$this->{GROUPS}};
    return $grpid;
}

# get_user_groups - returns an array-ref to the ids of the groups that
#                   the user identified by the userid argument belongs to.
sub get_user_groups {
    my ($this, $userid) = @_;

    return [map { $_->{grp} } @{$this->{USER_GROUPS}->{$userid}}];
}

sub get_group_users {
    my ($this, $grpid) = @_;

    return [map { $_->{user} } @{$this->{GROUP_USERS}->{$grpid}}];
}

sub validate_user {
    my ($this) = @_;

    if ( $this->{USER} eq 'nobody') {
        # nobody can never login interactively, but only programmatically
        # with password set to undef
        return not defined $this-> {PASSWORD};
    }

    $this->read_user_and_group_info();

    if (my $crypted=$this->{USERS}->{$this->{USER}}->{passwd}) {
        return ((crypt($this->{PASSWORD}, $crypted) eq $crypted));
    }
    return undef;
}

sub read_user_and_group_info {
    my ($this) = @_;

    return if (defined $this->{USERS} and defined $this->{GROUPS} and defined $this->{USER_GROUPS});

    my $users=$this->get_table_data_hash('users', [qw(id login)]); # logins must not be digits only
    $this->{USERS}=$users;
    my $groups=$this->get_table_data_hash('groups', 'id');
    $this->{GROUPS}=$groups;
    my $user_groups=$this->get_table_data_hash_array('grp_user', 'user');
    $this->{USER_GROUPS}=$user_groups;
    my $group_users=$this->get_table_data_hash_array('grp_user', 'grp');
    $this->{GROUP_USERS}=$group_users;
}


########################################################################
#
#       Changing users and groups
#
########################################################################

# encrypt_password - Returns an encrypted version of the password.
#                    The password is encrypted using the traditional
#                    UNIX crypt() method with a random salt. All
#                    passwords are thefore one-way passwords.
sub encrypt_password {
    my ($this, $pw) = @_;

    my @chars = ('.', '/', 0..9, 'A'..'Z', 'a'..'z');
    my $salt;
    $salt .= $chars[rand 64] for (1..8);

    # Assume MD5 crypt
    my $crypted = crypt($pw, "\$1\$$salt\$");

    # If not, use other salt
    $crypted = crypt($pw, $salt) if (substr($crypted, 0, 3) ne "\$1\$");

    return($crypted);
}

sub delete_user {
    my ($this, $userid) = @_;

    return undef unless $this->can_create_new_user();

    return undef unless $this->get_user($userid);

    # we change owner to "nobody"
    my $nobody = $this-> get_userid('nobody');
    unless ( defined $nobody) {
        $this->{DB_Error} = "User 'nobody' is not found; cannot relocate documents";
        return undef;
    }

    $this->db_begin;
    eval {
        my $set = DBIx::Recordset->SetupObject ( {
            '!DataSource' => $this->{DB},
            '!Table'      => 'documents',
        });
        $set-> Update( { owner => $nobody }, { owner => $userid } );
        $set-> Disconnect;

        $this->db_delete_user($userid);
        $this->db_delete_user_grp($userid);

        $this->db_commit;
    };

    my $ev_error=$@;
    if ($ev_error) {                    # handle error
        $this->{DB_Error} = $ev_error;
        $this->db_rollback;
        $this->{LOG}->error("====> Delete user ... failed ($ev_error)");
        return undef;
    }

    undef $this->{DB_Error};
    $this->{LOG}->info("====> Delete user ... done");
    return $userid;
}

sub create_new_user {
    my ($this, $user) = @_;

    return undef unless $this->can_create_new_user();

    return undef if ($this->get_userid($user->{login}));

    $user->{passwd}=$this->encrypt_password($user->{password});

    $user->{grp}=[$user->{grp}] if (defined $user->{grp} and ref $user->{grp} ne 'ARRAY');

    my $userid;
    $this->db_begin;
    eval {
        $userid=$this->db_insert_user($user);
        die "No userid returned" unless $userid;
        $this->db_insert_user_grp($userid, $user->{grp});
        $this->db_commit;
    };

    my $ev_error=$@;
    if ($ev_error) {                    # handle error
        $this->{DB_Error} = $ev_error;
        $this->db_rollback;
        $this->{LOG}->error("====> Create new user ... failed ($ev_error)");
        return undef;
    }

    undef $this->{DB_Error};
    $this->{LOG}->info("====> Create new user ... done");
    return $userid;
}

# update_user - updates the information about a user in the
#               database. Input is a user hash-ref and a document
#               object. The update only takes place if the current
#               admin-user has the power to create a new user on the
#               document given. Returns undef on error and true on
#               success.

sub update_user_passwd {
    my ($this, $user);
    
    return undef unless ($this->can_create_new_user() || ($this->{USER} eq $user->{login}));

    $user->{passwd}=$this->encrypt_password($user->{password})
        if (defined $user->{password} and $user->{password});
    
    $this->db_begin;
    eval {
	$this->db_update_user($user);
	$this->db_commit;
    };

    my $ev_error=$@;
    if ($ev_error) {                    # handle error
        $this->{DB_Error} = $ev_error;
        $this->db_rollback;
        $this->{LOG}->error("====> Delete group ... failed ($ev_error)");
        return undef;
    }
    
    undef $this->{DB_Error};
    $this->{LOG}->info("====> Update user ... done");
    return 1;
}
    
sub update_user {
    my ($this, $user) = @_;

    return undef unless $this->can_create_new_user();

    $user->{passwd}=$this->encrypt_password($user->{password})
        if (defined $user->{password} and $user->{password});

    $user->{grp}=[$user->{grp}] if (defined $user->{grp} and ref $user->{grp} ne 'ARRAY');

    #print STDERR "update_user, user: " . Dumper($user);
    $this->db_begin;
    eval {
        die "No user id!" unless $user->{id};

        $this->db_update_user($user);
        $this->db_delete_user_grp($user->{id});
        $this->db_insert_user_grp($user->{id}, $user->{grp})
            if (defined $user->{grp});
        $this->db_commit;
    };

    my $ev_error=$@;
    if ($ev_error) {                    # handle error
        $this->{DB_Error} = $ev_error;
        $this->db_rollback;
        $this->{LOG}->error("====> Delete group ... failed ($ev_error)");
        return undef;
    }

    undef $this->{DB_Error};
    $this->{LOG}->info("====> Update user ... done");
    return 1;
}

sub delete_group {
    my ($this, $grpid, $doc) = @_;

    return undef unless $this->can_create_new_group($doc);

    return undef unless $this->get_group($grpid);

    $this->db_begin;
    eval {
        $this->db_delete_group($grpid);
        $this->db_delete_grp_user($grpid);
        # XXX If this groups contains documents, what to do? Change group to something else?
        #     Don't delete the group? What?
        $this->db_commit;
    };

    my $ev_error=$@;
    if ($ev_error) {                    # handle error
        $this->{DB_Error} = $ev_error;
        $this->db_rollback;
        $this->{LOG}->error("====> Delete group ... failed ($ev_error)");
        return undef;
    }

    undef $this->{DB_Error};
    $this->{LOG}->info("====> Delete group ... done");
    return $grpid;
}

# create_new_group - given a hash-ref with a name-entry string and a
#                    user-entry with a user id, creates a group with
#                    that name and puts the user in it.
#                    Returns the group id on success and undef on
#                    failure.
#                    (Why the user-thing?!)
sub create_new_group {
    my ($this, $group, $doc) = @_;

    return undef unless $this->can_create_new_group($doc);

    $group->{user}=[$group->{user}] if (defined $group->{user} and ref $group->{user} ne 'ARRAY');

    my $grpid;
    $this->db_begin;
    eval {
        $grpid=$this->db_insert_group($group);
        die "No grpid returned" unless $grpid;
        $this->db_insert_grp_user($grpid, $group->{user});
        $this->db_commit;
    };

    my $ev_error=$@;
    if ($ev_error) {                    # handle error
        $this->{DB_Error} = $ev_error;
        $this->db_rollback;
        $this->{LOG}->error("====> Create new group ... failed ($ev_error)");
        return undef;
    }

    undef $this->{DB_Error};
    $this->{LOG}->info("====> Create new group ... done");
    return $grpid;
}

sub update_group {
    my ($this, $group, $doc) = @_;

    return undef unless $this->can_create_new_group($doc); # Perhaps different?

    $group->{user}=[$group->{user}] if (defined $group->{user} and ref $group->{user} ne 'ARRAY');

    $this->db_begin;
    eval {
        die "No group id!" unless $group->{id};

        $this->db_update_group($group);
        $this->db_delete_grp_user($group->{id});
        $this->db_insert_grp_user($group->{id}, $group->{user})
            if (defined $group->{user});
        $this->db_commit;
    };

    my $ev_error=$@;
    if ($ev_error) {                    # handle error
        $this->{DB_Error} = $ev_error;
        $this->db_rollback;
        $this->{LOG}->error("====> Update group ... failed ($ev_error)");
        return undef;
    }

    undef $this->{DB_Error};
    $this->{LOG}->info("====> Update group ... done");
    return 1;
}

1;
__END__

=head1 NAME

Obvius::Users - User/Group handling methods for L<Obvius>.

=head1 SYNOPSIS

  use Obvius;
  use Obvius::Config;

  my $config = new Obvius::Config("configname");
  my $obvius = new Obvius($config);

  my $crypted=$obvius->encrypt_password($clear);

  my $userid=$obvius->get_userid($user);
  my $grpids=$obvius->get_user_groups($userid);

  my $userid=$obvius->get_userid('stein');

  my $grpid=$obvius->create_new_group({ name=>'Boxers', user=>$userid }, $doc);

  my $href=$obvius->get_user($userid);

  my $grpid=$obvius->get_grpid($group_name);

  my $ret=$obvius->update_user($user);

=head1 DESCRIPTION

This module contains methods for handling users and groups in
L<Obvius>.
It is not intended for use as a standalone module.

=head2 EXPORT

None.

=head1 AUTHOR

Jørgen Ulrik B. Krag, E<lt>jubk@magenta-aps.dkE<gt>
Adam Sjøgren, E<lt>asjo@magenta-aps.dk<gt>

=head1 SEE ALSO

L<Obvius>.

=cut
