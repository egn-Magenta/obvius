package Obvius::Utils;

########################################################################
#
# Utils.pm - Obvius utilities
#
# Copyright (C) 2001-2004
#                    Magenta Aps, Denmark (http://www.magenta-aps.dk/)
#                    aparte A/S, Denmark (http://www.aparte.dk/),
#
# Authors: Adam Sjgren (asjo@magenta-aps.dk),
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

# $Id$


use strict;
use warnings;

use base qw(Exporter);
our $VERSION="1.0";

our @EXPORT_OK = qw(
    monthname
);

########################################################################
#
#	Handling passwordprotectedurls:
#
########################################################################

sub get_passwordprotectedurl {
    my ($this, $url) = @_;

    return $this->get_table_record('passwordprotectedurls', {url=>$url});
}

# can_create_new_passwordprotedtedurl()
#    - checks whether the user has admin cababilities on the frontpage or not
#
sub can_create_new_passwordprotectedurl {
    my ($this) = @_;

    # XXX this is obsolete, role 'admin' doesn't exist anymore 
    my $doc=$this->get_doc_by_id(1); # XXX Root
    return $this->user_has_capabilities($doc, qw(admin)); # Changed from 'modes' to 'admin'
}

sub delete_passwordprotectedurl {
    my ($this, $url) = @_;

    return undef unless $this->can_create_new_passwordprotectedurl();

    return undef unless $this->get_passwordprotectedurl($url);

    $this->db_begin;
    eval {
	$this->db_delete_table(table=>'passwordprotectedurls', key=>'url', id=>$url);
	$this->db_commit;
    };

    my $ev_error=$@;
    if ($ev_error) {			# handle error
	$this->{DB_Error} = $ev_error;
 	$this->db_rollback;
	$this->{LOG}->error("====> Delete passwordprotectedurl ... failed ($ev_error)");
	return undef;
    }

    undef $this->{DB_Error};
    $this->{LOG}->info("====> Delete passwordprotectedurl ... done");
    return 1;
}

sub create_new_passwordprotectedurl {
    my ($this, $passwordprotectedurl) = @_;

    return undef unless $this->can_create_new_passwordprotectedurl();

    return undef if ($this->get_passwordprotectedurl($passwordprotectedurl->{url}));

    $this->db_begin;
    eval {
	$this->db_insert_table(table=>'passwordprotectedurls', key=>'url', value=>$passwordprotectedurl);
	$this->db_commit;
    };

    my $ev_error=$@;
    if ($ev_error) {			# handle error
	$this->{DB_Error} = $ev_error;
 	$this->db_rollback;
	$this->{LOG}->error("====> Create new passwordprotectedurl ... failed ($ev_error)");
	return undef;
    }

    undef $this->{DB_Error};
    $this->{LOG}->info("====> Create new passwordprotectedurl ... done");
    return 1;
}

sub update_passwordprotectedurl {
    my ($this, $passwordprotectedurl) = @_;

    return undef unless $this->can_create_new_passwordprotectedurl(); # Perhaps different?

    $this->db_begin;
    eval {
	die "No url!" unless $passwordprotectedurl->{url};

	$this->db_update_table(table=>'passwordprotectedurls', key=>'url', value=>$passwordprotectedurl);
	$this->db_commit;
    };

    my $ev_error=$@;
    if ($ev_error) {			# handle error
	$this->{DB_Error} = $ev_error;
 	$this->db_rollback;
	$this->{LOG}->error("====> Update passwordprotectedurl ... failed ($ev_error)");
	return undef;
    }

    undef $this->{DB_Error};
    $this->{LOG}->info("====> Update passwordprotectedurl ... done");
    return 1;
}


########################################################################
#
#	Handling synonyms:
#
########################################################################

# get_synonyms - Returns all synonyms with $id
sub get_synonyms {
    my ($this, $id) = @_;

    return $this->get_table_record('synonyms', {id=>$id});
}

# can_create_new_synonyms - Check if the current user is allowed to create new synonyms
sub can_create_new_synonyms {
    my ($this) = @_;

    # XXX this is obsolete, role 'admin' doesn't exist anymore 
    my $doc=$this->get_doc_by_id(1); # XXX Root
    return $this->user_has_capabilities($doc, qw(admin)); # Changed from 'modes' to 'admin'
}

