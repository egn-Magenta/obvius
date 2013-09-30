package Obvius::SolrConvRoutines;

use strict;
use warnings;

use Obvius::CharsetTools qw(mixed2utf8 mixed2perl);
use DateTime;
use DateTime::TimeZone;
my $local_tz = new DateTime::TimeZone(name => 'local');
my $utc_tz = new DateTime::TimeZone(name => 'UTC');

###############################################################################
###### This module contains routines, which can be used when mapping CMS field
###### values to SOLR field values
###### All routines SUBROUTINE must have the formal parameter list signature:
######      SUBROUTINE(CMSVAL)
###### Where CMSVAL is 1) a literal for conversion of fieldvalue of 
######                    a non-repeatable field
######              or 2) A reference to an array of literals for conversion of 
######                    fieldvalue of a repeatable field
###############################################################################

###############################################################################
###### Converting CMS date-time values to SOLR UTC ditto
###############################################################################
sub toUTCDateTime {
    my($cmsval) = @_;

    if ( my($Y, $M, $D, $h, $m, $s) = $cmsval =~ /^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})$/ ) {
	my $dt = new DateTime(year => $Y, month => $M, day => $D, hour => $h,
			      minute => $m, second => $s, time_zone => $local_tz);
	# Make it UTC
	$dt->subtract(seconds => $dt->offset());
	return $dt->iso8601 . "Z";
    } else {
	return $cmsval;
    }
}

sub fromUTCDateTime {
    my($utcval) = @_;


    if ( my($Y, $M, $D, $h, $m, $s) = $utcval =~ /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})Z$/ ) {
	my $dt = new DateTime(year => $Y, month => $M, day => $D, hour => $h,
			      minute => $m, second => $s, time_zone => $utc_tz);
	# Make it local
	$dt->set_time_zone('local');
	my $cmsval = $dt;
	$cmsval =~ s/[TZ]/ /g;
	return $cmsval;
    } else {
	return $utcval;
    }
}

sub toUTF8 {
    my($cmsval) = @_;

    $cmsval = mixed2utf8($cmsval) if ( $cmsval );
    return $cmsval;
}

sub toPERL {
    my($cmsval) = @_;

    $cmsval = mixed2perl($cmsval) if ( $cmsval );
    return $cmsval;
}

sub multipath2Id {
    my($cmsval) = @_;
    return [ map { 
	if (/^\d+\:\/(\d+)\.docid$/) {
	    $1;
	} elsif (/^(\d+)$/) {
	    $1;
	} else {
	    $_;
	}
      } @$cmsval ];
}

#####
# Std. return value
#####
1;
