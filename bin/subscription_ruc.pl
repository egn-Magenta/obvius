#!/usr/bin/perl
# $Id$
use strict;
use warnings;

use lib '/home/httpd/obvius/perl_blib', '/usr/lib/perl/5.6.1', '/usr/lib/perl/5.6.0';

use Obvius;
use Obvius::Config;
use Obvius::Log;

use HTML::Mason::Parser;
use HTML::Mason::Interp;

use Net::SMTP;
use POSIX qw(strftime);

use Getopt::Long;
use Carp;

use locale;

use Data::Dumper;

my ($automatic, $manual, $site, $sender, $debug, $docid, $sitename, $institute) = (0,0,undef,undef,0, 0, undef, undef);

GetOptions('automatic'   => \$automatic,
           'manual'      => \$manual,
           'site=s'      => \$site,
           'sender=s'    => \$sender,
           'docid=i'     => \$docid,
           'debug'       => \$debug,
           'sitename=s'  => \$sitename,
           'institute=s'   => \$institute);

my $log = new Obvius::Log ($debug ? 'debug' : 'alert');

croak ("No site defined")
    unless (defined($site));

croak ("No sender defined")
    unless(defined($sender));

my $conf = new Obvius::Config($site);
#print Dumper($conf);
croak ("Could not get config for $site")
    unless(defined($conf));

my $obvius = new Obvius($conf,undef,undef,undef,undef,undef,log => $log); # Hmmmmm.
#print Dumper($obvius);
croak ("Could not get Obvius object for $site")
    unless(defined($obvius));

croak ("Must have a sitename") unless($sitename);
my $base_dir = '/home/httpd/'. $sitename;

my $institute_name = $institute || 'ruc';

## "Main" program part

do { send_automatic(); exit (0) } if ($automatic);

do { send_manual($docid); exit (0) } if ($manual);

print STDERR "No subscriptions sent\n";

exit(0);

sub send_manual {
    my $docid = shift;

    my $doc = $obvius->get_doc_by_id($docid);
    die "No doc with id $docid\n" unless($doc);

    my $vdoc = $obvius->get_public_version($doc);
    die "No public version for the chosen document\n" unless($vdoc);

    $obvius->get_version_fields($vdoc, [ 'subscribeable', 'title' ]);
    die "Document not subscribeable\n" unless($vdoc->Subscribeable and $vdoc->Subscribeable eq 'manual');

    my $mailtemplate = '/' . $docid . '.txt';

    my $new_docs =  get_subdocs_recursive($vdoc) || [];

    my $subscriptions = $obvius->get_subscriptions({ docid => $docid });

    my $now = strftime('%Y-%m-%d %H:%M:%S', localtime);
    my $seven_days_ago = strftime('%Y-%m-%d %H:%M:%S', localtime(time() - 24*60*60*7));


    for my $s (@$subscriptions) {
        my $last_update = $s->{last_update};
        $last_update = $seven_days_ago if ($last_update eq '0000-00-00 00:00:00');
        my @docs_2_send = grep { $last_update lt $_->{published} } @$new_docs;
        if(scalar(@docs_2_send)) {

            # Hmmm, DBIx::RecordSet thinks you are trying to update the DB
            # when you modify the subscriber object, so we clone it.
            #
            # This is a know bug, it's been fixed in a revision of the
            # Debian packages, but upstream hasn't released a new
            # version.
            # See <http://bugs.debian.org/cgi-bin/bugreport.cgi?bug=133165>
            #
            # A workaround (explicitly setting !TieRow to 0) has been
            # added to Obvius.pm.
            # See <>

            my $subscriber_ = $obvius->get_subscriber({id => $s->{subscriber}});
            my $subscriber = {};
            for(keys %$subscriber_) {
                $subscriber->{$_} = $subscriber_->{$_};
            }
            next if ($subscriber->{suspended});

            $subscriber->{subscriptions} = [ {
                                                title => $vdoc->Title,
                                                docs => \@docs_2_send,
                                                url=>$obvius->get_doc_uri($obvius->get_doc_by_id($vdoc->DocId)),
                                                docid => $vdoc->DocId
                                             } ];

            my $mail_error = send_mail($sender, $subscriber, $mailtemplate);

            if($mail_error) {
                print STDERR "Warning: Mail system failure: $mail_error";
            } else {
                unless($debug) {
                    $obvius->update_subscription({ last_update => $now}, $s->{subscriber}, $docid);
                }
            }
        }
    }
}


