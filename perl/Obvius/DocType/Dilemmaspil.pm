package Obvius::DocType::Dilemmaspil;

########################################################################
#
# Dilemmaspil.pm - A game of questions and reasons
#
# Copyright (C) 2002 aparte, Denmark (http://www.aparte.dk/)
#
# Author: Jørgen Ulrik Balslev Krag <jubk@magenta-aps.dk>
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

use Obvius;
use Obvius::DocType;

use Digest::MD5 qw(md5_hex);

use Data::Dumper;

our @ISA = qw( Obvius::DocType );
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;


# XXX Warning: This doctype depends on code from the CreateDocument doctype

sub action {
    my ($this, $input, $output, $doc, $vdoc, $obvius) = @_;

    # Handle session (pager) stuff
    $output->param(Obvius_SIDE_EFFECTS => 1);
    my $session = $input->param('SESSION');
    if($session and $session->{docs} and @{$session->{docs}}) {
        if ($session->{pagesize}) {
            my $page = $input->param('p') || 1;
            $this->export_paged_doclist($session->{pagesize}, $session->{docs}, $output, $obvius,
                                            name=>'args', page=>$page,
                                            require=>'content',
                                        );
        } else {
            $this->export_doclist($session->{docs},  $output, $obvius,
                                    name=>'args',
                                    require=>'content',
                                );
        }
        #make sure we keep this session
        $output->param('SESSION' => undef);
        #make sure we have a session_id
        $output->param('SESSION_ID' => $session->{_session_id});
        #make sure the docs are shown...
        $output->param(mode => 'showargs');
        $output->param(votetype => $session->{votetype});

        return OBVIUS_OK;
    }

    my $mode = $input->param('mode');
    my $is_admin = $input->param('IS_ADMIN');
    $output->param(is_admin => $is_admin) if($is_admin);

    # Check if the user have already voted
    my $voter_id;
    unless ($is_admin) {
        my $cookies = $input->param('Obvius_COOKIES');
        $voter_id = $cookies->{Obvius_VOTER_ID};
        unless ($voter_id) {
            $voter_id = md5_hex($input->param('THE_REQUEST') . $input->param('REMOTE_IP') . $input->param('Now'));
            $output->param('Obvius_COOKIES' => { 'Obvius_VOTER_ID' => {
                                                        value => $voter_id,
                                                        expires => '+1y',
                                                    }
                                                });
        }
    }
    if ((!$mode or $mode eq 'modargs' or $mode eq 'vote')
        and $voter_id and $obvius->voter_is_registered($voter_id, $doc->ID))
    {
        if($input->param('no_redirect')) {
            $mode = 'view';
            $output->param('has_voted' => 1);
        } else {
            # Try to find another dilemmaspil and redirect to it.
            my $parentid = $doc->Parent;
            $output->param(Obvius_DEPENDENCIES => 1);
            my $possible_docs = $obvius->search(['seq'],
                                                "parent = $parentid AND type = " . $this->Id,
                                                public => 1,
                                                notexpired => 1,
                                                needs_document_fields => ['parent'],
                                                order => 'seq',
                                            ) || [];

            # Get all possible docs not in $has_voted_docs
            my $has_voted_docs = $obvius->get_votedoc_ids_by_cookie($voter_id) || [];
            my @possible_docs = grep {
                                        my $docid = $_->DocId;
                                        ! grep { $docid == $_ } @$has_voted_docs
                                    } @$possible_docs;

            # Try to find the next document på seq
            my $seq = $obvius->get_version_field($vdoc, 'seq');
            my @seq_limited_docs = grep { $_->Seq > $seq } @possible_docs;

            # Get a doc if we have any, preferring the one found by seq.
            my $next = shift(@seq_limited_docs) || shift(@possible_docs);

            if($next) {
                my $d = $obvius->get_doc_by_id($next->DocId);
                my $next_path = $obvius->get_doc_uri($d) . "?bare=1";
                print STDERR "Redirecting to: $next_path\n";
                $output->param('Obvius_REDIRECT' => $next_path);
                return OBVIUS_OK;
            } else {
                $mode='all_votes';
            }
        }
    }

    return OBVIUS_OK unless($mode);


    my $create_doctype = $obvius->get_doctype_by_name('CreateDocument');
    my $create_doctype_id = $create_doctype->Id;

    my $reason_doctype = $obvius->get_doctype_by_name('Reason');
    my $reason_doctype_id = $reason_doctype->Id;

    my $vote = $input->param('vote');

    # XXX exporting mode both here and at the end of the function
    $output->param(mode => $mode);

    if($mode eq 'modarg') {
        unless(defined($vote)) {
            print STDERR "No vote in Dilemmaspil, modarg mode\n";
            $output->param(mode => 'view');
            return OBVIUS_OK;
        }

        my $yes_no = $vote ? 0 : 1;

        my %search_options=(
                            needs_document_fields => [ 'parent' ],
                            sortvdoc => $vdoc,
                            notexpired=>!$is_admin,
                            public=>!$is_admin,
                            order => 'published DESC',
                            append => 'LIMIT 3',
                        );

        $output->param(Obvius_DEPENDENCIES => 1);
        my $args = $obvius->search(
                                    [ 'title', 'reason', 'gender', 'age', 'occupation', 'yes_no', 'published' ],
                                    "parent = " . $doc->Id . " AND type = $reason_doctype_id AND yes_no = $yes_no",
                                    %search_options
                                );
        $args = [] unless($args);
        my @modargs;
        for(@$args) {
            my $occupation = $_->Occupation;
            my $char1 = uc(substr($occupation,0,1));
            $occupation =~ s/^(.)/$char1/;
            push(@modargs, {
                                title => $_->Title,
                                reason => $_->Reason,
                                gender => $_->Gender,
                                age => $_->Age,
                                occupation => $occupation,
                            });
        }

        $output->param(modargs => \@modargs);
        if($vote) {
            $obvius->get_version_fields($vdoc, ['yes_top', 'yes_bottom']);
            $output->param(top => $vdoc->Yes_Top);
            $output->param(bottom => $vdoc->Yes_Bottom);
        } else {
            $obvius->get_version_fields($vdoc, ['no_top', 'no_bottom']);
            $output->param(top => $vdoc->No_Top);
            $output->param(bottom => $vdoc->No_Bottom);
        }
    } elsif($mode eq 'vote') {
        my $vote = $input->param('vote');
        unless(defined($vote)) {
            print STDERR "No vote in Dilemmaspil, vote mode\n";
            $output->param(mode => 'view');
            return OBVIUS_OK;
        }

        # Make sure vote is either 0 or 1
        $vote = $vote ? 1 : 0;

        if ($voter_id) {
            $obvius->register_voter($doc->ID, $voter_id);
            $obvius->register_vote($doc->ID, $vote);
        }

        my $answers = { 0 => 'Nej', 1 => 'Ja'};
        my $total = 0;
        my $max   = 0;
        my $votes = $obvius->get_votes($doc->ID);

        my $answer_table = [
                            map {
                                    ({
                                        id => $_,
                                        answer => $answers->{$_},
                                        count => $votes->{$_} || 0,
                                    })
                                } qw(1 0)
                            ];

        $total += $_->{count} for (@{$answer_table});
        $output->param(total => $total);
        map { $max = $_->{count} if $max < $_->{count} } @{$answer_table};
        $output->param(max => $max);

        my $bar_width=$vdoc->Bar_Width ? $vdoc->Bar_Width : 200; # Default

        for (@{$answer_table}) {
            if ($total > 0) {
                $_->{pct} = int(100.0 * $_->{count} / $total + 0.5);
                $_->{rel} = int($bar_width * ($_->{count} / $max)); # $total>0 => $max>0
            } else {
                $_->{pct} = 0;
                $_->{rel} = 0;
            }
            $_->{total} = $total;
        }

        $output->param(answers => $answer_table);
    } elsif($mode eq 'reason') {
        #$output->param(create_doc => $create_doc_path);
    } elsif($mode eq 'reason_create') {
        # XXX using code from other doctype here XXX
        my %create_options = (
                                doctype => $reason_doctype,
                                parent_doc => $doc,
                                fields => { seq => '-1.0' }
                            );
        $create_doctype->action($input, $output, $doc, $vdoc, $obvius, %create_options);
    } elsif($mode eq 'showargs') {
        my %search_options=(
                            needs_document_fields => [ 'parent' ],
                            sortvdoc => $vdoc,
                            notexpired=>!$is_admin,
                            public=>!$is_admin,
                            order => 'published DESC',
                        );

        my $votetype = $input->param('votetype');
        unless(defined($votetype)) {
            $output->param(Obvius_DEPENDENCIES => 1);
            my $yes = $obvius->search(
                                                [ 'yes_no', 'published' ],
                                                "parent = " . $doc->Id . " AND type = $reason_doctype_id AND yes_no = 1",
                                                %search_options
                                            );
            $yes = $yes ? scalar(@$yes) : 0;
            my $no = $obvius->search(
                                                [ 'yes_no', 'published' ],
                                                "parent = " . $doc->Id . " AND type = $reason_doctype_id AND yes_no = 0",
                                                %search_options
                                            );
            $no = $no ? scalar(@$no) : 0;

            $output->param(yes_args => $yes);
            $output->param(no_args => $no);
            $output->param(total_args => $yes + $no);

            return OBVIUS_OK;
        }

        $output->param(votetype => $votetype);

        #OK, now start out with an empty session
        $session = {};

        $votetype = $votetype ? 1 : 0; # Convert to number

        $session->{votetype} = $votetype;

        $output->param(Obvius_DEPENDENCIES => 1);
        $session->{docs} = $obvius->search(
                                            [ 'yes_no', 'published' ],
                                            "parent = " . $doc->Id . " AND type = $reason_doctype_id AND yes_no = $votetype",
                                            %search_options
                                        );
        $session->{docs} = [] unless($session->{docs});

        #Convert first char in occupation
        for(@{$session->{docs}}) {
            my $occupation = $_->Occupation;
            my $char1 = uc(substr($occupation,0,1));
            $occupation =~ s/^(.)/$char1/;
            $_->param(occupation => $occupation);
        }

        $session->{pagesize} = $obvius->get_version_field($vdoc, 'pagesize');
        if ($session->{pagesize}) {
            my $page = $input->param('p') || 1;
            $this->export_paged_doclist($session->{pagesize}, $session->{docs}, $output, $obvius,
                                            name=>'args', page=>$page,
                                            require=>'content',
                                        );
        } else {
            $this->export_doclist($session->{docs},  $output, $obvius,
                                    name=>'args',
                                    require=>'content',
                                );
        }
        #save the session on the output object
        $output->param('SESSION' => $session);
        #make sure we have a session_id
        $output->param('SESSION_ID' => $session->{_session_id}) if($session->{_session_id});
    } elsif ($mode eq 'send_til_en_ven') {
	$mode = 'send_til_en_ven';
    } elsif ($mode eq 'show_questions') {
	$mode = 'show_questions';
    } elsif ($mode eq 'abonnement') {
	$mode = 'abonnement';
    } elsif ($mode eq 'all_votes') {
        $mode = 'all_votes';
        if($input->param('delete')) {
            # Simply expire the cookie :)
            $output->param('Obvius_COOKIES' => { 'Obvius_VOTER_ID' => {
                                                value => $voter_id,
                                                expires => '-1y',
                                            }
                                        });
            $output->param('deleted' => 1);

            # Find the first game
            my $parentid = $doc->Parent;
            $output->param(Obvius_DEPENDENCIES => 1);
            my $possible_docs = $obvius->search(['seq'],
                                                "parent = $parentid AND type = " . $this->Id,
                                                public => 1,
                                                notexpired => 1,
                                                needs_document_fields => ['parent'],
                                                order => 'seq',
                                ) || [];
            my $first_vdoc = shift(@$possible_docs);
            if($first_vdoc) {
                my $first_doc = $obvius->get_doc_by_id($first_vdoc->DocId);
                my $url = $obvius->get_doc_uri($first_doc) . "?bare=1";
                $output->param('Obvius_REDIRECT' => $url);
            } else {
                $output->param('Obvius_REDIRECT' => "../");
            }

        }
    } else {
        $mode = 'view';
    }

    $output->param(vote => $vote);
    $output->param(mode => $mode);

    return OBVIUS_OK;
}

1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Obvius::DocType::Dilemmaspil - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Obvius::DocType::Dilemmaspil;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Obvius::DocType::Dilemmaspil, created by h2xs. It looks like the
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
