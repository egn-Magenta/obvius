package Obvius::DocType::FiskeKalender;

########################################################################
#
# FiskeKalender.pm - FiskeKalender Document Type
#
# Copyright (C) 2001-2004 aparte A/S, Denmark (http://www.aparte.dk/)
#
# Authors: Mads Kristensen
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

# $Id$

use strict;
use warnings;

use Obvius;
use Obvius::DocType;

use Date::Calc qw(:all);
use locale;
use Carp;
use POSIX qw(strftime);

our @ISA = qw( Obvius::DocType );
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub action {
    my ($this, $input, $output, $doc, $vdoc, $obvius) = @_;

    my ($date_docs, $weeks)=$this->get_date_docs_weeks($input->param('date'), $input->param('IS_ADMIN'), $vdoc, $obvius);

    $output->param(date_docs=>$date_docs);
    $output->param(weeks=>$weeks);

    return OBVIUS_OK;
}

sub get_date_docs_weeks {
    my ($this, $date, $is_admin, $vdoc, $obvius)=@_;

    my $date_docs;
    my $weeks;

    my $event_doctype = $obvius->get_doctype_by_name('FiskeKalenderArrangement');

    croak("Couldn't find event doctypeid\n") unless($event_doctype);

    $obvius->get_version_fields($vdoc, 256);

    my $enddate=$vdoc->field('enddate');

    # Note: $date is only used in the if-clause below, while $enddate
    # is used in the rest of the function. Instead of $date,
    # $vdoc->field('startdate') is used later, and it's value is not
    # "the same" as $date, because of the comparison with $now_date
    # below.
    $date='' unless ($date and ($date =~ /^[0-9 :.-]*$/)); # Throw away bad dates
    if ($date) {
        $enddate=sprintf('%4.4d-%2.2d-%2.2d',  Add_Delta_YMD(Add_Delta_YM((split /[-]/, $date), 0, 1), 0, 0, -1)) unless ($enddate);
	$date_docs = $this->get_docs_by_date($date, $obvius, $event_doctype);
    }
    else {
	$date = $vdoc->field('startdate');

	my $comp_date = make_date_comparable($date);
	my $now_date = strftime('%Y%m%d', localtime);
	if ($comp_date < $now_date) {
	    $date = strftime('%Y-%m-%d', localtime);
	}
        $enddate=sprintf('%4.4d-%2.2d-%2.2d',  Add_Delta_YMD(Add_Delta_YM((split /[-]/, $date), 0, 1), 0, 0, -1)) unless ($enddate);
	$date_docs = $this->get_docs_by_date($date, $obvius, $event_doctype, $enddate);
    }

    my $where = "type = " . $event_doctype->param('ID') . " and ";

    if($vdoc->field('startdate') and $enddate) {
        $where .= "fradato >= '" . $vdoc->field('startdate') . "' and ";
        $where .= "fradato <= '" . $enddate . "' and ";
    }

    my %options = (
		   order=>" fradato ",
		   public => !$is_admin,
		   notexpired => !$is_admin
		  );

    my $limit_path = $vdoc->field('s_event_path');
    if($limit_path and $limit_path ne '/') {
        my $limit_parent = $obvius->lookup_document($limit_path);
        if($limit_parent) {
            $options{needs_document_fields} = [ 'parent' ];
            $where .= "parent = " . $limit_parent->Id . " and ";
        }
    }

    $where =~ s/ and $//;

    my $result = $obvius->search(['fradato'], $where, %options);
    $result = [] unless($result);

    #Now, let's make a neat list
    my @events;
    for(@$result) {
        push(@events, {
		       'date' => $_->Fradato,
		      }
	    );
    }

    my $event_hash = {};

    my ($timemin, $timemax);

    for my $e (@events) {
	my $time = $e->{date};

        if ($time =~ /^(\d\d\d\d)-(\d\d)-(\d\d)/) {
            my ($e_year, $e_month, $e_day) = ($1, $2, $3);
	
            $timemin = $time unless (defined($timemin) and $timemin le $time);
            $timemax = $time unless (defined($timemax) and $timemax ge $time);

            my $weekno;
            eval { ($weekno, $e_year) = Week_of_Year($e_year, $e_month, $e_day); };

            unless ($@) {
                $weekno = sprintf("%4.4d%2.2d", $e_year, $weekno);
                my $weekday = Day_of_Week($e_year, $e_month, $e_day);
                $event_hash->{$weekno}->{$weekday} = [] unless (defined($event_hash->{$weekno}->{$weekday}));
                push(@{$event_hash->{$weekno}->{$weekday}}, $e);
            }
            else {
                print STDERR "WARNING: FiskeKalender.pm skipped an event; couldn't find week for date: '$time'\n";
            }
        }
        else {
            print STDERR "WARNING: FiskeKalender.pm skipped an event; couldn't parse date: '$time'\n";
        }
    }

    my ($weekmin, $weekmax);

    # $vdoc->Startdate
    my $a=$vdoc->field('startdate') || $date;
    my ($min_year, $min_month, $min_day) = ($a =~ /^(\d\d\d\d)-(\d\d)-(\d\d)/);
    ($min_year, $min_month, $min_day) = adjust_ymd($min_year, $min_month, $min_day);
    ($weekmin, $min_year) = Week_of_Year($min_year, $min_month, $min_day);
    $weekmin = sprintf("%4.4d%2.2d", $min_year, $weekmin);

    my ($max_year, $max_month, $max_day) = ($enddate =~ /^(\d\d\d\d)-(\d\d)-(\d\d)/);
    ($max_year, $max_month, $max_day) = adjust_ymd($max_year, $max_month, $max_day);
    ($weekmax, $max_year) = Week_of_Year($max_year, $max_month, $max_day);
    $weekmax = sprintf("%4.4d%2.2d", $max_year, $weekmax);

    # People might get it wrong and we don't want to wait forever
    if($weekmin > $weekmax) {
	my $temp = $weekmin;
	$weekmin = $weekmax;
	$weekmax = $temp;
    }

    my @result;

    for my $wno ($weekmin..$weekmax) {
	my $year = substr($wno,0,4);
	my $Weekno = substr($wno,-2);
	my $weekno = $wno%100;
	my $weeks_in_year = Weeks_in_Year($year);
	next if($weekno > $weeks_in_year or $weekno < 1);
	
	my @weekdays;
	for my $weekday (1..7) {
	    my ($y, $m, $d) = Add_Delta_Days(Monday_of_Week($weekno, $year), ($weekday - 1));
	    push(@weekdays, {
			     weekday => $weekday,
			     docs    => defined($event_hash->{$wno}->{$weekday}) ? $event_hash->{$wno}->{$weekday} : undef,
			     dayname => Day_of_Week_Abbreviation($weekday),
			     Dayname => Day_of_Week_to_Text($weekday),
			     month   => substr(Month_to_Text($m),0,3),
			     Month   => Month_to_Text($m),
			     mday    => $d,
			     mnumber => $m
			    });
	}
	
	push(@result, {
		       year => $year,
		       Weekno => $Weekno,
		       weekno => $weekno,
		       weekdays => \@weekdays
		      });
    }
    $weeks=\@result;

    return ($date_docs, $weeks);
}

