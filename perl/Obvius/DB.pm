package Obvius::DB;

########################################################################
#
# Obvius.pm - Content Manager, database handling
#
# Copyright (C) 2001-2004 Magenta Aps, Denmark (http://www.magenta-aps.dk/),
#                         aparte A/S, Denmark (http://www.aparte.dk/),
#                         FI, Denmark (http://www.fi.dk/)
#
# Authors: Jørgen Ulrik B. Krag (jubk@magenta-aps.dk),
#          Peter Makholm (pma@fi.dk),
#          René Seindal,
#          Adam Sjøgren (asjo@magenta-aps.dk),
#          Martin Skøtt (martin@magenta-aps.dk)
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

our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

########################################################################
#
#	Database update helpers.
#	In general they assume valid data
#
########################################################################


sub db_error { return shift->{DB_Error}; };

sub db_begin {
    my $this = shift;
    $this->{LOG}->info("**** DB TRANSACTION BEGIN");
    return 1;
}

sub db_commit {
    my $this = shift;
    $this->{LOG}->info("**** DB TRANSACTION COMMIT");
    $this->{DB}->DBHdl->commit;
 }

sub db_rollback	{
     my $this = shift;
     $this->{LOG}->info("**** DB TRANSACTION ROLLBACK");
     $this->{DB}->DBHdl->rollback;
}

# db_number_of_rows_in_table - returns the number of rows in the table
#                              given.
#
sub db_number_of_rows_in_table {
    my ($this, $table)=@_;

    my $sth=$this->{DB}->DBHdl->prepare('SELECT COUNT(*) FROM ' . $table);
    $sth->execute;
    my $count=$sth->fetchrow;

    return $count;
}

sub db_insert_document {
    my ($this, $name, $parent, $type, $owner, $grp) = @_;

    $this->tracer($name, $parent, $type, $owner, $grp) if ($this->{DEBUG});

    $this->{LOG}->info("====> Inserting document ($name, $parent) ...");

    my $doc = {
	       id      => 0,
	       parent  => $parent,
	       name    => $name,
	       type    => $type,
	       owner   => $owner,
	       grp     => $grp,
	      };

    my $set = DBIx::Recordset->SetupObject ({'!DataSource' => $this->{DB},
					     '!Table'      => 'documents',
					     '!Serial'     => 'id',
					    });
    $set->Insert($doc);
    $set->Disconnect;

    return $set->LastSerial;
}

sub db_update_document {
    my ($this, $doc, $fields) = @_;

    $this->tracer($doc, $fields||'NULL') if ($this->{DEBUG});

    $this->{LOG}->info("====> Update document (id $doc->{ID} - parent $doc->{PARENT} - name $doc->{NAME}) ...");

    $fields ||= [ qw(name parent type owner grp accessrules) ];

    my %data;
    $data{$_} = $doc->param($_) for (@$fields);
    $data{id} = $doc->param('id') unless defined $data{id}; # Must have id (key)

    my $set = DBIx::Recordset->SetupObject ({'!DataSource' => $this->{DB},
					     '!Table'      => 'documents',
					     '!PrimKey'    => 'id',
					    });
    $set->Update(\%data);
    $set->Disconnect;

    return;
}

sub db_delete_document {
    my ($this, $id) = @_;

    $this->tracer($id||'NULL') if ($this->{DEBUG});

    $this->{LOG}->info("====> Delete document (id $id) ...");

    my $set = DBIx::Recordset->SetupObject ({'!DataSource' => $this->{DB},
					     '!Table'      => 'documents',
					    });
    $set->Delete({id=>$id});
    $set->Disconnect;

    return;
}

sub db_delete_versions {
    my ($this, $docid) = @_;

    $this->tracer($docid||'NULL') if ($this->{DEBUG});

    $this->{LOG}->info("====> Delete versions (docid $docid) ...");

    my $set = DBIx::Recordset->SetupObject ({'!DataSource' => $this->{DB},
					     '!Table'      => 'versions',
					    });
    $set->Delete({docid=>$docid});
    $set->Disconnect;

    return;
}

