package Obvius::DocType::Quiz;

########################################################################
#
# Quiz.pm - Quiz and Game Document Type
#
# Copyright (C) 2001-2002 FI, aparte, Denmark
#
# Authors: Jason Armstrong <jar@fi.dk>
#          Jørgen Ulrik Balslev Krag <jubk@magenta-aps.dk>
#          Peter Makholm <pma@fi.dk>
#          Adam Sjøgren <asjo@aparte-test.dk>
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

our @ISA = qw( Obvius::DocType );
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub action {
    my ($this, $input, $output, $doc, $vdoc, $obvius) = @_;

    $this->tracer($input, $output, $doc, $vdoc, $obvius) if ($this->{DEBUG});

    # retrieve document
    my $prefix = $output->param('PREFIX');

    my $mode = $input->param('mode') || 'form';

    $output->param(Obvius_DEPENCIES => 1);
    my $questions = $obvius->get_document_subdocs($doc);

    my $questions_doctype = $obvius->get_doctype_by_name('QuizQuestion');

    $questions = [ grep { $_->Type == $questions_doctype->ID } @$questions ];

    # If it's a game, handle that instead:
    if ($obvius->get_version_field($vdoc, qw(isgame))) {
        return $this->game($input, $output, $doc, $vdoc, $obvius, $questions);
    }

    my $correct_answer_count = 0;
    my $wrong_answer_count = 0;
    my $answer_count = 0;

    for (@$questions) {

	my $doc = $obvius->get_doc_by_id($_->DocId);
	$obvius->get_version_fields($_, [qw(question answer correctanswer)]);

	my $answers = {};

	for (@{$_->Answer}) {
	    if (/^\[(\w+)\](.*)$/) {
		$answers->{$1} = $2;
	    }
	    else {
		$obvius->log->warn("Didn't understand answer '$_'");
	    }
	}

	my $answer = $input->param("answer_".$doc->Name) || '';

	if ($answer) {
	    $_->{FIELDS}->{ANSWER_ID} = $answer;
	    $_->{FIELDS}->{ANSWER_TEXT} = $answers->{$answer};
	    $answer_count++;
	}

	my $correct_answer_id = $_->CorrectAnswer;
	my $correct_answer_text = $answers->{$correct_answer_id};

	$_->{FIELDS}->{ANSWERS} = [
				   map {
				       my $correct = 0;
				       if ($correct_answer_id  and $correct_answer_id eq $_) {
					   $correct = 1;
				       };

				       ({
					 id => $_,
					 answer => $answers->{$_},
					 correct => $correct,
					 active => ($answer eq $_),
					})
				   } sort keys %$answers
				   #@{$answers->{__order}}
				  ];

	$_->{FIELDS}->{CORRECT_ANSWER_ID} = $correct_answer_id;
	$_->{FIELDS}->{CORRECT_ANSWER_TEXT} = $correct_answer_text;

	$_->{FIELDS}->{CORRECT_ANSWER} = ($answer and $correct_answer_id eq $answer);

	if ($_->{FIELDS}->{CORRECT_ANSWER}) {
	    $correct_answer_count++;
	} else {
	    $wrong_answer_count++;
	}
    }

    my $export_questions = $this->export_doclist($questions, $output, $obvius,
						 prefix=>$prefix,
						 name=>'questions',
						 require=>'content'
						);

    $output->param(questions => $export_questions);

    $output->param(answer_count => $answer_count);
    my $all_questions_answered=((scalar(@$questions) - $answer_count) == 0);
    $output->param(all_questions_answered => $all_questions_answered);

    $output->param(wrong_answer_count => $wrong_answer_count);
    $output->param(correct_answer_count => $correct_answer_count);

    $obvius->get_version_fields($vdoc, [ 'mailto', 'mailmsg', 'requireallanswers', 'custom_msg' ]);

    $output->param('quiz_msg'=>$this->get_quiz_msg($vdoc, $correct_answer_count, $obvius));

    # Export mailto, so the template can tell whether it's a mail-quiz or not:
    $output->param(mailto=>$vdoc->MailTo) if $vdoc->fields('mailto');
    my $submitter_name = $input->param('submitter_name');
    my $submitter_email = $input->param('submitter_email');
    $output->param(submitter_name => $submitter_name);
    $output->param(submitter_email => $submitter_email);

    # Is this an answer, and should it be emailed?
    my $send_email=0;
    if( $mode ne "form" and ($vdoc->field('mailto') and $vdoc->field('mailmsg')) ) {
	$send_email=1;

	# Should all questions be answered before emailing?
	if( ($vdoc->RequireAllAnswers and $vdoc->RequireAllAnswers eq "yes") )
	{
	    # Yes:
	    if( !$all_questions_answered ) {
		$output->param(answers_missing_for_mail => 1);
		$output->param(mode => 'form'); # new form, try again!
		$send_email=0; # but they weren't; don't send
	    }
	}

	if( !($submitter_email) ) {
	    $output->param(email_missing => 1);
	    $output->param(mode => 'form');
	    $send_email=0;
	}

	if( !($submitter_name) ) {
	    $output->param(name_missing => 1);
	    $output->param(mode => 'form');
	    $send_email=0;
	}

	if( $send_email ) {
	    $output->param(recipient => $vdoc->MailTo);
	    $output->param(mode => 'email_sent' );
	    $output->param(mailmsg => $vdoc->MailMsg);
	}
    }
    else
    {
	$output->param(mode => $mode);
    }

    return OBVIUS_OK;
}

