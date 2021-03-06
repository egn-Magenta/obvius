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

use Cache::FileCache;
use JSON;

our $VERSION="1.0";

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

sub get_user_from_db {
    my ($this, $userid) = @_;
    return $this->get_table_record('users', {'id' => $userid});
}

# is_admin - depricated. Kept for backwards compatibility, but should use
#	     is_admin_user instead.
sub is_admin {
    return shift->is_admin_user;
}


# is_admin_user - determines whether the current user is a 'normal' admin user
#                 with privileges to manage users globally
sub is_admin_user {
    my ($this) = @_;

    return 0 if (!$this->{USER});
    my $user = $this->get_user($this->{USER});

    return 1 if($user->{is_admin});

    my $mode = $this->config->param('is_admin_user_mode') || 'member_of_admin_group';
    if($mode eq 'can_manage_users') {
	return $user->{can_manage_users} > 1;
    } else {
	return grep { $_ == 1 } @{$this->get_user_groups($user->{id})};
    }
}

# is_superadmin_user - determines whether a user (defaulting to the current) is
#                      a superadmin user which always have all privileges.
sub is_superadmin_user {
    my ($this, $mixed) = @_;

    $mixed ||= $this->{USER};

    my $user;
    if(ref($mixed)) {
	$user = $mixed;
    } else {
	$user = $this->get_user($mixed);
    }
    return 0 unless($user);

    return $user->{is_admin};
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

    my @ops = (
	  { name => 'USERS', 
	    fetch_data => sub {return $this->get_table_data_hash('users', [qw(id login)])}},
	  { name => 'GROUPS',
	    fetch_data => sub { return $this->get_table_data_hash('groups', [qw(id)])}},
	  { name => 'USER_GROUPS', 
	    fetch_data => sub { return $this->get_table_data_hash_array('grp_user', 'user') }},
	  { name => 'GROUP_USERS',
	    fetch_data => sub { return $this->get_table_data_hash_array('grp_user', 'grp') }});
    
    my $cache = new Cache::FileCache({cache_root => $this->{OBVIUS_CONFIG}{FILECACHE_DIRECTORY},
				      namespace => 'user_data'});
     
    for my $op (@ops) {
	 my $entity = $cache->get($op->{name});
	 if (!$entity) {
	      $entity = $op->{fetch_data}->();
	      $cache->set($op->{name}, $entity);
	 }
	 $this->{$op->{name}} = $entity;
    }
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
    my $user = $this->get_user($userid);
    return undef unless $user;

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

	$this->db_delete_user_sessions($userid);
        $this->update_user_history($user, 'delete');
        $this->db_delete_user_grp($userid);
        $this->db_delete_user($userid);

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
    $this->register_modified('users' => 1);
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
        $this->update_user_history($user, 'create');
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
    $this->register_modified('users' => 1);
    return $userid;
}

# update_user - updates the information about a user in the
#               database. Input is a user hash-ref and a document
#               object. The update only takes place if the current
#               admin-user has the power to create a new user on the
#               document given. Returns undef on error and true on
#               success.

sub update_user_passwd {
    my ($this, $user) = @_;
    
    return undef unless ($this->can_create_new_user() || ($this->{USER} eq $user->{login}));

    if (defined $user->{password} and $user->{password}) {
	$user->{passwd}=$this->encrypt_password($user->{password});
    } else {
	return;
    }

    
    $this->db_update_user($user);
    $this->register_modified('users' => 1);

    return 1;
}
    
sub update_user {
    my ($this, $user) = @_;
    
    return undef unless $this->can_create_new_user();

    $user->{passwd}=$this->encrypt_password($user->{password})
        if (defined $user->{password} and $user->{password});

    $user->{grp}=[$user->{grp}] if (defined $user->{grp} and ref $user->{grp} ne 'ARRAY');

    $this->update_user_history($user, 'update');
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
        $this->{LOG}->error("====> Update user ... failed ($ev_error)");
        return undef;
    }

    undef $this->{DB_Error};
    $this->{LOG}->info("====> Update user ... done");
    $this->register_modified('users' => 1);
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
    $this->register_modified('users' => 1);
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
    $this->register_modified('users' => 1);
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
    $this->register_modified('users' => 1);
    return 1;
}

sub update_user_history {
    my ($this, $user, $operation) = @_;
    if ($operation ne 'create' && $operation ne 'update' && $operation ne 'delete') {
        die "Invalid user history operation $operation\n";
    }
    my $old = $this->get_user_from_db($user->{id});
    my $editor = $this->get_user($this->{USER});

    my $changes = undef;

    if ($operation eq 'create' || $operation eq 'update') {
        sub compare {
            my ($a, $b) = @_;
            if (defined($a) && defined($b)) {
                return "$a" eq "$b";
            } else {
                return (!defined($a) && !defined($b));
            }
        }
        my $changes_object = { 'before' => {}, 'after' => {} };
        for my $field (keys(%$old)) {
            if (exists($user->{$field})) {
                my $old_value = $old->{$field};
                my $new_value = $user->{$field};
                if (!compare($old_value, $new_value)) {
                    $changes_object->{'before'}->{$field} = $old_value;
                    $changes_object->{'after'}->{$field} = $new_value;
                }
            }
        }
        $changes = to_json($changes_object, {'canonical' => 1});
    }

    $this->insert_table_record('user_history', {
        'user_id'      => $user->{id},
        'user_login'   => $user->{login},
        'editor_id'    => $editor->{id},
        'editor_login' => $editor->{login},
        'operation'    => $operation,
        'changes'      => $changes
    });
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
