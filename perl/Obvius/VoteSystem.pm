package Obvius::VoteSystem;

########################################################################
#
# Obvius.pm - Content Manager, database handling
#
# Copyright (C) 2001 aparte A/S, Denmark (http://www.aparte.dk/)
#
# Authors: Jørgen Ulrik B. Krag (jubk@magenta-aps.dk)
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
#	Methods for MultiChoice/Voting System
#
########################################################################

sub voter_is_registered {
    my($this, $voter_id, $docid) = @_;

    $this->tracer($voter_id, $docid) if $this->{DEBUG};

    my $set=DBIx::Recordset->SetupObject( {'!DataSource'=>$this->{DB},
					   '!Table'     =>'voters',
					  } );
    $set->Search({ docid=>$docid, cookie=>$voter_id });

    my $data = $set->Next;

    $set->Disconnect;

    return $data;
}

sub register_voter {
    my($this, $docid, $voter_id) = @_;

    $this->tracer($docid, $voter_id) if $this->{DEBUG};

    my $set=DBIx::Recordset->SetupObject( {'!DataSource'=>$this->{DB},
                      '!Table'     =>'voters',
                    } );
    $set->Insert({ docid=>$docid, cookie=>$voter_id });

    $set->Disconnect;
}

sub register_vote {
    my($this, $docid, $vote_id) = @_;

    $this->tracer($docid, $vote_id) if $this->{DEBUG};

    my $set=DBIx::Recordset->SetupObject( {'!DataSource'=>$this->{DB},
					   '!Table'     =>'votes',
					  } );
    $set->Search({ docid=>$docid, answer=>$vote_id });

    my $data = $set->Next;

    if($data) {
        $data->{total}++;

        $set->Update($data, { docid=>$data->{docid}, answer=>$data->{answer} });
    } else {
        $set->Insert( { docid=>$docid, answer=>$vote_id, total=>1 })
    }

    $set->Disconnect;
}

sub get_votes {
    my($this, $docid) = @_;

    $this->tracer($docid) if $this->{DEBUG};

    my $set=DBIx::Recordset->SetupObject( {'!DataSource'=>$this->{DB},
                      '!Table'     =>'votes',
                    } );
    $set->Search({ docid=>$docid });

    my $votes;
    my $rec;
    while($rec=$set->Next) {
        $votes->{$rec->{answer}} = $rec->{total};
    }
    $set->Disconnect;

    return $votes;
}

sub get_votedoc_ids_by_cookie {
    my($this, $cookie) = @_;

    $this->tracer($cookie) if $this->{DEBUG};

    my $set=DBIx::Recordset->SetupObject( {'!DataSource'=>$this->{DB},
                                            '!Table'     =>'voters',
                                            '!Debug'     => 8
                    } );
    $set->Search({ cookie=>$cookie });


    my @docs;
    my $rec;
    while($rec=$set->Next) {
        push(@docs, $rec->{docid})
    }
    $set->Disconnect;

    return \@docs;
}

1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Obvius::VoteSystem - VoteSystem functions for L<Obvius>.

=head1 SYNOPSIS

  use Obvius;
  use Obvius::Config;

  my $config = new Obvius::Config("configname");
  my $obvius = new Obvius($config);

  $obvius->get_votes($docid);

  etc.

=head1 DESCRIPTION

This module contains votesystem functions for L<Obvius>.
It is not intended for use as a standalone module.

=head2 EXPORT

None.


=head1 AUTHORS

Adam Sjøgren, E<lt>adam@aparte.dkE<gt>

Jørgen Ulrik B. Krag, E<lt>jubk@magenta-aps.dkE<gt>

=head1 SEE ALSO

L<Obvius>.

=cut
