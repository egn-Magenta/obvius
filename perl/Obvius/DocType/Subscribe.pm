package Obvius::DocType::Subscribe;

# $Id$

use strict;
use warnings;

use Obvius;
use Obvius::DocType;

use Digest::MD5 qw(md5_hex md5_base64);

our @ISA = qw( Obvius::DocType );
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub action {
    my ($this, $input, $output, $doc, $vdoc, $obvius) = @_;

    $this->tracer($input, $output, $doc, $vdoc, $obvius) if ($this->{DEBUG});

    $obvius->get_version_fields($vdoc, ['passwdmsg', 'mailfrom']);

    my $mailmsg = $vdoc->PasswdMsg;
    my $mailfrom = $vdoc->MailFrom;

    unless($mailmsg and $mailfrom) {
        $obvius->log->error("Password template or mail-from missing in Obvius::DocType::Subscribe");
        return OBVIUS_ERROR;
    }

    #Modes : 1 if login protected else 0
    my $modes = { choose => 1,
                  choose_submit => 1,
                  edit_subscriber => 1,
                  edit_subscriber_submit => 1,
                  login => 1,
                  send_password => 0,
                  new_subscriber => 0,
                  new_subscriber_submit => 0,
                  delete_subscriber => 1,
	          activate => 0 };

    #Default to login mode
    my $mode = $input->param('mode') || 'new_subscriber';
    $mode = 'login' unless(defined($modes->{$mode}));

    # new_subscriber is the only mode that doesn't have side effects. Ignore this
    $output->param(Obvius_SIDE_EFFECTS => 1);
    $output->param(Obvius_DEPENCIES => 1);

    my $subscriber;
    my $email;

    if($modes->{$mode} > 0) { #if login protected
        my $cookies = $input->Obvius_COOKIES;
        my $subscriber_id = $cookies->{Obvius_SUBSCRIPTION_ID};

        if($subscriber_id) {
            $subscriber = $obvius->get_subscriber({cookie => $subscriber_id});
            if($subscriber) {
                # skip login if we got a valid cookie
                $mode = 'choose' if($mode eq 'login');
            } else {
                # No subscriber for the given cookie.. login again
                $mode = 'login';
            }
        } else {
            # No cookie given.. Do a login
            $mode = 'login';
        }
    }

    if($mode eq 'login') {
        $email = $input->param('email');
        my $password = $input->param('password');
        if($email and $email =~ /^.+\@[a-z0-9\-\.]+\.[a-z]{2,4}$/i) {
            if($password) {
                $subscriber = $obvius->get_subscriber( { email => $email, passwd => $password } );
                if($subscriber) {
                    #login successfull, set a cookie, and go on to choosing
                    #OBS! The cookie is set in the choose mode
                    $mode = 'choose';
                } else {
                    $output->param(login_failed=>1);
		    unless ($obvius->get_subscriber( { email=>$email } )) {
			$output->param(subscriber_not_found=>1);
		    }
                }
            } else {
                $mode = 'send_password';
            }
        } else {
            $output->param(error_email=>1) if($email); # Only output if there actually is an email-address
        }
    }


    if ($mode eq 'activate') {
	# We would like the URL's to fit in 72 chars hence the short alternative parameters
	my $email = $input->param('email') || $input->param('e');
	my $passwd = $input->param('password') || $input->param('p');

	my $subscriber = $obvius->get_subscriber( {email => $email, passwd => $passwd} );
	if ($subscriber) {
	    $subscriber->{suspended} = 0;
	    $obvius->update_subscriber($subscriber,email=>$email);
	} else {
	    $output->param(activate_failed=>1);
	}
    }

    if($mode eq 'choose') {
        return OBVIUS_ERROR unless($subscriber);

        # Add one should be 'carried on' until it gets here.
        my $add_one = $input->param('add_one');
        if($add_one) {
            $mode = 'add_one';
            my $exists = $obvius->get_subscriptions( { subscriber => $subscriber->{id},  docid => $add_one} );
            if($exists and scalar(@$exists)) {
                $output->param(subscription_exists => 1);
            } else {
                my $add_doc = $obvius->get_doc_by_id($add_one);
                my $add_vdoc;
                $add_vdoc = $obvius->get_public_version($add_doc) if($add_doc);
                if($add_vdoc) {
                    $obvius->get_version_fields($add_vdoc, [ 'title', 'subscribeable' ]);
                    if($add_vdoc->Subscribeable and $add_vdoc->Subscribeable ne 'none') {
                        $output->param('add_title' => $add_vdoc->Title);
                        $obvius->add_subscription( { docid => $add_one, subscriber => $subscriber->{id}, last_update => 0 } );
                    } else {
                        $output->param(subscribe_error => 'Det valgte dokument er ikke abonnerbart');
                    }
                } else {
                    $output->param(subscribe_error => 'Dokumentet med id \'' . $add_one . '\' eksisterer ikke eller er ikke offentligt');
                }

            }
        } else {
            # asjo 20020206: Added parens:
            my $subscriber_docs = $obvius->search( ['subscribeable', 'title'], '(subscribeable = \'automatic\' OR subscribeable = \'manual\')',
                                                    notexpired=>1, public=>1, sortvdoc => $vdoc);

            my $user_subscriptions = $obvius->get_subscriptions( { subscriber => $subscriber->{id} } );

            #build list of subscribable docs
            my @subscribe_list;
            foreach $doc (@$subscriber_docs) {
                my $data = {};
                $data->{id} = $doc->{DOCID};
                $data->{selected} = 1 if(grep { $doc->{DOCID} == $_->{docid}} @$user_subscriptions);
                $data->{title} = $doc->{TITLE};

                my $doc_object = $obvius->get_doc_by_id($doc->{DOCID});
                my $url = $obvius->get_doc_uri($doc_object);

                my $section = $url =~ /^\/([^\/]*)/ ? $1 : 'dummy';
                $data->{section} = lc($section);

                push(@subscribe_list, $data);
            }
            my $sort_map = $this->get_section_hash($obvius);

            # Sort according to above hash. Anything that is not listed in the hash will get the
            # sort-value 1000000, which equals being put at the bottom.
            # If the seq-nr comparison returns 0, eg. the values are the same do a comparison of
            # the section names instead.
            @subscribe_list = sort {
                                        my $tmpval = ($sort_map -> { $a->{section} } || 1000000) <=> ($sort_map -> { $b->{section} } || 1000000);
                                        ($tmpval == 0 ? $a->{section} cmp $b->{section} : $tmpval);
                                } @subscribe_list;

            # If we have a new section, uppercase the first char and put on the object

            my $current_section = '';
            for(@subscribe_list) {
                if($current_section ne lc($_->{section})) {
                    $current_section = lc($_->{section});
                    $_->{section} = ucfirst($_->{section});
                    $_->{new_section} = $_->{section};
                }
            }
            $output->param(subscribe_list => \@subscribe_list);
            provide_categories_if_necessary($obvius, $output, subscriber=>$subscriber);
        }
        # Give 'em a new cookie
        my $cookie = md5_hex($input->THE_REQUEST . $input->REMOTE_IP . $input->Now);
        $obvius->set_subscriber_cookie($subscriber->{email}, $cookie);
        $output->param('Obvius_COOKIES' => { 'Obvius_SUBSCRIPTION_ID' => { value => $cookie, expires => '+15m' } });
    } elsif($mode eq 'choose_submit') {
        return OBVIUS_ERROR unless($subscriber);

        my $chosen = $input->param('subscription');
        $chosen = [ $chosen ] unless(ref($chosen) eq 'ARRAY');
        #Make sure we have an empty array and not an array with a single undef in it
        pop(@$chosen) unless(defined(@$chosen[0]));
        my $user_subscriptions = $obvius->get_subscriptions( { subscriber => $subscriber->{id} } );

        my $chosen_categories=$input->param('categories') || [];
        $chosen_categories=[$chosen_categories] if ($chosen_categories and ref($chosen_categories) ne 'ARRAY');

        # Build a hash where each key is a docid and its value will be 2 if it is
        # in both $chosen and $user_subscriptions
        my %exists;
        for(@$chosen) {
            $exists{$_}++;
        }
        for(@$user_subscriptions) {
            $exists{$_->{docid}}++;
        }

        # New - all ids that are in chosen and not in user_subscriptions (exists < 2)
        my @new = grep { $exists{$_} < 2 } @$chosen;

        # Delete - all ids that are in user_subscriptions and not in chosen (exists < 2)
        my @delete = map { $_->{docid} } grep { $exists{$_->{docid}} < 2 } @$user_subscriptions;

        for(@new) {
            $obvius->add_subscription( { docid => $_, subscriber => $subscriber->{id}, last_update => 0 } );
        }
        for(@delete) {
            $obvius->remove_subscription($_, $subscriber->{id});
        }

        $obvius->update_subscriber_categories($subscriber->{id}, $chosen_categories);

        # Give 'em a new cookie
        my $cookie = md5_hex($input->THE_REQUEST . $input->REMOTE_IP . $input->Now);
        $obvius->set_subscriber_cookie($subscriber->{email}, $cookie);
        $output->param('Obvius_COOKIES' => { 'Obvius_SUBSCRIPTION_ID' => { value => $cookie, expires => '+15m' } });

    } elsif ($mode eq 'send_password') {
        $email = $email ? $email : $input->param('email');
        unless($email) {
            $obvius->log->debug("Missing email while sending subscriber password");
            return OBVIUS_ERROR;
        }
        $output->param(mailmsg => $mailmsg);
        $output->param(sender => $mailfrom);
        $subscriber = $obvius->get_subscriber( { email => $email } );
        if($subscriber) {
            $output->param( password => $subscriber->{passwd});
        } else {
            $output->param( error_no_subscriber => 1);
        }

    } elsif($mode eq 'new_subscriber') {

	my $subscriber_docs = $obvius->search( ['subscribeable', 'title'], '(subscribeable = \'automatic\' OR subscribeable = \'manual\')',
                                                    notexpired=>1, public=>1, sortvdoc => $vdoc);

	#build list of subscribable docs
	my @subscribe_list;
	foreach $doc (@$subscriber_docs) {
	    my $data = {};
	    $data->{id} = $doc->{DOCID};
	    $data->{title} = $doc->{TITLE};

	    my $doc_object = $obvius->get_doc_by_id($doc->{DOCID});
	    my $url = $obvius->get_doc_uri($doc_object);

	    my $section = $url =~ /^\/([^\/]*)/ ? $1 : 'dummy';
	    $data->{section} = lc($section);

	    push(@subscribe_list, $data);
	}
	my $sort_map = $this->get_section_hash($obvius);

	# Sort according to above hash. Anything that is not listed in the hash will get the
	# sort-value 1000000, which equals being put at the bottom.
	@subscribe_list = sort {
                                    my $tmpval = ($sort_map -> { $a->{section} } || 1000000) <=> ($sort_map -> { $b->{section} } || 1000000);
                                    ($tmpval == 0 ? $a->{section} cmp $b->{section} : $tmpval);
                                } @subscribe_list;

	@subscribe_list = grep { $obvius->is_public_document($obvius->get_doc_by_id($_->{id})) } @subscribe_list;

	$output->param(subscribe_list => \@subscribe_list);
        provide_categories_if_necessary($obvius, $output);
    }
    elsif($mode eq 'new_subscriber_submit') {
        my @errors= ();
        my $new_email = $input->param('new_email');
        my $name = $input->param('name');

        my $chosen = $input->param('subscription');
        $chosen = [ $chosen ] unless(ref($chosen) eq 'ARRAY');
        #Make sure we have an empty array and not an array with a single undef in it
        pop(@$chosen) unless(defined(@$chosen[0]));

        my $chosen_categories=$input->param('categories') || [];
        $chosen_categories=[$chosen_categories] if ($chosen_categories and ref($chosen_categories) ne 'ARRAY');

        push(@errors, { error => 'Emailadressen er ikke korrekt formateret' } )
            unless ($new_email =~ /^.+\@[a-z0-9\-\.]+\.[a-z]{2,4}$/i);
        push(@errors, { error => 'Du skal angive både for og efternavn'} )
            unless ($name =~ /^[^\s]+\s+[^\s]+/);
        unless(@errors) {
            push(@errors, { error => 'Denne emailadresse er allerede registreret i abonnementsystemet' } )
                if($obvius->get_subscriber( { email => $new_email} ));
        }

        if(@errors) {
            $output->param(errors => \@errors);
        } else {
            my @chars = (0..9, 'A'..'Z', 'a'..'z');
            my $passwd = $input->param('passwd');
            unless($passwd) { $passwd .= $chars[rand scalar(@chars)] for (1..8); }
            $obvius->add_subscriber({email => $new_email, name => $name, passwd => $passwd, suspended => 1}, categories=>$chosen_categories);
	    my $subscriber = $obvius->get_subscriber( { email => $new_email} );
	    $obvius->add_subscription( { docid => $_, subscriber => $subscriber->{id}, last_update => 0 } ) foreach (@$chosen);
            $output->param('password' => $passwd);
            $output->param('sender' => $mailfrom);
            $output->param('mailmsg' => 'mail/new_subscriber'); # ACHTUNG!!
	    $output->param('mailcookie' => md5_base64($new_email, $name, $passwd));
            $email = $new_email;  # Email is exported at the end of the function
        }
    } elsif($mode eq 'edit_subscriber') {
        return OBVIUS_ERROR unless($subscriber);

        $email = $subscriber->{email}; # Email is exported at the end of the function
        $output->param(company => $subscriber->{company});
        $output->param(name => $subscriber->{name});
    } elsif ($mode eq 'edit_subscriber_submit') {
        return OBVIUS_ERROR unless($subscriber);

        my @errors = ();

        my $name = $input->param('name');
        my $company = $input->param('company');
        my $passwd1 = $input->param('passwd1');
        my $passwd2 = $input->param('passwd2');
        my $password_changed = 0;

        push(@errors, { error => 'Ukorrekt navn. Du skal angive både for og efternavn'} )
            unless ($name =~ /^[\wæøå]+\s+[\wæøå]+/);
        if($passwd1) {
            if($passwd1 ne $passwd2) {
                push(@errors, { error => 'De to passwords skal være ens' } );
            } else {
                $password_changed = 1;
            }
        }

        if(@errors) {
            $output->param(errors => \@errors);
        } else {
            $obvius->update_subscriber( { company => $company,
                                        name => $name,
                                        passwd => $passwd1 ? $passwd1 : $subscriber->{passwd}
                                    },
                                    email=>$subscriber->{email});
            if($password_changed) {
                $output->param(password_changed => 1);
                $output->param('password' => $passwd1);
                $output->param('sender' => $mailfrom);
                $output->param('mailmsg' => $mailmsg);
                $email = $subscriber->{email};
            }
        }

        # Give 'em a new cookie
        my $cookie = md5_hex($input->THE_REQUEST . $input->REMOTE_IP . $input->Now);
        $obvius->set_subscriber_cookie($subscriber->{email}, $cookie);
        $output->param('Obvius_COOKIES' => { 'Obvius_SUBSCRIPTION_ID' => { value => $cookie, expires => '+15m' } });
    } elsif ($mode eq 'delete_subscriber') {
        $email = $subscriber->{email};
        if($input->param('confirm')) {
            $obvius->delete_subscriber($subscriber->{id});
            $output->param('deleted' => 1);
        }
    }


    #Carry on add_* parameters
    $output->param(add_one => $input->param('add_one')) if($input->param('add_one'));
    $output->param(add_one_url => $input->param('add_one_url')) if($input->param('add_one_url'));


    $email = '' unless(defined($email));

    $output->param(email => $email);
    $output->param(mode => $mode);

    return OBVIUS_OK;
}