# delete_synonyms - Removes synonyms with $id from the database if they exist
#                   and the user has the necessary rights. Returns undef on failure.
sub delete_synonyms {
    my ($this, $id) = @_;

    return undef unless $this->can_create_new_synonyms();
    return undef unless $this->get_synonyms($id);

    $this->db_begin;
    eval {
	$this->db_delete_table(table=>'synonyms', id=>$id);
	$this->db_commit;
    };

    my $ev_error=$@;
    if ($ev_error) {			# handle error
	$this->{DB_Error} = $ev_error;
 	$this->db_rollback;
	$this->{LOG}->error("====> Delete synonyms ... failed ($ev_error)");
	return undef;
    }

    undef $this->{DB_Error};
    $this->{LOG}->info("====> Delete synonyms ... done");
    return 1;
}

# create_new_synonyms - given a hashref with a space-separated list of
#                       synonyms as the value of the key 'synonyms'
#                       creates them in the database. Returns false if
#                       the user doesn't have access to create
#                       synonyms and if creation fails. Returns true
#                       upon success.
sub create_new_synonyms {
    my ($this, $synonyms) = @_;

    return undef unless $this->can_create_new_synonyms();

    return undef if ($this->get_synonyms($synonyms->{id}));

    $this->db_begin;
    eval {
	$this->db_insert_table(table=>'synonyms', value=>$synonyms);
	$this->db_commit;
    };

    my $ev_error=$@;
    if ($ev_error) {			# handle error
	$this->{DB_Error} = $ev_error;
 	$this->db_rollback;
	$this->{LOG}->error("====> Create new synonyms ... failed ($ev_error)");
	return undef;
    }

    undef $this->{DB_Error};
    $this->{LOG}->info("====> Create new synonyms ... done");
    return 1;
}

sub update_synonyms {
    my ($this, $synonyms) = @_;

    return undef unless $this->can_create_new_synonyms(); # Perhaps different?

    $this->db_begin;
    eval {
	die "No id!" unless $synonyms->{id};

	$this->db_update_table(table=>'synonyms', value=>$synonyms);
	$this->db_commit;
    };

    my $ev_error=$@;
    if ($ev_error) {			# handle error
	$this->{DB_Error} = $ev_error;
 	$this->db_rollback;
	$this->{LOG}->error("====> Update synonyms ... failed ($ev_error)");
	return undef;
    }

    undef $this->{DB_Error};
    $this->{LOG}->info("====> Update synonyms ... done");
    return 1;
}


########################################################################
#
#	Methods for ExpertGroups system
#
########################################################################

sub get_expertgroup {
    my ($this, $name) = @_;

    my $set=DBIx::Recordset->SetupObject( {'!DataSource'=>$this->{DB},
                                            '!Table'     =>'expertgroups',
                                        } );
    $set->Search({'name' => $name});

    my @docids;
    while (my $rec=$set->Next) {
        push(@docids, $rec->{docid});
    }

    $set->Disconnect;

    return \@docids;
}

sub get_expertgroup_names {
    my ($this) = @_;
    my $set=DBIx::Recordset->SetupObject( {'!DataSource'=>$this->{DB},
                                            '!Table'     =>'expertgroups',
                                            '!Fields'    =>'DISTINCT name'
                                        } );
    $set->Search();

    my @result;
    while (my $rec=$set->Next) {
        push(@result, $rec->{name});
    }
    return \@result;

    $set->Disconnect;
}

sub create_expertgroup {
    my ($this, $name, $docids) = @_;
    die '$docids must be an array ref' . "\n" unless(ref($docids) eq 'ARRAY');

    my $set=DBIx::Recordset->SetupObject( {'!DataSource'=>$this->{DB},
                                            '!Table'     =>'expertgroups',
                                        } );
    for(@$docids) {
        $set->Insert({'name' => $name, 'docid' => $_});
    }
    $set->Disconnect;
}

sub modify_expertgroup {
    my ($this, $name, $docids) = @_;
    die '$docids must be an array ref' . "\n" unless(ref($docids) eq 'ARRAY');

    #Simply delete the group and create it again with the new ids.
    $this->delete_expertgroup($name);
    $this->create_expertgroup($name, $docids);
}

sub delete_expertgroup {
    my ($this, $name) = @_;

    my $set=DBIx::Recordset->SetupObject( {'!DataSource'=>$this->{DB},
                                            '!Table'     =>'expertgroups',
                                        } );
    $set->Delete({'name' => $name });

    $set->Disconnect;
}


########################################################################
#
#	Methods for phorum integration
#
########################################################################

# XXX These methods should be called as little as possible as they
# make a new database connection each time they are called, which
# is quite expensive. They don't really belong here, but until now
# it's the best place to put 'em.

