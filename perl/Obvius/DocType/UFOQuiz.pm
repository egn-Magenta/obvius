package Obvius::DocType::UFOQuiz;

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
      } else { 
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
                                 if ($correct_answer_id and 
                                     $correct_answer_id eq $_) {
                                   $correct = 1;
                                 };

                                 ({
                                   id => $_,
                                   answer => $answers->{$_},
                                   correct => $correct,
                                   active => ($answer eq $_),
                                 })
                               } sort keys %$answers
                              ];

    $_->{FIELDS}->{CORRECT_ANSWER_ID} = $correct_answer_id;
    $_->{FIELDS}->{CORRECT_ANSWER_TEXT} = $correct_answer_text;

    $_->{FIELDS}->{CORRECT_ANSWER} = ($answer and 
                                      $correct_answer_id eq $answer);

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

  # Jason: This section ported from v1 to add a customised message based
  #        on the number of correct answers

  my $msgs;
  $msgs = $vdoc->Custom_Msg if ($vdoc->field('custom_msg'));
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
      $output->param(quiz_msg => $msg_options{$_});
      last;
    }

    if ($_ < $correct_answer_count) {
      $quiz_msg = $msg_options{$_};
    } else {
      # First time ? use this one, otherwise use saved value
      $output->param(quiz_msg => ($quiz_msg ? $quiz_msg : $msg_options{$_}));
      last;
    }
  }

  $output->param(quiz_msg => $quiz_msg) unless $output->param('quiz_msg');

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
    if( ($vdoc->RequireAllAnswers and $vdoc->RequireAllAnswers eq "yes") ) {
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
  } else {
    $output->param(mode => $mode);
  }

  return OBVIUS_OK;
}

1;
__END__