# sub db_delete_single_version - Deletes a single version of a document from the database.
#                                XXX: No check is done on input values before the command is run. 
#                                     What would happen if this method is called only with $lanf defined?
sub db_delete_single_version {
    my ($this, $docid, $version, $lang) = @_;

    $this->tracer($docid||'NULL', $version||'NULL', $lang||'NULL') if ($this->{DEBUG});

    $this->{LOG}->info("====> Delete single version (docid $docid, version $version, lang $lang) ...");

    my $set = DBIx::Recordset->SetupObject ({'!DataSource' => $this->{DB},
                                            '!Table'      => 'versions',
                                            });
    $set->Delete({docid=>$docid, version=>$version, lang=>$lang});
    $set->Disconnect;

    return;
}

sub db_delete_single_version_vfields {
    my ($this, $docid, $version) = @_;

    $this->tracer($docid||'NULL', $version||'NULL') if ($this->{DEBUG});

    $this->{LOG}->info("====> Delete single version vfields (docid $docid, version $version) ...");

    my $set = DBIx::Recordset->SetupObject ({'!DataSource' => $this->{DB},
                                            '!Table'      => 'vfields',
                                            });
    $set->Delete({docid=>$docid, version=>$version});
    $set->Disconnect;

    return;
}

sub db_delete_vfields {
    my ($this, $docid) = @_;

    $this->tracer($docid||'NULL') if ($this->{DEBUG});

    $this->{LOG}->info("====> Delete vfields (docid $docid) ...");

    my $set = DBIx::Recordset->SetupObject ({'!DataSource' => $this->{DB},
					     '!Table'      => 'vfields',
					    });
    $set->Delete({docid=>$docid});
    $set->Disconnect;

    return;
}

sub db_delete_vfield {
    my ($this, $docid, $version, $name) = @_;

    $this->tracer($docid||'NULL') if ($this->{DEBUG});

    $this->{LOG}->info("====> Delete vfield (docid $docid version $version name $name) ...");

    my $set = DBIx::Recordset->SetupObject ({'!DataSource' => $this->{DB},
					     '!Table'      => 'vfields',
					    });
    $set->Delete({docid=>$docid, version=>$version, name=>$name});
    $set->Disconnect;

    return;
}

sub db_delete_subscriptions {
    my ($this, $docid) = @_;

    $this->tracer($docid||'NULL') if ($this->{DEBUG});

    $this->{LOG}->info("====> Delete subscriptions (docid $docid) ...");

    my $set = DBIx::Recordset->SetupObject ({'!DataSource' => $this->{DB},
					     '!Table'      => 'subscriptions',
					    });
    $set->Delete({docid=>$docid});
    $set->Disconnect;

    return;
}

# db_insert_version - Creates a new entry in the versions table based on the supplied docid.
#                     Returns version which is a string of the format "%Y-%m-%d %H:%M:%S".
#                     TODO:
#                     Check that the supplied arguments are correct (eg. does docid and type make sense).
#                     Handle when the insert goes wrong.
sub db_insert_version {
    my ($this, $docid, $type, $lang) = @_;

    $this->tracer($docid, $type, $lang) if ($this->{DEBUG});

    my $version = strftime('%Y-%m-%d %H:%M:%S', localtime);

    $this->{LOG}->info("====> Inserting version $version ...");

    my $vdoc = {
		public	 => 0,
		docid	 => $docid,
		version	 => $version,
		type	 => $type,
		lang	 => $lang,
	       };

    my $set = DBIx::Recordset->SetupObject ({'!DataSource' => $this->{DB},
					     '!Table'      => 'versions',
					    });
    $set->Insert($vdoc);
    $set->Disconnect;

    return $version;
}