# get_phorum_names($config_suffix) - Returns the names of forums created under the chosen
#                    config_suffix. Returns an array-ref.
sub get_phorum_names {
    my ($this, $suffix_limit) = @_;

    my $config = $this->{OBVIUS_CONFIG};

    my $set=DBIx::Recordset->SetupObject(
                                            {
                                                '!DataSource' => $config->param('PHORUMDSN'),
                                                '!Username'   => $config->param('normal_db_login'),
                                                '!Password'   => $config->param('normal_db_passwd'),
                                                '!Table'     => 'forums',
                                                '!Fields'   =>  'name',
                                            }
                                        );

    my $where = "folder != 1";
    $where .= " AND config_suffix LIKE '%$suffix_limit%'" if($suffix_limit);

    $set->Search($where);

    my @data;
    while(my $rec = $set->Next) {
        push(@data, $rec->{name});
    }

    return \@data;
}

# get_phorum_id_by_name($name) - Returns the Phorum ID of the forum called
#                                $name. Returns undef if no forum was found.
sub get_phorum_id_by_name {
    my ($this, $name) = @_;

    return undef unless($name);

    my $config = $this->{OBVIUS_CONFIG};

    my $set=DBIx::Recordset->SetupObject(
                                            {
                                                '!DataSource' => $config->param('PHORUMDSN'),
                                                '!Username'   => $config->param('normal_db_login'),
                                                '!Password'   => $config->param('normal_db_passwd'),
                                                '!Table'     => 'forums',
                                                '!Fields'   =>  'id',
                                            }
                                        );

    $set->Search("folder != 1 AND name = '$name'");

    if(my $rec = $set->Next) {
        return $rec->{id};
    } else {
        return undef;
    }
}
# get_phorum_by_id ($id) - Returns the name of the forum with $id. Returns undef
#                        - if no forum was found.
sub get_phorum_by_id {
    my ($this, $id) = @_;

    return undef unless($id);

    my $config = $this->{OBVIUS_CONFIG};

    my $set=DBIx::Recordset->SetupObject(
                                            {
                                                '!DataSource' => $config->param('PHORUMDSN'),
                                                '!Username'   => $config->param('normal_db_login'),
                                                '!Password'   => $config->param('normal_db_passwd'),
                                                '!Table'     => 'forums',
                                                '!Fields'   =>  'name',
                                            }
                                        );

    my $where = "folder != 1 AND id = $id";

    $set->Search($where);

    if(my $rec = $set->Next) {
        return $rec->{name};
    }

    return undef;
}


###################################
###
###   Message Digest Calculation
###
###################################

# Jason: expects a hash
sub create_msg_digest {
  my ($this, $data, %exclude) = @_;

  if (ref($data) ne 'HASH') {
    $this->{LOG}->debug("MessageDigest> Data Ref: " . ref($data));
  }

  use Digest::SHA1;
  my $ctx = new Digest::SHA1;


  # The keys are the field names, and they need to be sorted, as they are calculated
  # in the same way when the document is created as when it is published.

  foreach my $k (sort keys %$data) {
    next if ($exclude{$k});

    if (ref($data->{$k}) eq 'ARRAY') {

      # We need to find a better way of sorting the data .. this one assumes that all
      # Xrefs should be sorted by the id field, but it may not exist. Should be able
      # to get the fieldspec for this record, and check from that ...
      # XXX : convention: Xref fields have ID as the 'key'

      foreach my $e (sort { (ref($a) eq 'Obvius::Data::Xref' and defined($a->Id) )
                                      ? $a->Id cmp $b->Id
                                      : $a cmp $b
                          } @{$data->{$k}} ) {

        if (ref($e) eq 'Obvius::Data::Xref' and defined($e->Id)) {
          $ctx->add($e->Id);
          $this->{LOG}->debug("CTX_xref ($k): [" . $e->Id . "]");
        } elsif (defined($e)) {
          $ctx->add($e);
          $this->{LOG}->debug("CTX_ar ($k): [$e]");
        }

      }
    } elsif (defined($data->{$k})) {
      $ctx->add($data->{$k});
      $this->{LOG}->debug("CTX_ ($k) : [" . $data->{$k} . "]");
    }
  }

    my $md = $ctx->hexdigest;
    $this->{LOG}->debug(" *> MSGDIGEST: $md");

    return $md;
}

########################################################################
#
#	Handling loginusers:
#
########################################################################

# get_loginuser - given a string with a login and an optional prefix,
#                 returns a hash-ref with the matching row in the
#                 table prefixloginusers. Returns undef if nothing is
#                 found (in scalar context, in array context an empty
#                 list is returned).
sub get_loginuser {
    my ($this, $login, $prefix) = @_;
    $prefix='' unless (defined $prefix);

    return $this->get_table_record($prefix . 'loginusers', {login=>$login});
}