sub send_automatic ($institute_name) {
    my @subscribers_2_send;

    # Make a timestamp now so subscribers wont miss documents published while
    # the subscription system is running.
    #
    my $now = strftime('%Y-%m-%d %H:%M:%S', localtime);

    # Yesterday - For subscriptions with an all-zero last_update
    my $yesterday = strftime('%Y-%m-%d %H:%M:%S', localtime(time() - 24*60*60));


    # Start with building a hash of subscribeable docs indexed by ID
    #
    # Each element in the hash will have a Subdocs field containing a list
    # of all subdocs under the current document, that is to be sent out (found
    # recursively).
    #
    #my $subscribeable_docs = $obvius->search( [ 'subscribeable', 'title' ], 'subscribeable = \'automatic\'', notexpired=>1, public=>1);
    my $sec_doc = $obvius->lookup_document("/$institute_name/");
    my $subscribeable_docs = $obvius->search( [ 'subscribeable', 'title', 'sec' ],
                                              'subscribeable = \'automatic\' and sec = ' . $sec_doc->Id, notexpired=>1,
                                              public=>1);

    my %docs_by_id;

    if($subscribeable_docs) {
        for(@$subscribeable_docs) {
            my $subdocs = get_subdocs_recursive($_, $obvius);
            $_->param('subdocs' => $subdocs);
            $docs_by_id{$_->DocId} = $_;
            print STDERR Dumper($_) if($debug);
        }
    }


    # Get all subscribers from the database
    my $subscribers = $obvius->get_all_subscribers;


    # Make a 3 level datastructure:
    #
    # subscribers
    #   their subscriptions
    #     documents that will be sent
    #
    for(@$subscribers) {
	next if ($_->{suspended});
        my $subscriber_categories=$obvius->get_subscriber_categories($_->{id});
        my %subscriber_categories=map { ($_=>1) } @{$_->{categories}} if ($subscriber_categories);

        my @subscriptions_2_send;

        my $subscriptions = $obvius->get_subscriptions({ subscriber => $_->{id} });
        foreach my $s_ (@$subscriptions) {

            # Hmmm, DBIx::RecordSet thinks you are trying to update the DB
            # when you modify the subscriptions object, so we clone it.
            # Note: See above.
            my $s = {};
            for(keys %$s_) {
                $s->{$_} = $s_->{$_};
            }


            if($s->{last_update} eq '0000-00-00 00:00:00') {
                $s->{last_update} = $yesterday;
            }

            my @docs_2_send;
            my $subdocs;

            my $vdoc = $docs_by_id{$s->{docid}};

            $subdocs = $vdoc->Subdocs if($vdoc);
            $subdocs = [] unless($subdocs);

            @docs_2_send = grep { $s->{last_update} lt $_->{published} } @$subdocs;

            if($vdoc and @docs_2_send) {
                push(@subscriptions_2_send, {
                                            'subscriberid' => $_->{id},
                                            'docid' => $s->{docid},
                                            'title' => $vdoc->Title,
                                            'url' => $obvius->get_doc_uri($obvius->get_doc_by_id($vdoc->DocId)),
                                            'docs' => \@docs_2_send
                                        });
            }
        }

        if(@subscriptions_2_send) {
            push(@subscribers_2_send, {
                                    'name' => $_->{name},
                                    'passwd' => $_->{passwd},
                                    'email' => $_->{email},
                                    'subscriptions' => \@subscriptions_2_send,
                                    'institute' => $institute_name,
                                });
        }
    }

    # For each subscriber, send their mail and update last_update fields
    # in the subscriptions table;
    foreach my $subscriber (@subscribers_2_send) {
        my $mail_error = send_mail($sender, $subscriber);
        if($mail_error) {
            print STDERR "Warning: Mail system failure: $mail_error";
        } else {
            unless($debug) {
                my $s_list = $subscriber->{subscriptions};
                for(@$s_list) {
                    $obvius->update_subscription({ last_update => $now}, $_->{subscriberid}, $_->{docid});
                }
            }
        }
    }
}

my $in_subscription_cache;

sub get_in_subscription_docs {

    return $in_subscription_cache if($in_subscription_cache);
    my %in_subscription_docs;

    my $docs = $obvius->search(
                                ['in_subscription'],
                                "in_subscription = 1",
                                public => 1
                            ) || [];
    for(@$docs) {
        $in_subscription_docs{$_->DocId} = $_;
    }

    $in_subscription_cache = \%in_subscription_docs;

    return \%in_subscription_docs;
}

