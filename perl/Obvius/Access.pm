package Obvius::Access;

########################################################################
#
# Obvius.pm - Content Manager, database handling
#
# Copyright (C) 2001 Magenta Aps, Denmark (http://www.magenta-aps.dk/)
#                    aparte A/S, Denmark (http://www.aparte.dk/),
#                    FI, Denmark (http://www.fi.dk/)
#
# Authors: Adam Sjøgren (asjo@magenta-aps.dk),
#          Jørgen Ulrik B. Krag (jubk@magenta-aps.dk)
#          Peter Makholm (pma@fi.dk)
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

sub get_capability_rules {
    my ($this, $doc) = @_;
    return () unless ($doc);

    my $rules=$doc->AccessRules || 'INHERIT';
    $rules =~ s/\r//g;
    chomp($rules);

    if ($rules eq "INHERIT") {
	return $this->get_capability_rules($this->get_doc_by_id($doc->Parent));
    }
    else {
	my @rules=split /\n/, $rules;
	map { chomp } @rules;
	my @final;
	foreach (@rules) {
	    if ($_ eq "INHERIT") {
		push @final, $this->get_capability_rules($this->get_doc_by_id($doc->Parent));
	    }
	    else {
		push @final, $_;
	    }
	}
	return @final;
    }
}

sub user_has_capabilities {
    my ($this, $doc, @capabilities) = @_;
    return 1 if ($this->{USER} eq 'admin' and $this->get_userid($this->{USER})==1);

    my $capabilities=$this->user_capabilities($doc);

    foreach (@capabilities) {
	return 0 unless ($capabilities->{$_});
    }
    return 1;
}

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

sub user_capabilities {
    my ($this, $doc) = @_;

    $this->{CAPABILITIES}={} unless (defined $this->{CAPABILITIES});
    return $this->{CAPABILITIES}->{$doc->Id} if (defined $this->{CAPABILITIES}->{$doc->Id});

    my $user=$this->{USER};
    my $userid=$this->get_userid($user);
    my $user_groups=$this->get_user_groups($userid);

    my @rules=$this->get_capability_rules($doc);

    my @accept;
    my @deny;
    foreach (@rules) {
	#print STDERR "  accept: " . Dumper(\@accept);
	#print STDERR "  deny: " . Dumper(\@deny);
	#print STDERR " zee rule: $_\n";

	if (/^([^=+\-]+)(=|=!|[+]|-)\s*([^=+!\-]+)$/) {
	    my ($who_list, $how, $capabilities)=($1, $2, $3);

	    my $apply=0;
	    if (defined $userid) {
		my @who_list=split /\s*,\s*/, $who_list;
		# ALL or username:
		if (grep { $user eq $_ or $_ eq 'ALL' } @who_list) {
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
		    my %groups = map {
			my $grp=substr($_, 1);
			$this->get_grpid($grp)=>$grp
		    } grep { /^@/ } @who_list;
		    foreach (@$user_groups) {
			$apply=1 if (defined $groups{$_});
		    }
		}
	    }
	    elsif ($who_list =~ /(^|,|\s)PUBLIC(,|\s|)/) {
		$apply=1;
	    }

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
	    }
	    else {
		#print STDERR " not applying rule $_\n";
	    }
	}
	else {
	    $this->{LOG}->warn("UNRECOGNIZED RULE: [$_]");
	}
    }

    #print STDERR "  accept: " . Dumper(\@accept);
    #print STDERR "  deny: " . Dumper(\@deny);

    my %capabilities;
    foreach (@accept) {
	$capabilities{$_}=1;
    }
    foreach (@deny) {
	delete $capabilities{$_};
    }

    #print STDERR "FINAL capabilities: " . Dumper(\%capabilities);

    $this->{CAPABILITIES}->{$doc->Id}=\%capabilities;

    return \%capabilities;
}

sub set_access_data {
    my ($this, $doc, $owner, $grp, $accessrules) = @_;

    die "User $this->{USER} does not have access to change the accessrules for this document."
	unless $this->can_set_access_data($doc);

    $doc->param(owner=>$owner);
    $doc->param(grp=>$grp);
    $doc->param(accessrules=>$accessrules);

    return $this->db_update_document($doc, [qw(owner grp accessrules)]);
}



sub can_create_new_document {
    my ($this, $parent) = @_;

    return $this->user_has_capabilities($parent, qw(create));
}


sub can_create_new_version {
    my ($this, $doc) = @_;

    # Consider whether making a new version (new language/type) should
    # require create-capability...
    return $this->user_has_capabilities($doc, qw(edit));
}

sub can_delete_document {
    my ($this, $doc) = @_;

    return (
	    (!$this->get_docs_by_parent($doc->Id)) and
	    $this->user_has_capabilities($doc, qw(delete))
	   );
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

sub can_create_new_user {
    my ($this, $doc) = @_;

    $doc ||= $this->get_doc_by_id(1); # XXX Root
    return $this->user_has_capabilities($doc, qw(admin)); # Changed from 'modes' to 'admin'.
}

sub can_create_new_group {
    my ($this, $doc) = @_;

    $doc ||= $this->get_doc_by_id(1); # XXX Root
    return $this->user_has_capabilities($doc, qw(admin)); # Changed from 'modes' to 'admin'
}

sub can_update_comment {
    my ($this, $doc) = @_;

    return $this->user_has_capabilities($doc, qw(edit));
}

sub can_delete_comment {
    my ($this, $docid) = @_;

    my $doc=$this->get_doc_by_id($docid);
    return $this->user_has_capabilities($doc, qw(delete));
}

sub can_set_docparams {
    my ($this, $doc) = @_;

    # Should this be modes?
    return $this->user_has_capabilities($doc, qw(modes));
}


1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Obvius::Access - Access related functions for L<Obvius>.

=head1 SYNOPSIS

  use Obvius;
  use Obvius::Config;

  my $config = new Obvius::Config("configname");
  my $obvius = new Obvius($config);

  $obvius->user_capabilities($doc);

  etc.

=head1 DESCRIPTION

This module contains access related functions for L<Obvius>.
It is not intended for use as a standalone module.

=head2 EXPORT

None.

=head1 AUTHORS

Adam Sjøgren E<lt>adam@aparte.dkE<gt>

Jørgen Ulrik B. Krag, E<lt>jubk@magenta-aps.dkE<gt>

=head1 SEE ALSO

L<Obvius>.

=cut