sub delete_loginuser {
    my ($this, $login, $prefix) = @_;
    $prefix='' unless (defined $prefix);

    return undef unless $this->can_create_new_loginuser();

    return undef unless $this->get_loginuser($login, $prefix);

    $this->db_begin;
    eval {
	$this->db_delete_loginuser($login, $prefix);
	# XXX If this login is used on documents, it should probably be removed from there.
	$this->db_commit;
    };

    my $ev_error=$@;
    if ($ev_error) {			# handle error
	$this->{DB_Error} = $ev_error;
 	$this->db_rollback;
	$this->{LOG}->error("====> Delete " . $prefix . "loginuser ... failed ($ev_error)");
	return undef;
    }

    undef $this->{DB_Error};
    $this->{LOG}->info("====> Delete " . $prefix . "loginuser ... done");
    return 1;
}

sub can_create_new_loginuser {
    my ($this, $prefix) = @_;
    $prefix='' unless (defined $prefix);

    # XXX this is obsolete, role 'admin' doesn't exist anymore 
    my $doc=$this->get_doc_by_id(1); # XXX Root
    return $this->user_has_capabilities($doc, qw(admin)); # Changed from 'modes' to 'admin'
}

sub create_new_loginuser {
    my ($this, $loginuser, $prefix) = @_;
    $prefix='' unless (defined $prefix);

    return undef unless $this->can_create_new_loginuser();

    return undef if ($this->get_loginuser($loginuser->{login}, $prefix));

    $this->db_begin;
    eval {
	$this->db_insert_loginuser($loginuser, $prefix);
	$this->db_commit;
    };

    my $ev_error=$@;
    if ($ev_error) {			# handle error
	$this->{DB_Error} = $ev_error;
 	$this->db_rollback;
	$this->{LOG}->error("====> Create new " . $prefix . "loginuser ... failed ($ev_error)");
	return undef;
    }

    undef $this->{DB_Error};
    $this->{LOG}->info("====> Create new " . $prefix . "loginuser ... done");
    return 1;
}

sub update_loginuser {
    my ($this, $loginuser, $prefix) = @_;
    $prefix='' unless (defined $prefix);

    return undef unless $this->can_create_new_loginuser(); # Perhaps different?

    $this->db_begin;
    eval {
	die "No login!" unless $loginuser->{login};

	$this->db_update_loginuser($loginuser, $prefix);
	$this->db_commit;
    };

    my $ev_error=$@;
    if ($ev_error) {			# handle error
	$this->{DB_Error} = $ev_error;
 	$this->db_rollback;
	$this->{LOG}->error("====> Update " . $prefix . "loginuser ... failed ($ev_error)");
	return undef;
    }

    undef $this->{DB_Error};
    $this->{LOG}->info("====> Update " . $prefix . "loginuser ... done");
    return 1;
}

########################################################################
#
#	General utility methods
#
########################################################################

# Returns lowercase month name from a number (1-12)
# The result may be inserted in a translation, e.g. __(Obvius::Utils::monthname($month))
sub monthname_from_number {
    my ($monthnumber) = @_;
    if (!$monthnumber || $monthnumber < 1 || $monthnumber > 12) {
        return undef;
    }
    my @months = qw(none january february march april may june july august september october november december);
    return $months[$monthnumber];
}

1;
__END__
#

=head1 NAME

Obvius::Utils - Utility functions for Obvius.pm

=head1 SYNOPSIS

  use Obvius;
  use Obvius::Config;

  my $config = new Obvius::Config("configname");
  my $obvius = new Obvius($config);

  $obvius->create_msg_digest();

  can_create_new_passwordprotectedurl();

  my $ret=$obvius->create_new_synonyms( { synonyms=>'hest pony hingst hoppe' } );

  my $phorums=$obvius->get_phorum_names('hope');
  my $phorum_id=$obvius->get_phorum_id_by_name('Almen debat');
  my $phorum_name=$obvius->get_phorum_by_id('12');

  my $loginuser=$obvius->get_loginuser(login=>'asjo');
  my $fun_loginuser=$obvius->get_loginuser(login=>'asjo', prefix=>'fun_');

=head1 DESCRIPTION

This module adds extra functions to the L<Obvius> module. It should not be
used as a stand alone module.

All functions related to phorum usage should be used with caution since a new
database connection is made on each invocation.

=head2 EXPORT

None.

=head1 AUTHORS

Adam Sjøgren, E<lt>adam@aparte.dkE<gt>

Jørgen Ulrik B. Krag, E<lt>jubk@magenta-aps.dkE<gt>

Martin Skøtt E<lt>martin@magenta-aps.dk<gt>

=head1 SEE ALSO

L<Obvius>.

=cut