sub get_quiz_msg {
    my ($this, $vdoc, $correct_answer_count, $obvius)=@_;

    # Jason: This section ported from v1 to add a customised message based
    #        on the number of correct answers
    #        format is num=msg
    #        num is the upper range of correct answers
    #        msg is the message to display
    #
    #        Documentation from v1: 
    #         https://www.fi.dk/admin/intranet/obviushelp/quiz/

    my $msgs;
    $msgs = $obvius->get_version_field($vdoc, qw(custom_msg));
    my $quiz_msg = '';

    # Put into a hash so that it can be sorted properly
    my %msg_options;
    foreach (@$msgs) {
      s///g;
      if (/^(\d+)=(.*)$/) {
        $msg_options{$1} = $2;
      } else { 
        $obvius->log->warn("Quiz> Invalid Custom Msg: '$_'");
      }
    }
    foreach (sort { $a <=> $b } keys %msg_options) {
      # If it is equal, then use it
      if ($_ == $correct_answer_count) {
        $quiz_msg = $msg_options{$_};
        last;
      }

      if ($_ < $correct_answer_count) {
        $quiz_msg = $msg_options{$_};
      } else {
        # First time ? use this one, otherwise use saved value
        $quiz_msg = ($quiz_msg ? $quiz_msg : $msg_options{$_});
        last;
      }
    }

    return $quiz_msg;
}

sub game {
    my ($this, $input, $output, $doc, $vdoc, $obvius, $questions) = @_;

    $output->param('isgame'=>1);

    my $session=$input->param('session');
    $output->param(Obvius_SIDE_EFFECTS => 1);
    #use Data::Dumper; ; $Data::Dumper::Maxdepth=10; print STDERR "==>SESSION: " . Dumper($session);

    unless ($session) {
        # No session yet, we are to display the frontpage
        return $this->display_frontpage($input, $output, $doc, $vdoc, $obvius, $questions);
    }
    else {
        # We've got a session, so we're in the game:
        return $this->handle_game($input, $output, $doc, $vdoc, $obvius, $questions, $session);
    }
}

sub display_frontpage {
    my ($this, $input, $output, $doc, $vdoc, $obvius, $questions) = @_;
    $questions=[] unless (ref $questions);

    $output->param('display_frontpage'=>1);
    $output->param('teaser'=>$obvius->get_version_field($vdoc, qw(teaser)));

    # Create session
    my $session={
                 questions=>{},
                 answered=>{}, # 0: haven't been answered, 1: has been answered, 2+: has been displayed after answering
                 scores=>{},
                 total=>0,
                 current=>0, # Indexing @$sequence, created below.
                };

    # Shuffle questions
    my $sequence=[map { $_->Docid } @{$questions} ];
    push @$sequence, 0 while(@$sequence<15); # Fill up with 0's till we get 16-1
    fisher_yates_shuffle($sequence);
    $session->{sequence}=$sequence;

    # Display teaser and text, ask for number of questions and go to
    # the first question.

    $output->param('session'=>$session);

    return OBVIUS_OK;
}

