package Obvius::Subscriptions;

########################################################################
#
# Subscriptions.pm - handling the subscription system
#
# Copyright (C) 2001-2004 Magenta Aps, Denmark (http://www.magenta-aps.dk/)
#                         aparte A/S, Denmark (http://www.aparte.dk/),
#                         FI, Denmark (http://www.fi.dk/)
#
# Authors: Jørgen Ulrik B. Krag (jubk@magenta-aps.dk),
#          Peter Makholm (pma@fi.dk),
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
#	Methods for Subscription System
#
########################################################################

# get_subscriber - given a hash-ref with sufficient key-value pairs to
#                  identify at least one subscriber, returns a
#                  hash-ref containing the data of the first match in
#                  the subscribers table.
sub get_subscriber {
    my ($this, $subscriber) = @_;

    my $set=DBIx::Recordset->SetupObject( {'!DataSource'=>$this->{DB},
					   '!Table'     =>'subscribers',
                                           '!TieRow'    =>0,
					  } );
    $set->Search($subscriber);
    my $data = $set->Next;
    $set->Disconnect;

    return $data;
}

sub add_subscriber {
    my ($this, $data, %options) = @_;

    my $set=DBIx::Recordset->SetupObject( {'!DataSource'=>$this->{DB},
					   '!Table'     =>'subscribers',
                                           '!Serial'    =>'id',
                                           '!TieRow'    =>0,
					  } );
    $set->Insert($data);
    $set->Disconnect;

    my $subscriber=$set->LastSerial;
    $this->add_subscriber_categories($subscriber, $options{categories});

    return $data;
}

sub update_subscriber {
    my ($this, $new_data, %options) = @_;

    my $set=DBIx::Recordset->SetupObject( {'!DataSource'=>$this->{DB},
                                           '!Table'     =>'subscribers',
                                           '!TieRow'    =>0,
                                          } );

    if ($options{email}) {
        $set->Update($new_data, {email=>$options{email}});
    }
    else {
        $set->Update($new_data, {id=>$new_data->{id}});
    }

    $set->Disconnect;

    if (exists $options{categories}) {
        my $subscriber;
        if ($options{email}) {
            $subscriber=$this->get_subscriber({email=>$options{email}});
        }
        else {
            $subscriber=$this->get_subscriber({id=>$new_data->{id}});
        }
        $this->update_subscriber_categories($subscriber->{id}, $options{categories})
    }
}
# delete_subscriber($subscriber) - Removes the subscriber with ID $subscriber and
#                                  all his subscriptions and subscriber categories.
sub delete_subscriber {
    my ($this, $subscriber) = @_;

    $this->{LOG}->info("delete_subscriber: $subscriber");
    return undef unless ($subscriber);

    $this->update_subscriptions($subscriber, []);
    $this->delete_subscriber_categories($subscriber);

    my $set=DBIx::Recordset->SetupObject( {'!DataSource'=>$this->{DB},
                                           '!Table'     =>'subscribers',
                                           '!TieRow'    =>0,
                                          } );
    $set->Delete({id=>$subscriber});
    $set->Disconnect;
}

sub set_subscriber_cookie {
    my ($this, $email, $cookie) = @_;

    my $set=DBIx::Recordset->SetupObject( {'!DataSource'=>$this->{DB},
					   '!Table'     =>'subscribers',
                                           '!TieRow'    =>0,
					  } );
    $set->Update({cookie=>$cookie}, {email=>$email});
    $set->Disconnect;
}

sub get_all_subscribers {
    my ($this, $where) = @_;

    $this->tracer($where) if $this->{DEBUG};

    my $set=DBIx::Recordset->SetupObject( {'!DataSource'=>$this->{DB},
					   '!Table'     =>'subscribers',
                                           '!TieRow'    =>0,
					  } );
    $set->Search($where);

    my $rec;
    my @data;

    while($rec=$set->Next) {
        push(@data, $rec);
    }

    $set->Disconnect;

    return \@data;
}

sub get_subscriptions {
    my ($this, $where) = @_;

    $this->tracer($where) if $this->{DEBUG};

    my $set=DBIx::Recordset->SetupObject( {'!DataSource'=>$this->{DB},
					   '!Table'     =>'subscriptions',
                                           '!TieRow'    =>0,
					  } );
    $set->Search($where);

    my $rec;
    my @data;

    while($rec=$set->Next) {
        push(@data, $rec);
    }

    $set->Disconnect;

    return \@data;
}

sub add_subscription {
    my ($this, $data) = @_;

    $this->tracer($data) if $this->{DEBUG};

    # Double check that this is actually a subscribeable document
    return undef unless( $this->search( ['subscribeable'], "subscribeable != '' and docid = ". $data->{docid}, notexpired=>1, public=>1 ) );

    my $set=DBIx::Recordset->SetupObject( {'!DataSource'=>$this->{DB},
					   '!Table'     =>'subscriptions',
                                           '!TieRow'    =>0,
					  } );
    $set->Insert($data);
    $set->Disconnect;
}

