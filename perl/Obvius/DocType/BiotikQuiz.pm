package Obvius::DocType::BiotikQuiz;

########################################################################
#
# BiotikQuiz.pm - BiotikQuiz Document Type
#
# Copyright (C) 2002 aparte, Denmark (http://www.aparte.dk/)
#
# Authors: Mads Kristensen,
#          Jørgen Ulrik Balslev Krag <jubk@magenta-aps.dk>
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
use DBI; # using dbi, no time to study dbix-recordset :-(

use Obvius;
use Obvius::DocType;

our @ISA = qw( Obvius::DocType );
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub action {
    my ($this, $input, $output, $doc, $vdoc, $obvius) = @_;

    $output->param(Obvius_SIDE_EFFECTS => 1); # Session
    my $session = $input->param('SESSION') || {};

    if($session->{_session_id}) {
        $output->param('SESSION_ID' => $session->{_session_id});
    }

    # load questions if we don't have them
    unless ($session->{questions} and @{$session->{questions}}) {
	my $question_doctype=$obvius->get_doctype_by_name("BiotikQuizQuestion");
	my $question_id = $question_doctype->Id;
	
	my %search_options =    (
				 notexpired=>1,
				 order => 'seq',
				 public=>1,
				 append=>'limit 5'
				);
	
        $output->param(Obvius_DEPENCIES => 1); # search
	my $question_docs = $obvius->search([qw(docdate seq)],
					  "type = " . $question_id,
					  %search_options);
	
	
	my @questions;
	for(@$question_docs) {
	    $obvius->get_version_fields($_, [qw(docid title short_title teaser correct_answer answer_1 answer_2 answer_3 description)]);
	    my $doc = $obvius->get_doc_by_id($_->DocId);
	    my $url = $obvius->get_doc_uri($doc);
	    push(@questions, {
			       question => $_->Teaser,
			       correct_answer => $_->Correct_answer,
			       answer_1 => $_->Answer_1,
			       answer_2 => $_->Answer_2,
			       answer_3 => $_->Answer_3,
			       description => $_->Description,
			       docid => $_->Docid
			      }
		);
	}
	
	$session->{questions} = \@questions;
	$output->param('SESSION' => $session);

	# Make session notice the changes to ->{questions}
	$session->{questions} = $session->{questions};
    }
    if ($input->param('mode') eq 'answer') {
	my $docid = $input->param('docid');
	my $answer = $input->param('answers'); # 0 = rigtig, 1-3 = forkert svar 1, 2 og 3

	# if the answer is correct, then the docid is added to the session
	if ($answer == 0) {
	    my $correct_answers = $session->{correct_answers} || [];
	    my $already_answered = 0;

	    for (@$correct_answers) {
		if ($_ == $docid) {
		    $already_answered = 1;
		}
	    }
	
	    if (!$already_answered) {
		push (@$correct_answers, $docid);
		$session->{correct_answers} = $correct_answers;
		# Make session notice the changes to ->{correct_answers}
		$session->{correct_answers} = $session->{correct_answers};
	    }
	}

        my $config = $obvius->{OBVIUS_CONFIG};
	my $dbh=DBI->connect($config->{'DSN'}, $config->{'NORMAL_DB_LOGIN'}, $config->{'NORMAL_DB_PASSWD'});
	
	# update the database with the new answers
	my $sth = $dbh->prepare ("select * from quiz where docid = $docid and answer = \'$answer\'");
	$sth->execute();

        $output->param(Obvius_SIDE_EFFECTS => 1); # Write to database
	if (!$sth->fetchrow_array) {
	    $sth = $dbh->prepare ("insert into quiz (docid, answer, total) values ($docid, \'$answer\', 1)"); 
	    $sth->execute;
	}
	else {
	    $sth = $dbh->prepare ("update quiz set total = total + 1 where docid = $docid and answer = \'$answer\'"); 
	    $sth->execute;
	}

	# select the data used for statistics
	$sth = $dbh->prepare ("select sum(total) as total from quiz where docid = $docid");
	$sth->execute;
	my $total_answers = $sth->fetchrow || '0';

	$sth = $dbh->prepare ("select sum(total) as total from quiz where docid = $docid and answer = '0'");
	$sth->execute;
	my $total_correct = $sth->fetchrow || '0';

	$output->param('total_correct' => $total_correct);
	$output->param('total_answers' => $total_answers);

	$sth->finish();
	$dbh->disconnect();
    }
    if ($input->param('mode') eq 'stat') {
	# prepare the SQL
	my $all_questions = $session->{questions};
	my $where = '';

	for (@$all_questions) {
	    $where .= " docid=$_->{docid} or";
	}
	$where =~ s/or$//;

	my $sql_total = "select sum(total) as total from quiz where (" . $where . ")";
	my $sql_correct = $sql_total . " and answer = '0'"; 

	
        $output->param(Obvius_SIDE_EFFECTS => 1); # Non-document data from database
        my $config = $obvius->{OBVIUS_CONFIG};
        my $dbh=DBI->connect($config->{'DSN'}, $config->{'NORMAL_DB_LOGIN'}, $config->{'NORMAL_DB_PASSWD'});
	
	# find the total number of questions
	my $number_questions = scalar @$all_questions;
	$output->param('number_questions' => $number_questions);

	# find the total number of questions
	my $sth_total = $dbh->prepare($sql_total);
	$sth_total->execute;
	my $total_questions = $sth_total->fetchrow || '0';
	$output->param('total_questions' => $total_questions);
	
	# find the total number of correct answers
	my $sth_correct = $dbh->prepare($sql_correct);
	$sth_correct->execute;
	my $total_correct = $sth_correct->fetchrow || '0';
	$output->param('total_correct' => $total_correct);

	# find the number of this users correct answers
	my $correct_answers = $session->{correct_answers} || [];
	my $correct_number = scalar @$correct_answers || '0';
	$output->param('correct_answers' => $correct_number);
    }

    my $question_number = $input->param('question') || '0';
    my $number = scalar @{$session->{questions}};

    $output->param('question_number' => $question_number);
    $output->param('question'        => $session->{questions}->[$question_number]);
    $output->param('more_questions'  => $question_number+1 < $number ? '1' : '0');

    return OBVIUS_OK;
}

1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Obvius::DocType::BiotikQuiz - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Obvius::DocType::BiotikQuiz;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Obvius::DocType::BiotikQuiz, created by h2xs. It looks like the
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