sub get_section_hash {
    my ($this, $obvius) = @_;
    my %hash;

    my $results = $obvius->search(['seq'], "parent = 1",
                                                    public => 1,
                                                    needs_document_fields => ['parent', 'name']
                            ) || [];
    for(@$results) {
        my $seq = $_->Seq;
        $seq = $seq < 0 ? 1000000 : $seq;
        $hash{lc($_->Name)} = $seq;
    }
    return \%hash;
}


# provide_categories_if_necessary($obvius, $output) - checks whether the
# database has the table subscriber_categories, indicating that the
# subscription system should filter on selected categories, and if
# it's there, puts the categories on the output object for the
# template-system to use.

sub provide_categories_if_necessary {
    my ($obvius, $output, %options)=@_;

    my $db=$obvius->{DB};
    my $alltables=$db->AllTables;
    if ($alltables->{subscriber_categories}) {
        my @categories=sort{$a->{id} cmp $b->{id}} @{$obvius->get_table_data('categories') || []};

        my %selected=();
        if ($options{subscriber}) {
            map { $selected{$_}=1 }
                @{$obvius->get_subscriber_categories($options{subscriber}->{id}) || []};
            map { $_->{selected}=1 if ($selected{$_->{id}}); } @categories;
        }

        $output->param('subscriber_categories'=>\@categories) if (@categories);
        return \@categories;
    }
    else {
        return undef;
    }
}

1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Obvius::DocType::Subscribe - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Obvius::DocType::Subscribe;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Obvius::DocType::Subscribe, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head2 EXPORT

None by default.


=head1 AUTHOR

A. U. Thor, E<lt>a.u.thor@a.galaxy.far.far.awayE<gt>

=head1 SEE ALSO

L<perl>.

=cut
