package Obvius::SolrConvRoutines;

use strict;
use warnings;

use Obvius::CharsetTools qw(mixed2utf8);
use DateTime;
use DateTime::TimeZone;
my $local_tz = new DateTime::TimeZone(name => 'local');

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

sub toUTF8 {
    my($cmsval) = @_;

    $cmsval = mixed2utf8($cmsval) if ( $cmsval );
    return $cmsval;
}

#####
# Std. return value
#####
1;
