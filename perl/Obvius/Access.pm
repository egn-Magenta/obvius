package Obvius::Access;

########################################################################
#
# Access.pm - access to functionality; capability-handling
#
# Copyright (C) 2001-2005 Magenta Aps, Denmark (http://www.magenta-aps.dk/)
#                         aparte A/S, Denmark (http://www.aparte.dk/),
#                         FI, Denmark (http://www.fi.dk/)
#
# Authors: Jørgen Ulrik B. Krag (jubk@magenta-aps.dk),
#          Peter Makholm (pma@fi.dk)
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
#	Access-related methods
#
########################################################################

sub _get_capability_rules
{
	my ($this, $doc) = @_;
	return unless $doc;

	my $rules = $doc-> AccessRules || 'INHERIT';
	$rules =~ s/\r//gs;

	return map {
		($_ eq 'INHERIT') ?
			$this-> _get_capability_rules( $this->get_doc_by_id( $doc->Parent)) :
			$_
	} split /\n/, $rules;
}

sub get_capability_rules
{
	my ($this, $doc) = @_;

	return
		$this-> _get_capability_rules( $this-> get_universal_document()),
		$this-> _get_capability_rules( $doc)
		;
}

# user_has_capabilities - Return true if the user has all of the capabilities listed in
#                         @capabilities on $doc. Note: this method returns false if the user
#                         is missing just one of the capabilites requested.
#                         Always returns true for 'admin'.
sub user_has_capabilities {
    my ($this, $doc, @capabilities) = @_;
    return 1 if ($this->{USER} eq 'admin' and $this->get_userid($this->{USER})==1);

    my $capabilities=$this->user_capabilities($doc);

    foreach (@capabilities) {
	return 0 unless ($capabilities->{$_});
    }
    return 1;
}

# user_has_any_capability - Return a count of how many of the capabilites in @capabilites the user 
#                           has on $doc. Always returns 1 for 'admin'.
sub user_has_any_capability {
    my ($this, $doc, @capabilities) = @_;
    return 1 if ($this->{USER} eq 'admin' and $this->get_userid($this->{USER})==1);

    my $capabilities=$this->user_capabilities($doc);

    my $any=0;
    foreach (@capabilities) {
	$any++ if ($capabilities->{$_});
    }
    return $any;
}

sub compute_user_capabilities
{
    my ($this, $doc, $userid) = @_;

    my $user_groups=$this->get_user_groups($userid);

    my @rules=$this->get_capability_rules($doc);

    my @accept;
    my @deny;
    my @unconditional_deny;
    foreach (@rules) {
	#print STDERR "  accept: " . Dumper(\@accept);
	#print STDERR "  deny: " . Dumper(\@deny);
	#print STDERR " zee rule: $_\n";

        my ($apply, $who_list, $how, $capabilities)=$this->parse_access_rule($_, $doc, $userid);
        if (defined $apply) {
	    if ($apply) {
		#print STDERR " applying rule $_\n";
		my @capabilities=split /\s*,\s*/, $capabilities;
		if ( $how eq "=" ) {
		    @accept=@capabilities;
		}
		elsif ($how eq "=!") {
		    @accept=@capabilities; @deny=();
		}
		elsif ($how eq "+") {
		    push @accept, @capabilities;
		}
		elsif ($how eq "-") {
		    push @deny, @capabilities;
		}
		elsif ($how eq "!") {
		    push @unconditional_deny, @capabilities;
		}
	    }
	    #else {
            #    print STDERR " not applying rule $_\n";
	    #}
	}
	else {
	    $this->log->warn("Unrecognized access rule '$_' for docid " . $doc->Id);
	}
    }

    #print STDERR "  accept: " . Dumper(\@accept);
    #print STDERR "  deny: " . Dumper(\@deny);

    my %capabilities;
    foreach (@accept) {
	$capabilities{$_}=1;
    }
    foreach (@deny, @unconditional_deny) {
	delete $capabilities{$_};
    }

    return \%capabilities;
}

