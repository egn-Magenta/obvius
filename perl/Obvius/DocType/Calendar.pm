package Obvius::DocType::Calendar;

########################################################################
#
# Calendar.pm - Calendar Document Type
#
# Copyright (C) 2001 Magenta Aps, Denmark (http://www.magenta-aps.dk/)
#
# Author: Jørgen Ulrik B. Krag (jubk@magenta-aps.dk)
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

our @ISA = qw( Obvius::DocType );
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub action {
    my ($this, $input, $output, $doc, $vdoc, $obvius) = @_;

    my $session = $input->param('session') || {};
    my $sesdocs = $session->{docs};

    if($sesdocs and scalar(@$sesdocs)) {
        # Carry on session ID
        $output->param('SESSION_ID' => $session->{_session_id}) if($session->{_session_id});

        $output->param('show_as' => $session->{show_as});

        my $pagesize = $session->{pagesize};
        my $require = $session->{require};
        if($pagesize) {
            my $page = $input->param('p') || 1;
            $this->export_paged_doclist($pagesize, $sesdocs, $output, $obvius,
                                        name=>'tmpevents',
                                        page=>$page,
                                        require=>$require,
                                        include_images=>1,
                                        return_vdoclist => 1,
                                    );
        } else {
            $this->export_doclist($sesdocs,  $output, $obvius,
                                    name=>'tmpevents',
                                    #prefix => $prefix,
                                    require=>$require,
                                    include_images=>1,
                                    return_vdoclist => 1,
                        );
        }

        my $tmpevents = $output->param('tmpevents') || [];
        $output->param('events' => $this->export_eventlist($obvius, $tmpevents));

        return OBVIUS_OK;
    }

    my $event_doctype = $obvius->get_doctype_by_name('CalendarEvent');

    croak("Couldn't find event doctypeid\n") unless($event_doctype);

    my %sort_map = (
                    'title' => 'title',
                    '-docdate' => 'docdate DESC',
                    '+docdate' => 'docdate',
                    'docdate' => 'docdate',
                    'eventtype' => 'eventtype',
                    'contactinfo' => 'contactinfo'
                    );
    $obvius->get_version_fields($vdoc, [
                                        'title',
                                        'docdate',
                                        'startdate',
                                        'enddate',
                                        's_event_path',
                                        's_event_title',
                                        's_event_type',
                                        's_event_contact',
                                        's_event_place',
                                        's_event_info',
                                        's_event_order_by',
                                        'show_as',
                                        'pagesize'
                                        ]);

    my @fields = ( 'docdate' );

    my $where = "type = " . $event_doctype->param('ID') . " and ";

    if($vdoc->field('s_event_title')) {
        push(@fields, 'title');
        $where .= "title LIKE '%" . $vdoc->S_Event_Title ."%' and ";
    }
    if($vdoc->field('s_event_type')) {
        push(@fields, 'eventtype');
        $where .= "eventtype = '" . $vdoc->S_Event_Type . "' and ";
    }
    if($vdoc->field('startdate') and $vdoc->field('enddate')) {
        $where .= "docdate >= '" . $vdoc->Startdate . "' and ";
        $where .= "docdate <= '" . $vdoc->Enddate . "' and ";
    }
    if($vdoc->field('s_event_place')) {
        push(@fields, 'eventplace');
        $where .= "eventplace LIKE '%" . $vdoc->S_Event_Place . "%' and ";
    }
    if($vdoc->field('s_event_contact')) {
        push(@fields, 'contactinfo');
        $where .= "contactinfo LIKE '%" . $vdoc->S_Event_Contact . "%' and ";
    }
    if($vdoc->field('s_event_info')) {
        push(@fields, 'eventinfo');
        $where .= "eventinfo LIKE '%" . $vdoc->S_Event_Info . "%' and ";
    }

    my $show_as = $vdoc->Show_As || 'list';

    my $sortorder;
    if($show_as eq 'list'){
        $sortorder = $vdoc->field('s_event_order_by') || '-docdate';
        my $testorder = $sortorder;
        $testorder =~ s/[+-]//g;
        push(@fields, $testorder) unless(grep {$_ eq $testorder} @fields);
    } else {
        $sortorder = '-docdate';
    }

    my $sort_sql = $sort_map{$sortorder};

    my $is_admin = $input->param('IS_ADMIN');

    my %options = (
                    order=>$sort_sql,
                    public => !$is_admin,
                    nothidden => !$is_admin,
                    notexpired => !$is_admin
                );

    my $limit_path = $vdoc->field('s_event_path');
    if($limit_path and $limit_path ne '/') {
        my $limit_parent = $obvius->lookup_document($limit_path);
        if($limit_parent) {
            $options{needs_document_fields} = [ 'parent' ];
            $options{straight_documents_join} = 1;
            $where .= "parent = " . $limit_parent->Id . " and ";
        }
    }

    $where =~ s/ and $//;

    $output->param(Obvius_DEPENCIES => 1);
    my $result = $obvius->search(\@fields, $where, %options);
    $result = [] unless($result);

    $output->param(show_as => $show_as);

    if($show_as eq 'list') {
        # Show as a list..
        my $session = {};

        my $pagesize = $vdoc->field('pagesize') || 0;

        if ($pagesize) {
            my $page = $input->param('p') || 1;
            $this->export_paged_doclist($pagesize, $result, $output, $obvius,
                                        name=>'tmpevents', page=>$page,
                                        require=>'teaser',
                                        include_images=>1,
                                        return_vdoclist => 1,
                                    );
        } else {
            $this->export_doclist($result,  $output, $obvius,
                                    name=>'tmpevents',
                                    require=>'teaser',
                                    include_images=>1,
                                    return_vdoclist => 1,
                                );

        }

        my $tmpevents = $output->param('tmpevents') || [];
        $output->param('events' => $this->export_eventlist($obvius, $tmpevents));

        # Store stuff in session
        $session->{docs} = $result;
        $session->{pagesize} = $pagesize;
        $session->{require} = '';
        $session->{show_as} = 'list';
        $output->param('session' => $session);
    } else {
        #Now, let's make a neat list
        my $events = $this->export_eventlist($obvius, $result);

        my $event_hash = {};

        my ($timemin, $timemax);

        for my $e (@$events) {
            my $time = $e->{date};
            my ($start_year, $start_month, $start_day) = ($time =~ /^(\d\d\d\d)-(\d\d)-(\d\d)/);

            $timemin = $time unless (defined($timemin) and $timemin le $time);
            $timemax = $time unless (defined($timemax) and $timemax ge $time);

            my $delta_days = 0;

            my $endtime = $e->{enddate};
            if($endtime and $endtime ne $time and $endtime =~ /^(\d\d\d\d)-(\d\d)-(\d\d)/) {
                my $end_year = $1;
                my $end_month = $2;
                my $end_day = $3;

                $timemax = $endtime unless (defined($timemax) and $timemax ge $endtime);
                if(check_date($start_year, $start_month, $start_day) and check_date($end_year, $end_month, $end_day)) {
                    my $dds = Delta_Days($start_year, $start_month, $start_day, $end_year, $end_month, $end_day);

                    $delta_days = $dds if($dds > 0);
                }
            }

            for(0..$delta_days) {
                my ($year, $month, $day) = Add_Delta_Days($start_year, $start_month, $start_day, $_);
                my ($weekno, $w_year) = Week_of_Year($year, $month, $day);
                $weekno = sprintf("%4.4d%2.2d", $w_year, $weekno);
                my $weekday = Day_of_Week($year, $month, $day);

                $event_hash->{$weekno}->{$weekday} = [] unless (defined($event_hash->{$weekno}->{$weekday}));
                push(@{$event_hash->{$weekno}->{$weekday}}, $e);
            }
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
                                    mday    => $d
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
    }

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

sub export_eventlist {
    my ($this, $obvius, $events) = @_;

    my @events;
    for(@$events) {
        my $doc = $obvius->get_doc_by_id($_->DocId);
        my $url = $obvius->get_doc_uri($doc);
        $obvius->get_version_fields($_, [
                                        'title',
                                        'eventtype',
                                        'eventtime',
                                        'eventplace',
                                        'contactinfo',
                                        'eventinfo',
                                        'enddate'
                                    ]
                                );
        push(@events, {
                        'title' => $_->field('title'),
                        'eventtype' => $_->field('eventtype'),
                        'date' => $_->DocDate,
                        'enddate' => $_->field('enddate'),
                        'time' => $_->field('eventtime'),
                        'place' => $_->field('eventplace'),
                        'contactinfo' => $_->field('contactinfo'),
                        'eventinfo' => $_->field('eventinfo'),
                        'url' => $url
                    });
    }

    return \@events;
}

1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Obvius::DocType::Calendar - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Obvius::DocType::Calendar;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Obvius::DocType::Calendar, created by h2xs. It looks like the
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
