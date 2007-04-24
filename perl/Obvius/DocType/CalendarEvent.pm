package Obvius::DocType::CalendarEvent;

########################################################################
#
# Calendar.pm - CalendarEvent Document Type
#
# Copyright (C) 2001 Magenta Aps, Denmark (http://www.magenta-aps.dk/)
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

use Date::ICal;

our @ISA = qw( Obvius::DocType );
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

# recursively encode an array into ICal text scalar
sub encode_ical
{
	my ( $type, $opt, $as_quoted_printable) = @_;

	my $ret = "BEGIN:$type\n";

	for ( my $i = 0; $i < @$opt; $i += 2) {
		my ( $key, $val) = @$opt[$i,$i+1];
		if ( ref($val) eq 'ARRAY') {
			$ret .= encode_ical( $key, $_, $as_quoted_printable ) for @$val;
			next;
		}

		
		my $quoted = 0; 
		if ( $as_quoted_printable and $val =~ /[\\;,\t\r\n\x80-\xff]/) {
			# quoted-printable, conflicts with default and unicode strings
			$key .= ";ENCODING=QUOTED-PRINTABLE";
			$val =~ s/([\\;,\t\r\n\x80-\xff])/sprintf(q(=%02X),ord($1))/ge;
			$quoted = 1;
		} else {
			# default encoding, conflicts with quoted-printable
			$val =~ s/([\\;,])/\\$1/gs;
			$val =~ s/\n/\\n/gs;
		}
		
		$val =~ s/<("[^"]*"|'[^']*'|[^>])*>//g;
		$val =~ s/\s\s+/ /g;
		next if $val =~ /^\s*$/;

		my $gval = "$key:$val";
		if ( $quoted) {
			# quoted-printable wrapping: assume no field names 
			# should be longer than 74, but do not split the string 
			# inside =X{n} characters (assuming n=2)
			$gval =~ s/\G(.{71}(?:=..|[^=]{1,3})(?=.))/$1=\n/g;
			$gval =~ s/ $/=20/; # outlook does this, but I don't care why
		} else {
			# simple default wrapping
			$gval =~ s/(.{74})/$1\n /g;
		}
		
		$ret .= "$gval\n";
	}
	
	$ret .= "END:$type\n";

	return $ret;
}


sub as_ical
{
	my ( $self, $obvius, $hostname, @events) = @_;

	my @list;
	for my $event ( @events) {
		$obvius-> get_version_fields( $event, [qw(
			docdate teaser eventtype contactinfo 
			eventtime eventplace title 
		)]);

		my ( $contactinfo, $docdate, $eventtime) = map { $event-> field($_) } qw(
			contactinfo docdate eventtime
		);
		
		$contactinfo = "mailto:$contactinfo" if $contactinfo =~ /\@[\w\.]+$/;

		my ( $year, $month, $day, $starthour, $startmin, $endhour, $endmin);
		if ( $docdate =~ /^(\d+)-(\d+)-(\d+)/) {
			( $year, $month, $day) = ( $1, $2, $3);
		} else {
			( $year, $month, $day) = ( 1970, 1, 1);
		}

		if ( $eventtime =~ /(\d+)(?:[.:](\d+))?(?:\s*-\s*(\d+)(?:[.:](\d+))?)?/) {
			$starthour = $1;
			$startmin  = $2 || 0;
			if ( defined $3) {
				$endhour = $3;
				$endmin  = $4 || 0;
			}
		} else {
			( $starthour, $startmin) = (00, 00);
		}

		my $dtstart = Date::ICal-> new(
			year	=> $year,
			month	=> $month,
			day	=> $day,
			hour	=> $starthour,
			min	=> $startmin,
		)-> ical;

		push @list, [
			UID		=> $event-> Docid . '@' . $hostname,
			DESCRIPTION	=> 
				$event-> field('teaser') .
				"\n\n" .
				"http://$hostname".
				$obvius-> get_doc_uri(
					$obvius-> get_doc_by_id( $event-> Docid)
				),
			SUMMARY    	=> $event-> field('title'),
			CATEGORIES 	=> $event-> field('eventtype'),
			LOCATION   	=> $event-> field('eventplace'),
			ORGANIZER  	=> $contactinfo,
			DTSTART		=> $dtstart,
			DTSTAMP		=> $dtstart,
			defined( $endhour) ? (
			DTEND		=> Date::ICal-> new(
				year	=> $year,
				month	=> $month,
				day	=> $day,
				hour	=> $endhour,
				min	=> $endmin,
			)-> ical,
			) : (),
		];
	}

	return encode_ical( 'VCALENDAR', [
		VERSION	=> '2.0',
		METHOD	=> 'PUBLISH',
		PRODID	=> ':-//Obvius//NONSGML ICal//DA',
		VEVENT	=> \@list,
	]);
}

sub raw_document_data
{
	my ($this, $doc, $vdoc, $obvius, $input) = @_;

	return undef unless $input->param('get_ical');

	$input-> no_cache(1);

	return (
		'text/calendar',
		$this-> as_ical(
			$obvius,
			$input-> hostname,
			$vdoc
		),
		$doc->param('name') . ".ics", # filename
	)
}

1;