sub handle_game {
    my ($this, $input, $output, $doc, $vdoc, $obvius, $questions, $session) = @_;

    # Pass the session along:
    $output->param('session_id'=>$session->{_session_id});

    # Only set max if it hasn't been set before
    if (my $max=$input->param('max') and !exists $session->{max}) {
        $session->{max}=$max;
        #print STDERR " MAX ?S: $max\n";
    }

    # Handle incoming answer (and button to go to next), if any:
    $this->handle_answer($input, $output, $doc, $vdoc, $obvius, $questions, $session);

    # Determine next page:
    if (my $q=$this->find_next_page($input, $output, $doc, $vdoc, $obvius, $questions, $session)) {
        # Look up stuff, so the page can be displayed:
        my $question_doc=$obvius->get_doc_by_id($q);
        my $question_vdoc=$obvius->get_public_version($question_doc) if ($question_doc);
        if ($question_vdoc) {
            $obvius->get_version_fields($question_vdoc,
                                      [qw(title text teaser icon cornergraphic)]);
            $output->param(title        =>$question_vdoc->Title);
            $output->param(text         =>$question_vdoc->field('text'));
            unless ($session->{questions}->{$q}) {
                my ($subqs, $parseerrors)=$this->parse_subqs($question_vdoc->field('text'));
                $session->{questions}->{$q}=$subqs;
                $output->param(parseerrors  =>$parseerrors);
            }
            $output->param(teaser       =>$question_vdoc->field('teaser'));
            $output->param(icon         =>$question_vdoc->field('icon'));
            $output->param(cornergraphic=>$question_vdoc->field('cornergraphic'));
        }
    }
    else {
        #  Game over, man, game over!
        $session->{current}=0;
        $output->param('game_over'=>1);
        $output->param('quiz_msg'=>$this->get_quiz_msg($vdoc, $session->{total}, $obvius));
    }

    return OBVIUS_OK;
}