sub user_capabilities {
    my ($this, $doc) = @_;

    $this->{CAPABILITIES}={} unless (defined $this->{CAPABILITIES});
    return $this->{CAPABILITIES}->{$doc->Id} if (defined $this->{CAPABILITIES}->{$doc->Id});

    my $capabilities = $this-> compute_user_capabilities( $doc, $this->get_userid( $this->user));

    return $this->{CAPABILITIES}->{$doc->Id} = $capabilities;
}

# access_rule_applies - given a string with an access rule and a
#                       document object, returns 1 if the rule applies
#                       to the current user, 0 if it doesn't apply and
#                       undef if the rule is invalid.
sub access_rule_applies {
    my ($this, $line, $doc, $userid)=@_;

    my ($apply)=$this->parse_access_rule($line, $doc, $userid);

    return $apply;
}

# parse_access_rule - given a string with an access rule, a document
#                     object and optionally a numeric user id and an
#                     array-ref to the groups the user is in, returns
#                     a list with the values: apply which is undef if
#                     the rule wasn't valid, 0 if the rule is not to
#                     be applied to the user and 1 if it is, who_list
#                     which is the left-hand side of the rule, how
#                     which is the operator from the rule and finally
#                     capabilities which is the right-hand side of the
#                     rule.
sub parse_access_rule {
    my ($this, $line, $doc, $userid, $user_groups)=@_;

    $userid=$this->get_userid($this->user) if (!defined $userid);
    $user_groups=$this->get_user_groups($userid) if (!defined $user_groups);

    if ($line =~ /^([^=+\-]+)(!|=|=!|\+|-)\s*([^=+!\-]+)$/) {
        my ($who_list, $how, $capabilities)=($1, $2, $3);

        my $apply=0;
        if (defined $userid) {
            my @who_list=split /\s*,\s*/, $who_list;
            my $user = $this-> get_user($userid);
	    if (grep { (defined $user && $user->{login} eq $_) or $_ eq 'ALL' } @who_list) {
		$apply=1;
	    }
            # OWNER:
            elsif ($doc->Owner == $userid and grep { $_ eq 'OWNER' } @who_list) {
                $apply=1
            }
            # GROUP:
            elsif (grep { $_ eq 'GROUP' } @who_list and
                   grep { $doc->Grp == $_ } @$user_groups ) {
                $apply=1;
            }
            # @group:
            else {
                my %groups=();
                map {
                    my $groupname=substr($_, 1);
                    my $groupid=$this->get_grpid($groupname);
                    if ($groupid) {
                        $groups{$groupid}=$groupname;
                    }
                    else {
                        $this->log->warn("Access rule for unknown group '$groupname' encountered for docid " . $doc->Id);
                        $apply=undef;
                    }
                } grep { /^@/ } @who_list;
                foreach (@$user_groups) {
                    $apply=1 if (defined $groups{$_});
                }
            }
        }
        elsif ($who_list =~ /(^|,|\s)PUBLIC(,|\s|)/) {
            $apply=1;
        }

        return ($apply, $who_list, $how, $capabilities);
    }

    return undef;
}

# set_access_data - given a document object, a numerical owner id, a
#                   numerical group id and a string with accessrules,
#                   updates the database with them if the user has
#                   access to do so. Returns nothing.
sub set_access_data {
    my ($this, $doc, $owner, $grp, $accessrules) = @_;

    die "User $this->{USER} does not have access to change the accessrules for this document."
	unless $this->can_set_access_data($doc);

    # XXX Check validity of owner, grp and accessrules!
    $doc->param(owner=>$owner);
    $doc->param(grp=>$grp);
    $doc->param(accessrules=>$accessrules);

    return $this->db_update_document($doc, [qw(owner grp accessrules)]);
}

sub can_view_document {
    my ($this, $doc)=@_;

    return $this->user_has_capabilities($doc, qw(view));
}

# can_create_new_document - Return true if the user can create a new document.
#                           Always returns true for 'admin'.
sub can_create_new_document {
    my ($this, $parent) = @_;

    return $this->user_has_capabilities($parent, qw(create));
}

# can_create_new_version - return true if the current user is allowed to 
#                          create new versions of $doc. Returns false if
#                          the user doesn't have the necessary rights.
sub can_create_new_version {
    my ($this, $doc) = @_;

    # Consider whether making a new version (new language/type) should
    # require create-capability...
    return $this->user_has_capabilities($doc, qw(edit));
}