sub db_insert_vfields {
    my ($this, $docid, $version, $fields, $flist) = @_;

    $this->tracer($docid, $version, $fields, $flist||'NULL') if ($this->{DEBUG});

    my $set = DBIx::Recordset->SetupObject ({'!DataSource' => $this->{DB},
					     '!Table'      => 'vfields',
					    });

    for my $k ($flist ? @$flist : $fields->param) {
	$this->{LOG}->info("====> Inserting field $k ...");

	# XXX Should use doctype
	my $fspec = $this->get_fieldspec($k);
	die "Abort - fieldspec for $k  not found" unless ($fspec);
	my $ftype = $fspec->param('fieldtype');
	die "Abort - fieldtype for $k not found" unless ($ftype);

	my $value_field = $ftype->param('value_field');
	die "Abort - value_field for $k not found" unless ($value_field);
	$value_field .= '_value';

	my $v = $fields->param($k);
	my $field = {
		     docid	  => $docid,
		     version	  => $version,
		     name	  => $k,
		    };

	if ($fspec->Repeatable and (ref $v || '') eq 'ARRAY') {
	    for (@$v) {
		$field->{$value_field} = $ftype->copy_out($this, $fspec, $_);
		$set->Insert($field);
	    }
	} else {
	    $field->{$value_field} = $ftype->copy_out($this, $fspec, $v);
	    #print STDERR ">>>> inserting field: " . Dumper($field);
	    $set->Insert($field);
	}
    }
    $set->Disconnect;
}

sub db_update_versions_hide_all {
    my ($this, $docid) = @_;

    $this->tracer($docid) if ($this->{DEBUG});

    $this->{LOG}->info("====> Update versions mark all not public ($docid) ...");

    my $set = DBIx::Recordset->SetupObject ({'!DataSource' => $this->{DB},
					     '!Table'      => 'versions',
					    });
    # Clear all other public versions for document
    $set->Update({ public => 0}, { docid => $docid });
    $set->Disconnect;

    return;
}

sub db_update_version_mark_public {
    my ($this, $vdoc, $public) = @_;

    $public = 1 unless (defined $public);
    $this->tracer($vdoc, $public) if ($this->{DEBUG});

    $this->{LOG}->info("====> Update version mark public $public ($vdoc->{DOCID}, $vdoc->{VERSION}, $vdoc->{LANG}) ...");

    my $set = DBIx::Recordset->SetupObject ({'!DataSource' => $this->{DB},
					     '!Table'      => 'versions',
					    });
    # Clear other public version for same language
    $set->Update({ public => 0}, { $vdoc->params('docid', 'lang') });
    # Set this version public
    $set->Update({ public => 1}, { $vdoc->params('docid', 'version') }) if ($public);
    $set->Disconnect;

    return;
}

sub db_insert_user {
    my ($this, $user) = @_;

    $this->tracer($user) if ($this->{DEBUG});

    $this->{LOG}->info("====> Inserting user ($user->{login}, $user->{name}) ...");

    my $set = DBIx::Recordset->SetupObject ({'!DataSource' => $this->{DB},
					     '!Table'      => 'users',
					     '!Serial'     => 'id',
					    });
    $user->{id}=0;
    $set->Insert($user);
    $set->Disconnect;

    return $set->LastSerial;
}

sub db_update_user {
    my ($this, $user) = @_;

    $this->tracer($user) if ($this->{DEBUG});

    $this->{LOG}->info("====> Updating user ($user->{id}, $user->{login}, $user->{name}) ...");

    my $set = DBIx::Recordset->SetupObject ({'!DataSource' => $this->{DB},
					     '!Table'      => 'users',
					    });
    $set->Update($user, { id=>$user->{id} });
    $set->Disconnect;

    return;
}
# db_delete_user ($userid) - Removes a user from the system.
#
sub db_delete_user {
    my ($this, $userid) = @_;

    $this->tracer($userid||'NULL') if ($this->{DEBUG});

    $this->{LOG}->info("====> Delete user (userid $userid) ...");

    my $set = DBIx::Recordset->SetupObject ({'!DataSource' => $this->{DB},
					     '!Table'      => 'users',
					    });
    $set->Delete({id=>$userid});
    $set->Disconnect;

    return;
}