sub remove_subscription {
    my ($this, $docid, $subscriber) = @_;

    return undef unless($docid and $subscriber);

    my $set=DBIx::Recordset->SetupObject( {'!DataSource'=>$this->{DB},
					   '!Table'     =>'subscriptions',
                                           '!TieRow'    =>0,
					  } );
    $set->Delete( { docid=>$docid, subscriber=>$subscriber} );
    $set->Disconnect;
}

sub update_subscription {
    my ($this, $new_data, $subscriberid, $docid) = @_;

    my $set=DBIx::Recordset->SetupObject( {'!DataSource'=>$this->{DB},
                                           '!Table'     =>'subscriptions',
                                           '!TieRow'    =>0,
                                          } );
    $set->Update($new_data, { subscriber => $subscriberid, docid => $docid });
    $set->Disconnect;

}

sub update_subscriptions {
    my ($this, $subscriber, $docids) = @_;

    my $set=DBIx::Recordset->SetupObject( {'!DataSource'=>$this->{DB},
					   '!Table'     =>'subscriptions',
                                           '!TieRow'    =>0,
					  } );
    $set->Delete( { subscriber=>$subscriber} );
    foreach (@$docids) {
	$set->Insert({docid=>$_, subscriber=>$subscriber});
    }
    $set->Disconnect;
}

sub get_subscription_emails {
    my ($this, $docid) = @_;
    my $set=DBIx::Recordset->SetupObject( {'!DataSource'=>$this->{DB},
                                           '!Table'     =>'subscriptions, subscribers',
                                           '!Fields' => 'email',
                                           '!TabRelation' => 'subscriptions.subscriber=subscribers.id',
                                           '!TieRow'    =>0,
                                          } );
    $set->Search({'docid' => $docid});
    my $rec;
    my @data;

    while($rec=$set->Next) {
        push(@data, $rec->{email});
    }

    $set->Disconnect;

    return \@data;
}

########################################################################
#
#	Methods for category-filtered subscription
#
########################################################################

sub add_subscriber_categories {
    my ($this, $subscriber, $categories)=@_;
    return 1 unless ($this->subscriber_categories_on());
    return 1 unless (ref($categories) eq 'ARRAY' and scalar(@$categories));

    my $set=DBIx::Recordset->SetupObject( {'!DataSource'=>$this->{DB},
					   '!Table'     =>'subscriber_categories',
                                           '!TieRow'    =>0,
					  } );

    foreach my $category (@$categories) {
        $set->Insert({subscriber=>$subscriber, category=>$category});
    }

    $set->Disconnect;
}

sub delete_subscriber_categories {
    my ($this, $subscriber)=@_;
    return 1 unless ($this->subscriber_categories_on());

    my $set=DBIx::Recordset->SetupObject( {'!DataSource'=>$this->{DB},
					   '!Table'     =>'subscriber_categories',
                                           '!TieRow'    =>0,
					  } );

    $set->Delete({subscriber=>$subscriber});

    $set->Disconnect;
}

sub update_subscriber_categories {
    my ($this, $subscriber, $new_categories)=@_;
    return 1 unless ($this->subscriber_categories_on());

    $this->delete_subscriber_categories($subscriber);
    $this->add_subscriber_categories($subscriber, $new_categories)
}

sub get_subscriber_categories {
    my ($this, $subscriber)=@_;
    return undef unless ($this->subscriber_categories_on());
    return undef unless (defined $subscriber);

    my $set=DBIx::Recordset->SetupObject( {'!DataSource'=>$this->{DB},
					   '!Table'     =>'subscriber_categories',
                                           '!TieRow'    =>0,
					  } );

    $set->Search({subscriber=>$subscriber});

    my @data;
    while(my $rec=$set->Next) {
        push(@data, $rec->{category});
    }

    $set->Disconnect;

    return \@data;
}

sub subscriber_categories_on {
    my ($this)=@_;

    return 1 if ($this->{DB}->AllTables->{'subscriber_categories'});
    return undef;
}

1;
__END__

=head1 NAME

Obvius::Subscriptions - subscription related functions for L<Obvius>.

=head1 SYNOPSIS

  use Obvius;
  use Obvius::Config;

  my $config = new Obvius::Config("configname");
  my $obvius = new Obvius($config);

  $obvius->get_subscriptions($where);

  my $href=$obvius->get_subscriber({ email=>'asjo@magenta-aps.dk' });

=head1 DESCRIPTION

This module contains subscription related functions for L<Obvius>.
It is not intended for use as a standalone module.

=head2 EXPORT

None.

=head1 AUTHORS

Jørgen Ulrik B. Krag, E<lt>jubk@magenta-aps.dkE<gt>
Peter Makholm E<lt>pma@fi.dkE<gt>
Adam Sjøgren, E<lt>asjo@magenta-aps.dkE<gt>

=head1 SEE ALSO

L<Obvius>.

=cut
