package Obvius::Comments;

########################################################################
#
# Obvius.pm - Content Manager, page comments handling
#
# Copyright (C) 2001 aparte A/S, Denmark (http://www.aparte.dk/)
#                    FI, Denmark (http://www.fi.dk/)
#
# Authors: Adam Sjøgren (asjo@magenta-aps.dk),
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
#	Methods for Comments System
#
########################################################################

sub get_comments {
    my ($this, $docid, %options) = @_;

    my $doc=$this->get_doc_by_id($docid) or return undef;
    return undef unless ($this->is_public_document($doc));

    my $set = DBIx::Recordset->SetupObject( {'!DataSource' => $this->{DB},
					     '!Table'      => 'comments',
					    } );

    my @comments;
    $set->Search({docid=>$docid, '$order'=>'date', %options });
    while (my $rec=$set->Next) {
	my %comment=(date=>$rec->{date}, name=>$rec->{name}, email=>$rec->{email}, text=>$rec->{text}, show_email=>$rec->{show_email});
	push @comments, \%comment;
    }

    $set->Disconnect;

    return (@comments ? \@comments : undef);
}

sub get_comment {
    my ($this, $docid, $date) = @_;

    my $comments=$this->get_comments($docid, date=>$date);
    return (defined $comments ? $comments->[0] : undef);
}

sub create_new_comment {
    my ($this, $data) = @_;

    return undef unless (defined $data->{docid});
    return undef unless (defined $data->{name} and !($data->{name}=~/^\s*$/));
    return undef unless (defined $data->{text} and !($data->{text}=~/^\s*$/));

    $data->{text}=~s/\r//g;

    return $this->db_insert_comment($data);
}

sub update_comment {
    my ($this, $doc, $data) = @_;

    return undef unless $this->can_update_comment($doc);

    $this->db_begin;
    eval {
	die "No docid and date!" unless ($data->{docid} and $data->{date});

	$this->db_update_comment($data);
	$this->db_commit;
    };

    if ($@) {			# handle error
	$this->{DB_Error} = $@;
	$this->db_rollback;
	$this->{LOG}->error("====> Update comment ... failed ($@)");
	return undef;
    }

    undef $this->{DB_Error};
    $this->{LOG}->info("====> Update comment ... done");
    return 1;
}

sub delete_comment {
    my ($this, $docid, $date) = @_;

    return undef unless ($this->can_delete_comment($docid, $date));
    return undef unless ($this->get_comment($docid, $date));

    $this->db_begin;
    eval {
	die "No docid and date!" unless ($docid and $date);

	$this->db_delete_comment($docid, $date);
	$this->db_commit;
    };

    if ($@) {			# handle error
	$this->{DB_Error} = $@;
	$this->db_rollback;
	$this->{LOG}->error("====> Delete comment ... failed ($@)");
	return undef;
    }

    undef $this->{DB_Error};
    $this->{LOG}->info("====> Delete comment ... done");
    return 1;
}

1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Obvius::Comments - Comment functions for L<Obvius>.

=head1 SYNOPSIS

  use Obvius;
  use Obvius::Config;

  my $config = new Obvius::Config("configname");
  my $obvius = new Obvius($config);

  $obvius->get_comments($docid, %options);

  etc.

=head1 DESCRIPTION

This module contains functions for the page commenting system
in L<Obvius>.
It is not intended for use as a standalone module.

=head2 EXPORT

None.

=head1 AUTHOR

Adam Sjøgren, E<lt>adam@aparte.dkE<gt>

Jørgen Ulrik B. Krag, E<lt>jubk@magenta-aps.dkE<gt>

=head1 SEE ALSO

L<Obvius>.

=cut