# db_delete_user_grp ($userid) - Removes a users membership of all groups.
#                                $userid must be a numeric user id.
sub db_delete_user_grp {
    my ($this, $userid) = @_;

    $this->tracer($userid||'NULL') if ($this->{DEBUG});

    $this->{LOG}->info("====> Delete user_grp (userid $userid) ...");

    my $set = DBIx::Recordset->SetupObject ({'!DataSource' => $this->{DB},
					     '!Table'      => 'grp_user',
					    });
    $set->Delete({user=>$userid});
    $set->Disconnect;

    return;
}

sub db_insert_user_grp {
    my ($this, $userid, $grp) = @_;

    $this->tracer($userid||'NULL') if ($this->{DEBUG});

    $this->{LOG}->info("====> Insert user_grp (userid $userid) ...");

    my $set = DBIx::Recordset->SetupObject ({'!DataSource' => $this->{DB},
					     '!Table'      => 'grp_user',
					    });
    foreach (@$grp) {
	$set->Insert({grp=>$_, user=>$userid});
    }
    $set->Disconnect;

    return;
}

sub db_insert_group {
    my ($this, $group) = @_;

    $this->tracer($group) if ($this->{DEBUG});

    $this->{LOG}->info("====> Inserting group ($group->{name}) ...");

    my $set = DBIx::Recordset->SetupObject ({'!DataSource' => $this->{DB},
					     '!Table'      => 'groups',
					     '!Serial'     => 'id',
					    });
    $group->{id}=0;
    $set->Insert($group);
    $set->Disconnect;

    return $set->LastSerial;
}

sub db_update_group {
    my ($this, $group) = @_;

    $this->tracer($group) if ($this->{DEBUG});

    $this->{LOG}->info("====> Updating group ($group->{id} $group->{name}) ...");

    my $set = DBIx::Recordset->SetupObject ({'!DataSource' => $this->{DB},
					     '!Table'      => 'groups',
					    });
    $set->Update($group, { id=>$group->{id} });
    $set->Disconnect;

    return;
}

sub db_delete_group {
    my ($this, $grpid) = @_;

    $this->tracer($grpid||'NULL') if ($this->{DEBUG});

    $this->{LOG}->info("====> Delete group (grpid $grpid) ...");

    my $set = DBIx::Recordset->SetupObject ({'!DataSource' => $this->{DB},
					     '!Table'      => 'groups',
					    });
    $set->Delete({id=>$grpid});
    $set->Disconnect;

    return;
}
sub db_delete_grp_user {
    my ($this, $grpid) = @_;

    $this->tracer($grpid||'NULL') if ($this->{DEBUG});

    $this->{LOG}->info("====> Delete grp_user (grpid $grpid) ...");

    my $set = DBIx::Recordset->SetupObject ({'!DataSource' => $this->{DB},
					     '!Table'      => 'grp_user',
					    });
    $set->Delete({grp=>$grpid});
    $set->Disconnect;

    return;
}

sub db_insert_grp_user {
    my ($this, $grpid, $user) = @_;

    $this->tracer($grpid||'NULL') if ($this->{DEBUG});

    $this->{LOG}->info("====> Insert grp_user (grpid $grpid) ...");

    my $set = DBIx::Recordset->SetupObject ({'!DataSource' => $this->{DB},
					     '!Table'      => 'grp_user',
					    });
    foreach (@$user) {
	$set->Insert({user=>$_, grp=>$grpid});
    }
    $set->Disconnect;

    return;
}