sub adjust_ymd {
    my ($y, $m, $d) = @_;

    $y = 1970 if(! $y or $y < 1970);
    $y = 2037 if($y > 2037);

    $m = 1 if(! $m or $m < 1);
    $m = 12 if($m > 12);

    my $dim = Days_in_Month($y, $m);
    $d = 1 if(! $d or $d < 1);
    $d = $dim if($d > $dim);

    return($y, $m, $d);
}

sub get_docs_by_date {
    my ($this, $date, $obvius, $event_doctype, $enddate) = @_;

    my %search_options =    (
			     notexpired=>1,
			     order => 'fradato, title',
			     public=>1
			    );

    my $where;

    if ($enddate) {
	$where = "type=" . $event_doctype->{ID} . " and fradato >= \'" . $date . "\'";
	$where .= " and fradato <= \'" . $enddate . "\'";
    }
    else {
	$where = "type=" . $event_doctype->{ID} . " and fradato like \'" . $date . "%\'";
    }

    my $all_docs = $obvius->search([qw(fradato title)], 
				 $where, 
				 %search_options);

    for (@$all_docs) {
	$obvius->get_version_fields($_, [qw(fradato title short_title teaser tema)]);
	my $doc = $obvius->get_doc_by_id($_->{DOCID});
	$_->{URI} = $obvius->get_doc_uri($doc);
    }

    # show at least 5 events
    if (scalar @$all_docs < 5 and (!$enddate)) {
	%search_options =    (
			      notexpired=>1,
			      order => 'fradato, title',
			      public=>1,
			      append =>"limit " . (5 - (scalar @$all_docs))
			     );
	
	$where = "type=" . $event_doctype->{ID} . " and fradato > \'" . $date . "%\'";

	my $extra_docs = $obvius->search([qw(fradato title)], 
				     $where, 
				     %search_options);

	for (@$extra_docs) {
	    $obvius->get_version_fields($_, [qw(fradato title short_title teaser tema)]);
	    my $doc = $obvius->get_doc_by_id($_->{DOCID});
	    $_->{URI} = $obvius->get_doc_uri($doc);
	    push @$all_docs, $_;
	}
    }

    return $all_docs;
}

# make_date_comparable - supplied with a string, removes any dashes,
#                        whitespaces an occurrances of the string
#                        '00:00:00'.
sub make_date_comparable {
    my $date = shift;
    $date =~ s/-|(00:00:00)|\s//g;
    return $date;
}

1;
__END__

=head1 NAME

Obvius::DocType::FiskeKalender - a calendar for www.sportsfiskeren.dk

=head1 SYNOPSIS

  use'd automatically by Obvius

=head1 DESCRIPTION

This module is used by www.sportsfiskeren.dk and
www.fiskeskolen.dk. Never the less it's quite website specific, and
should not be placed in Obvius proper.

=head1 AUTHOR

Mads Kristensen
Adam Sjøgren E<lt>asjo@magenta-aps.dkE<gt>

=head1 SEE ALSO

L<Sportsfiskeren::DocType>, L<Fiskeskolen::DocType>.

=cut
