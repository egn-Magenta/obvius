package WebObvius::Admin;

########################################################################
#
# Admin.pm - support module for the Obvius administration system
#
# Copyright (C) 2001-2005 Magenta Aps, Denmark (http://www.magenta-aps.dk/)
#                         aparte A/S, Denmark (http://www.aparte.dk/),
#
# Authors: Jørgen Ulrik B. Krag (jubk@magenta-aps.dk)
#          René Seindal,
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

# $Id$

use strict;
use warnings;

use WebObvius;

our @ISA = qw( WebObvius );
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

use Apache::Session;
use Apache::Session::File;


########################################################################
#
#	Set up an editing session:
#
########################################################################

sub prepare_edit {
    my ($this, $req, $doc, $vdoc, $doctype, $obvius) = @_;

    my $session=$this->get_session();
    die "No session available - fatally wounded.\n" unless ($session);

    my $editpages=$obvius->get_editpages($doctype);

    my @pages;
    map {
	my $editpage=$editpages->{$_};
	my %page=(
		  title=>$editpage->Title,
		  help=>'page/' . $editpage->Page,
		  description=>$editpage->Description,
		  comp=>'/edit/edit', # For this particular purpose.
		 );
	$page{fieldlist}=$this->parse_editpage_fieldlist($editpage->Fieldlist, $doctype, $obvius);
	push @pages, \%page;
    } sort {$a <=> $b} grep { /^\d+$/ } keys %$editpages;

    $session->{pages}=\@pages;
    $obvius->get_version_fields($vdoc, 255); # All fields
    #use Data::Dumper;
    # It's not a good idea that fields that are optional and don't have a value are
    # inserted into fields_in as empty fields ('') instead of undef (or not there at all).
    # (this has been fixed in get_version_fields, I think).
    #print STDERR " prepare_edit: " . Dumper($vdoc->{FIELDS});
    $session->{fields_in}=$vdoc->{FIELDS};
    $session->{fields_out}=new Obvius::Data;
    $session->{document}=$doc;
    $session->{version}=$vdoc;
    $session->{doctype}=$doctype;
    $session->{done_comp}='/edit/validate/version';

    my $sessionid=$session->{_session_id};
    $this->release_session($session);

    return $sessionid;
}


########################################################################
#
#	Session handling
#
########################################################################

# get_session - if given a string with a session id, tries to get the
#               corresponding session. If the argument is undefined, a
#               new session is created and returned. Returns a
#               hash-ref to the session on success and undef on
#               failure.
sub get_session {
    my ($this, $id) = @_;

    my %session;
    eval {
	tie %session, 'Apache::Session::File',
	    $id, { Directory => $this->{EDIT_SESSIONS},
		   LockDirectory => $this->{EDIT_SESSIONS} . '/LOCKS',
		 };
    };
    if ($@) {
	warn "Can't get session data $id: $@\n\t";
	return undef;
    }

    return \%session;
}

sub release_session {
    my ($this, $session) = @_;

    untie %$session;
}

1;
__END__

=head1 NAME

WebObvius::Admin - support module for the Obvius administration system.

=head1 SYNOPSIS

  use WebObvius::Admin;

=head1 DESCRIPTION

WebObvius::Admin contains various support-functions for the
admin-system.

=head1 EXPORT

None by default.

=head1 AUTHOR

Jørgen Ulrik B. Krag <lt>krag@aparte.dk<gt>
René Seindal
Adam Sjøgren <lt>asjo@aparte-test.dk<gt>

=head1 SEE ALSO

L<WebObvius::Site>, L<mason/autohandler>.

=cut