# db_insert_comment - given a hash-ref containing key-value pairs for
#                     a comment (docid, name, email and text - date is
#                     set to now automatically), inserts the comment
#                     in the database.
sub db_insert_comment {
    my ($this, $data) = @_;

    $this->tracer($data) if ($this->{DEBUG});

    $this->{LOG}->info("====> Inserting comment ($data->{docid}, $data->{name}) ...");

    my $set = DBIx::Recordset->SetupObject ({'!DataSource' => $this->{DB},
					     '!Table'      => 'comments',
					    });

    $data->{'\date'}='NOW()';
    $set->Insert($data);
    $set->Disconnect;

    return $set->LastSerial;
}

sub db_update_comment {
    my ($this, $data) = @_;

    $this->tracer($data) if ($this->{DEBUG});

    $this->{LOG}->info("====> Updating comment ($data->{docid}, $data->{date} ...");

    my $set = DBIx::Recordset->SetupObject ({'!DataSource' => $this->{DB},
					     '!Table'      => 'comments',
					    });
    $set->Update($data, {docid=>$data->{docid}, date=>$data->{date}});
    $set->Disconnect;

    return;
}

sub db_delete_comment {
    my ($this, $docid, $date) = @_;

    $this->tracer($docid||'NULL', $date||'NULL') if ($this->{DEBUG});

    $this->{LOG}->info("====> Delete comment (docid $docid, date $date) ...");

    my $set = DBIx::Recordset->SetupObject ({'!DataSource' => $this->{DB},
					     '!Table'      => 'comments',
					    });
    my %options=(docid=>$docid);
    $options{date}=$date if ($date);
    $set->Delete(\%options);
    $set->Disconnect;

    return;
}

sub db_delete_comments {
    my ($this, $docid) = @_;

    return $this->db_delete_comment($docid, '');
}

sub db_insert_loginuser {
    my ($this, $loginuser, $prefix) = @_;

    $this->tracer($loginuser) if ($this->{DEBUG});

    $prefix='' unless (defined $prefix);

    $this->{LOG}->info("====> Inserting loginuser ($loginuser->{login}, $loginuser->{passwd}, $loginuser->{name}, $prefix) ...");

    my $set = DBIx::Recordset->SetupObject ({'!DataSource' => $this->{DB},
					     '!Table'      => $prefix . 'loginusers',
					    });
    $set->Insert($loginuser);
    $set->Disconnect;

    return;
}

sub db_update_loginuser {
    my ($this, $loginuser, $prefix) = @_;

    $this->tracer($loginuser) if ($this->{DEBUG});

    $prefix='' unless (defined $prefix);

    $this->{LOG}->info("====> Updating loginuser ($loginuser->{login}, $loginuser->{passwd}, $loginuser->{name}, $prefix) ...");

    my $set = DBIx::Recordset->SetupObject ({'!DataSource' => $this->{DB},
					     '!Table'      => $prefix . 'loginusers',
					    });
    $set->Update($loginuser, { login=>$loginuser->{login} });
    $set->Disconnect;

    return;
}

sub db_delete_loginuser {
    my ($this, $loginuserid, $prefix) = @_;

    $this->tracer($loginuserid||'NULL') if ($this->{DEBUG});

    $prefix='' unless (defined $prefix);

    $this->{LOG}->info("====> Delete loginuser (loginuserid $loginuserid, $prefix) ...");

    my $set = DBIx::Recordset->SetupObject ({'!DataSource' => $this->{DB},
					     '!Table'      => $prefix . 'loginusers',
					    });
    $set->Delete({login=>$loginuserid});
    $set->Disconnect;

    return;
}

sub db_insert_table {
    my ($this, %args) = @_;

    $this->tracer($args{value}) if ($this->{DEBUG});
    return undef unless ($args{table} and $args{value});

    $this->{LOG}->info("====> Inserting $args{table} ...");

    my $set = DBIx::Recordset->SetupObject ({'!DataSource' => $this->{DB},
					     '!Table'      => $args{table},
					    });
    $set->Insert($args{value});
    $set->Disconnect;

    return;
}