sub get_subdocs_recursive {
    my ($vdoc) = @_;

    my $doctype = $obvius->get_doctype_by_id($vdoc->Type);

    if($doctype->Name eq 'KeywordSearch' or $doctype->Name eq 'ComboSearch') {
        return get_docs_by_search($vdoc);
    }

    my $in_subscription_hash = get_in_subscription_docs();

    my @worklist;
    my @result;
    push(@worklist, $obvius->get_doc_by_id($vdoc->DocId));

    while (my $doc = shift @worklist) {
        my $subdocs = $obvius->get_docs_by(parent => $doc->Id);
        if($subdocs) {
            unshift(@worklist, @$subdocs);
        }

        if($in_subscription_hash->{$doc->Id}) {
            my $vdoc = $obvius->get_public_version($doc);

            $obvius->get_version_fields($vdoc, [ 'published', 'in_subscription' ], 'PUBLISH_FIELDS');
            $obvius->get_version_fields($vdoc, [ 'title', 'teaser' ]);

            push(@result, {
                            published => $vdoc->{PUBLISH_FIELDS}->{PUBLISHED},
                            title => $vdoc->Title,
                            teaser => $vdoc->field('teaser'),
                            url => $obvius->get_doc_uri($obvius->get_doc_by_id($vdoc->DocId)),
                            vdoc => $vdoc
                        }
                    ) if($vdoc->{PUBLISH_FIELDS}->{IN_SUBSCRIPTION} and $vdoc->{PUBLISH_FIELDS}->{PUBLISHED});
        }
    }

    return \@result;
}

sub get_docs_by_search {
    my ($vdoc) = @_;
    my $doctype = $obvius->get_doctype_by_id($vdoc->Type);

    my $doc = $obvius->get_doc_by_id($vdoc->DocId);

    my $input = new Obvius::Data;
    my $output = new Obvius::Data;

    $obvius->get_version_fields($vdoc, 256);

    $obvius->get_version_fields($vdoc, 256);

    # Hack pagesize
    $vdoc->{FIELDS}->{PAGESIZE} = 0;

    $doctype->action($input, $output, $doc, $vdoc, $obvius);

    my $vdocs = $output->param('kwdocs') || [];

    my @result;

    for my $vdoc (@$vdocs) {
        $obvius->get_version_fields($vdoc, [ 'title', 'teaser', 'docdate' ]);

        push(@result, {
                        # Cheat and use docdate for "published" - this way we don't risk
                        # subscribers getting new messages just because somebody corredted
                        # a spelling error.
                        published => $vdoc->field('docdate'),
                        title => $vdoc->Title,
                        teaser => $vdoc->field('teaser'),
                        url => $obvius->get_doc_uri($obvius->get_doc_by_id($vdoc->DocId)),
                        vdoc => $vdoc
                    }
                );
    }

    return \@result;
}

sub send_mail {
    my ($from, $subscriber, $mailtemplate) = @_;


    my $mailmsg;
    my $mail_error;
    my $mailto = $subscriber->{email};

    my $parser = new HTML::Mason::Parser;
    my $interp = new HTML::Mason::Interp(
                                        parser => $parser,
                                        comp_root => $base_dir . '/mason/mail/',
                                        data_dir => $base_dir . '/var/mail/',
                                        out_method => \$mailmsg
                                    );
    $mailtemplate = '/automatic' unless($mailtemplate and -f $base_dir . '/mason/mail' . $mailtemplate);
    my $retval = $interp->exec($mailtemplate, obvius => $obvius, subscriber => $subscriber, mailfrom => $sender, hostname=>$sitename);

    if($debug) {
        print STDERR "Not sending this mail (because of DEBUG): \n";
        print STDERR $mailmsg ."\n";
    } else {

        if($retval) {
            print STDERR "Warning: failed to create mail message\n";
        } else {
            my $smtp = Net::SMTP->new('localhost', Timeout=>30, Debug => $debug);
            $mail_error = "Failed to specify a sender [$from]\n"        unless ($smtp->mail($from));
            $mail_error = "Failed to specify a recipient [$mailto]\n"   unless ($mail_error or $smtp->to($mailto));
            $mail_error = "Failed to send a message\n"                  unless ($mail_error or $smtp->data([$mailmsg]));
            $mail_error = "Failed to quit\n"                            unless ($mail_error or $smtp->quit);
        }
    }

    return $mail_error;
}