sub handle_answer {
    my ($this, $input, $output, $doc, $vdoc, $obvius, $questions, $session)=@_;

    return if ($session->{current}==0); # The frontpage

    #print STDERR " HANDLE ANSWER\n";

    my $subqs=$session->{questions}->{$session->{current}};
    my @missing_subqs=();
    my $i=-1;
    foreach my $subq (@$subqs) {
        $i++;
        next if ($subq->{answered});
        delete $subq->{message};
        my $answer=$input->param("Q$i");
        if (defined $answer and $answer ne '') {
            #print STDERR "  ANSWER: " . Dumper($answer);
            if ($subq->{type} eq 'chooseone') {
                if (exists $subq->{options}->{$answer}) {
                    #print STDERR "   REGISTERING OPTION $answer SELECTED FOR SUBQ!\n";
                    $subq->{options}->{$answer}->{chosen}=1;
                    $subq->{answered}=1;
                }
                else {
                    #print STDERR "   DISREGARDING IMPOSSIBLE OPTION $answer FOR SUBQ\n";
                }
            }
            elsif ($subq->{type} eq 'choosemultiple') {
                $answer=[$answer] unless (ref $answer);
                #print STDERR "==> CHOOSEMULTIPLE" . (@$answer) . "\n";
                foreach (@$answer) {
                    #print STDERR "===> ANSWER: $answer\n";
                    if (exists $subq->{options}->{$_}) {
                        #print STDERR "   REGISTERING OPTION $_ SELECTED FOR SUBQ!\n";
                        $subq->{options}->{$_}->{chosen}=1;
                        $subq->{answered}=1;
                    }
                    else {
                        #print STDERR "   DISREGARDING IMPOSSIBLE OPTION $_ FOR SUBQ\n";
                    }
                }
            }
            else { # guessathing
                if (lc($answer) eq lc($subq->{correct_answer})) {
                    #print STDERR "====> ANSWER IS CORRECT!\n";
                    # Mark the last option with shown as chosen:
                    my $lastone=0;
                    foreach (sort keys %{$subq->{options}}) {
                        $lastone=$_;
                        last unless ($subq->{options}->{$_}->{shown});
                    }
                    $subq->{options}->{$lastone}->{chosen}=1;
                    $subq->{answered}=1;
                    $subq->{message}='Rigtigt besvaret: ' . $answer . '!';
                }
                else {
                    #print STDERR "====> NAH, WRONG ANSWER\n";
                    # Check all hints have been shown, the subq is done:
                    my @keys=sort keys %{$subq->{options}};
                    my @shown=grep { $subq->{options}->{$_}->{shown} } @keys;
                    if ($#keys-$#shown<3) {
                        $subq->{options}->{$keys[$#keys]}->{chosen}=1;
                        $subq->{answered}=1;
                        $subq->{message}='Du gættede ikke det rigtige svar, som var: ' . $subq->{correct_answer} . '.';
                    }
                    else {
                        $subq->{message}='Forkert svar, du har fået en ledetråd mere ovenfor. Gæt igen:';
                        $output->param('nexthint'=>1);
                    }
                }
            }
        }
        else {
            #print STDERR "  MISSING ANSWER FOR $i!\n";
            push @missing_subqs, $i;
        }
    }

    # Now, are we done with this question?
    my $subqs_answered=scalar grep { $_->{answered} } @$subqs;
    if ($subqs_answered eq scalar @$subqs) {
        #print STDERR "ALL ANSWERED!\n";
        # Add to score
        my $q_score=0;
        foreach my $subq (@$subqs) {
            my $subq_score=0;
            map {
                $subq_score+=$subq->{options}->{$_}->{value}
                    if ($subq->{options}->{$_}->{chosen}
                        and $subq->{options}->{$_}->{value}
                        and $subq->{options}->{$_}->{value}=~/^\d+$/);
              } sort keys %{$subq->{options}};
            $subq->{score}=$subq_score;
            $q_score+=$subq_score;
            #print STDERR "Q_SCORE: $q_score\n";
        }
        unless (exists $session->{scores}->{$session->{current}}) {
            $session->{scores}->{$session->{current}}=$q_score;
            $session->{total}+=$q_score;
        }

        # Mark as answered:
        $session->{answered}->{$session->{current}}=1
            unless (exists $session->{answered}->{$session->{current}});

        # Display result (button moves to next answer)
        #print STDERR "===> SETTING QUESTION_ANSWERED TO TRUE!\n";
        $output->param('question_answered'=>1);
    }
    else {
        #print STDERR "SUBQS MISSING AN ANSWER!\n";
    }

    $session->{NOW}=localtime(); # Touch the session
}

sub find_next_page {
    my ($this, $input, $output, $doc, $vdoc, $obvius, $questions, $session)=@_;

    my $answered=$session->{answered};

    #print STDERR "  FIND_NEXT_PAGE\n";

    # Check if max number of questions, if set, has been answered -
    # return 0 to indicate game over if so:
    return 0 if ($session->{max} and scalar(keys(%$answered))>=$session->{max});

    #print STDERR "  GOING THROUGH THE SEQUENCE\n";

    my $sequence=$session->{sequence} or die "No sequence in Quiz/game session!";

    my $next_q=0; # 0 indicates game over.

    # Perhaps jump to another question:
    my $goto=$input->param('goto');
    if (defined $goto) {
        if ($sequence->[$goto] and !$answered->{$goto}) {
            $next_q=$sequence->[$goto];
        }
    }

    # ... or stay where we are, if it's not done:
    unless ($next_q) {
        $next_q=$session->{current} if (!$answered->{$session->{current}}
                                        or $answered->{$session->{current}}<2);
    }

    # ... or go to the next in the sequence:
    unless ($next_q) {
        foreach my $q (@$sequence) {
            if ($q and (!$answered->{$q} or $answered->{$q}<2)) {
                $next_q=$q;
                last;
            }
        }
    }

    if ($next_q) {
        #print STDERR "  $q CHOSEN $answered->{$q}!\n";
        # Choose it as the next one, i.e. the upcoming current:
        $session->{answered}->{$next_q}++ if ($answered->{$next_q});
        $output->param('question_answered'=>0) if ($session->{current} ne $next_q);
        $session->{current}=$next_q;
        $session->{NOW}=localtime(); # Touch the session
    }
    #print STDERR "  RAN OUT OF QS!\n";

    return $next_q;
}

# fisher_yates_shuffle( \@array ) :
# generate a random permutation of @array in place
# from perlfaq4, thank you very nice...
sub fisher_yates_shuffle {
    my $array = shift;
    my $i;
    for ($i = @$array; --$i; ) {
        my $j = int rand ($i+1);
        @$array[$i,$j] = @$array[$j,$i];
    }
}

sub parse_subqs {
    my ($this, $text)=@_;

    my @errors=();
    my @l=split /\n/, $text;
    my $i=1;
    my @subqs=();
    my $subq={};
    my $inbrackets=0;
    my $lead='';
    my $correctchoices=0;
    foreach (@l) {
        next if /^$/;
        if (/^\[([^\]]*)\]\s?(.*)$/) { # Lines starting with a bracket, [, are special:
            my ($info, $desc)=($1, $2);

            unless ($inbrackets) {
                # We've reached the next subq, store the current one and
                # start on the new one
                if (exists $subq->{type}) {
                    # Adjust type according to number of correct choices:
                    push @errors, "No correct answer for question \"$subq->{lead}\"!"
                        unless ($correctchoices);
                    $subq->{type}=($correctchoices>1 ? 'choosemultiple' : 'chooseone')
                        if ($subq->{type} eq 'choose');
                    push @subqs, $subq;
                    $correctchoices=0;
                }

                $subq={};
                $subq->{text}=$lead; $lead='';
                $subq->{type}=( $info=~/^::\d+$/ ? 'guessathing' : 'choose' );
                $subq->{options}={};
            }

            # Add option to subq
            my ($id, $value, $flags)=split /::/, $info;
            $subq->{dropdown}=1 if ($flags and lc($flags) eq 'dropdown');
            if (exists $subq->{type} and $subq->{type} eq 'guessathing') {
                unless ($value) { # it's the correct answer
                    $value=$id;
                    $desc=$id;
                    $subq->{correct_answer}=$id;
                }
                $id=$inbrackets;
            }
            $correctchoices++ if ($value);
            push @errors, "Option $id in question \"$subq->{lead}\" defined twice"
                if (exists $subq->{options}->{$id});
            $subq->{options}->{$id}={
                                     value=>$value,
                                     desc=>$desc,
                                    };
            $inbrackets++;
        }
        else {
            $lead=$lead . $_;
            $inbrackets=0;
        }
    }
    # Add last one:
    push @errors, "No correct answer for question \"$subq->{lead}\"!"
        unless ($correctchoices);
    $subq->{type}=($correctchoices>1 ? 'choosemultiple' : 'chooseone')
        if ($subq->{type} eq 'choose');
    push @subqs, $subq if (exists $subq->{type});

    return (\@subqs, \@errors);
}

1;
__END__
=head1 NAME

Obvius::DocType::Quiz - a document type for Obvius that handles quizzes
                      as well as games.

=head1 SYNOPSIS

(use'd automatically by Obvius)

=head1 DESCRIPTION

Obvius::DocType::Quiz gets it's questions from it's subdocuments, of the
type QuizQuestion.

If the field isgame is true, the document type assumes it's a game and
displays the frontpage as a game, generating a session upon submit.

If isgame isn't true, the document type assumes it's a quiz, and
displays the subdocuments as questions in the quiz.

=head1 QUIZ

The quiz is quite simple: An HTML-form containing questions is made
from the subdocuments, and the user can submit the form and get
feedback on whether the replies were correct or not.

A textual evalution of the result is configurable.

=head2 QUESTIONS

Questions consist of a number of options and one correct answer.

=head1 GAME

The game is session-driven - the session is used to store the
(randomly chosen) sequence in which the questions are posed and which
questions has been answered.

At the beginning of the game, the user can choose how many questions
he/she wants to answer: 5, 10 or all.

Each question can contain multiple subquestions of different kinds.

A tally of the score is kept, and when all questions are answered, the
user is awarded one of three medals, depending on the score.

=head2 QUESTIONS

There are three types of questions:

=head3 Choose one

=head3 Choose one or more

=head3 Guess the animal


=head1 EXPORT

None by default.

=head1 AUTHOR

Jason Armstrong <jar@fi.dk>,
Jørgen Ulrik Balslev Krag <jubk@magenta-aps.dk>,
Peter Makholm <pma@fi.dk>,
Adam Sjøgren <asjo@aparte-test.dk>

=head1 SEE ALSO

L<Obvius::DocType::Quiz>, L<Obvius::DocType>.

=cut