# db_update_table - updates a record in a database-table. Input is a
#                   hash with arguments. An argument named 'table'
#                   must give a tablename in the database, and an
#                   argument 'value' must exist and be a hash-ref to
#                   the values that should be updated. If there is no
#                   argument named 'key', the value 'id' is used for
#                   key. Returns undef if table and value aren't in
#                   the arguments. Returns nothing (i.e. empty list in
#                   list-context and undef in scalar context; see
#                   perldoc -f return) on success.
sub db_update_table {
    my ($this, %args) = @_;

    $this->tracer($args{value}) if ($this->{DEBUG});
    return undef unless ($args{table} and $args{value});
    $args{key} ||= 'id';

    $this->{LOG}->info("====> Updating $args{table} ($args{value}->{$args{key}} ...");

    my $set = DBIx::Recordset->SetupObject ({'!DataSource' => $this->{DB},
					     '!Table'      => $args{table},
					    });
    $set->Update($args{value}, { $args{key}=>$args{value}->{$args{key}} });
    $set->Disconnect;

    return;
}

sub db_delete_table {
    my ($this, %args) = @_;

    $this->tracer($args{id}||'NULL') if ($this->{DEBUG});
    return undef unless ($args{table} and $args{id});
    $args{key} ||= 'id';

    $this->{LOG}->info("====> Delete $args{table} ($args{key} $args{id}) ...");

    my $set = DBIx::Recordset->SetupObject ({'!DataSource' => $this->{DB},
					     '!Table'      => $args{table},
					    });
    $set->Delete( { $args{key}=>$args{id} } );
    $set->Disconnect;

    return;
}

sub db_insert_docparams {
    my ($this, $doc, $params) = @_;

    $this->tracer($doc, $params) if($this->{DEBUG});

    $this->{LOG}->info("====> Inserting docparams for docid " . $doc->Id . "...");


    my $set = DBIx::Recordset->SetupObject ({'!DataSource' => $this->{DB},
                                            '!Table'      => 'docparms',
                                            });
    for($params->param) {
        $set->Insert({
                        docid => $doc->Id,
                        name => $_,
                        value => $params->param($_)
                    });
    }
    $set->Disconnect;

    return;
}

sub db_delete_docparams {
    my ($this, $doc) = @_;

    $this->tracer($doc) if($this->{DEBUG});

    $this->{LOG}->info("====> Deleting docparams for docid " . $doc->Id . "...");

    my $set = DBIx::Recordset->SetupObject ({'!DataSource' => $this->{DB},
                                            '!Table'      => 'docparms',
                                            });
    $set->Delete({docid => $doc->Id});
    $set->Disconnect;

    return;
}

1;
__END__

=head1 NAME

Obvius::DB - Database functions for L<Obvius>.

=head1 SYNOPSIS

  use Obvius;
  use Obvius::Config;

  my $config = new Obvius::Config("configname");
  my $obvius = new Obvius($config);

  $obvius->db_error();

  $obvius->db_insert_comment({
                              docid=>$doc->Id,
                              name=>'Søren Hansen',
                              email=>'sh@example.invalid',
                              text=>'Jeg synes bare det er helt, ja det er.',
                             });

  $obvius->db_update_table(table=>'synonyms', synonyms=>'Søren Soeren');
  $obvius->db_update_table(table=>'docparms', key=>'docid', name=>'fancy_box', value=>'NO!', type=>0);

=head1 DESCRIPTION

This module contains the database functions for the L<Obvius> module.
It should not be used as a standalone module.

=head1 AUTHORS

Jørgen Ulrik B. Krag E<lt>jubk@magenta-aps.dkE<gt>
Peter Makholm E<lt>pma@fi.dkE<gt>
René Seindal
Adam Sjøgren E<lt>asjo@magenta-aps.dkE<gt>
Martin Skøtt E<lt>martin@magenta-aps.dkE<gt>

=head1 SEE ALSO

L<Obvius>.

=cut