# can_delete_document - given a document-object, checks whether the
#                       current user has access to delete the
#                       document. Please note that this function
#                       returns false if the document has
#                       subdocuments, which is questionable.
sub can_delete_document {
    my ($this, $doc) = @_;

    # Sneaky, this _also_ checks for subdocs, which makes the
    # error-message from below wrong when there are subdocs...

    # asjo: XXX We should change this, so only capabilities are
    # checked by can_delete_document, I think (then admin can use it
    # to determine whether to make the delete-button inactive or not
    # (now that there's recursive delete).  Or perhaps
    # can_delete_document should recursively check capabilities. That
    # would make more sense, come to think of it.
    return (
	    (!$this->get_docs_by_parent($doc->Id)) and
	    $this->user_has_capabilities($doc, qw(delete))
	   );
}

sub can_rename_document_create {
    my ($this, $doc) = @_;

    # Check if you are able to create at the destination point.
    return ($this->user_has_capabilities($doc, qw(create)));
}

sub can_delete_single_version {
    my ($this, $doc) = @_;

    return $this->user_has_capabilities($doc, qw(delete));
}

sub can_rename_document {
    my ($this, $doc) = @_;

    # One also needs to be able to create at the destination point,
    # but that can't be checked for menu-ghosting. It could be checked
    # otherwise though, and probably should. Here.
    return ($this->user_has_capabilities($doc, qw(delete)));
}

sub can_publish_version {
    my ($this, $vdoc) = @_;

    my $doc=$this->get_doc_by_id($vdoc->Docid);
    return $this->user_has_capabilities($doc, qw(publish));
}

sub can_unpublish_version {
    my ($this, $vdoc) = @_;

    my $doc=$this->get_doc_by_id($vdoc->Docid);
    return $this->user_has_capabilities($doc, qw(publish));
}

sub can_set_access_data {
    my ($this, $doc) = @_;

    # Not sure about this one...:
    return $this->user_has_capabilities($doc, qw(modes));
}

sub can_create_new_user  { $_[0]->{USERS}->{$_[0]->{USER}}->{can_manage_users} }
sub can_create_new_group { $_[0]->{USERS}->{$_[0]->{USER}}->{can_manage_groups} }

sub can_update_comment {
    my ($this, $doc) = @_;

    return $this->user_has_capabilities($doc, qw(edit));
}

sub can_delete_comment {
    my ($this, $docid) = @_;
    
    my $doc = ref($docid) eq 'Obvius::Document' ? $docid : $this->get_doc_by_id($docid);
    return $this->user_has_capabilities($doc, qw(delete));
}

# can_set_docparams - given a document-object returns true if the user
#                     is allowed to set document parameters on the
#                     document, false otherwise.
sub can_set_docparams {
    my ($this, $doc) = @_;

    # Should this be modes?
    return $this->user_has_capabilities($doc, qw(modes));
}


1;
__END__

=head1 NAME

Obvius::Access - Access related functions for L<Obvius>.

=head1 SYNOPSIS

  use Obvius;
  use Obvius::Config;

  my $config = new Obvius::Config("configname");
  my $obvius = new Obvius($config);

  $obvius->user_capabilities($doc);

  $ret=$obvius->can_delete_document($doc);

  $ret=$obvius->can_create_new_version($doc);

  $ret=$obvius->user_has_capabilities($doc, qw (edit delete create));

  $ret=$obvius->user_has_any_capability($doc, qw (edit delete create));

  $obvius->set_access_data($doc, $new_owner->Id, $new_grp->Id, accessrules=>$str);

  $ret=$obvius->can_set_docparams($doc);

=head1 DESCRIPTION

This module contains access related functions for L<Obvius>.
It is not intended for use as a standalone module.

=head1 AUTHORS

Jørgen Ulrik B. Krag E<lt>jubk@magenta-aps.dkE<gt>
Peter Makholm E<lt>pma@fi.dkE<gt>
Adam Sjøgren E<lt>asjo@magenta-aps.dkE<gt>

=head1 SEE ALSO

L<Obvius>.

=cut
