package Obvius::DocType::FiskeKalender;

########################################################################
#
# FiskeKalender.pm - FiskeKalender Document Type
#
# Copyright (C) 2001 Magenta Aps, Denmark (http://www.magenta-aps.dk/)
#
# Author: Mads Kristensen (mads@magenta-aps.dk)
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

    my $event_doctype = $obvius->get_doctype_by_name('FiskeKalenderArrangement');

    croak("Couldn't find event doctypeid\n") unless($event_doctype);

    $obvius->get_version_fields($vdoc, 256);

    my $date = $input->param('date');
    $date='' unless ($date and ($date =~ /^[0-9 :.-]*$/)); # Throw away bad dates
    if ($date) {
	$output->param('date_docs' => $this->get_docs_by_date($date, $obvius, $event_doctype));
    } else {
	$date = $vdoc->Startdate unless $date;

	my $comp_date = make_date_comparable($date);
	my $now_date = strftime('%Y%m%d', localtime);
	if ($comp_date < $now_date) {
	    $date = strftime('%Y-%m-%d', localtime);
	}
	$output->param('date_docs' => $this->get_docs_by_date($date, $obvius, $event_doctype, $vdoc->field('enddate')));
    }

    my $where = "type = " . $event_doctype->param('ID') . " and ";

    if($vdoc->Startdate and $vdoc->Enddate) {
        $where .= "fradato >= '" . $vdoc->Startdate . "' and ";
        $where .= "fradato <= '" . $vdoc->Enddate . "' and ";
    }

    my $is_admin = $input->param('IS_ADMIN');

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
	my ($e_year, $e_month, $e_day) = ($time =~ /^(\d\d\d\d)-(\d\d)-(\d\d)/);
	
	$timemin = $time unless (defined($timemin) and $timemin le $time);
	$timemax = $time unless (defined($timemax) and $timemax ge $time);
	
	my $weekno;
	($weekno, $e_year) = Week_of_Year($e_year, $e_month, $e_day);
	$weekno = sprintf("%4.4d%2.2d", $e_year, $weekno);
	my $weekday = Day_of_Week($e_year, $e_month, $e_day);
	
	$event_hash->{$weekno}->{$weekday} = [] unless (defined($event_hash->{$weekno}->{$weekday}));
	
	push(@{$event_hash->{$weekno}->{$weekday}}, $e);
    }

    my ($weekmin, $weekmax);

    my ($min_year, $min_month, $min_day) = ($vdoc->Startdate =~ /^(\d\d\d\d)-(\d\d)-(\d\d)/);
    ($min_year, $min_month, $min_day) = adjust_ymd($min_year, $min_month, $min_day);
    ($weekmin, $min_year) = Week_of_Year($min_year, $min_month, $min_day);
    $weekmin = sprintf("%4.4d%2.2d", $min_year, $weekmin);

    my ($max_year, $max_month, $max_day) = ($vdoc->Enddate =~ /^(\d\d\d\d)-(\d\d)-(\d\d)/);
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
    $output->param(weeks => \@result);

    return OBVIUS_OK;
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

sub make_date_comparable {
    my $date = shift;
    $date =~ s/-|(00:00:00)|\s//g;
    return $date;
}



1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Obvius::DocType::FiskeKalender - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Obvius::DocType::FiskeKalender;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Obvius::DocType::FiskeKalender, created by h2xs. It looks like the
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
