package WebObvius::Timer;

########################################################################
#
# Timer.pm - perl-module for logging time for each request.
#
# Copyright (C) 2002 FI, Denmark (http://www.fi.dk/)
#
# Authors: Peter Makholm (pma@fi.dk)
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
use WebObvius::Apache Constants => qw(:common);
use Time::HiRes qw(gettimeofday tv_interval);

require Exporter;
our @ISA = qw( Exporter );
our @EXPORT_OK = qw( handler );

our $VERSION="1.0";

# StartTimer - stores the current time on pnotes for use by LogTimer
#              later. To be used as a PerlPostReadRequestHandler.
sub StartTimer {
    my $r = shift;
    $r->pnotes(entrytime => [gettimeofday()]); 
    return OK;
}

# LogTimer - logs remote host, date, status, bytes and duration for a
#            request. To be used as a PerlLogHandler.
sub LogTimer {
    my $r = shift;
    my $logfile = $r->dir_config('TimerLog') || return OK;
    my $request = $r->the_request;
    my $remote = $r->get_remote_host;
    my $date = localtime;
    my $status = $r->status;
    my $bytes = $r->bytes_sent;
    my $timer = tv_interval($r->pnotes('entrytime'));
    open FH, ">>$logfile" || return OK;
    print FH join " ", $remote, qq([$date]), qq("$request"), $status, $bytes, $timer, "\n";
    close FH;
    return OK;
}

1;
__END__

=head1 NAME

WebObvius::Timer - Perl module for logging status, bytes and time of each request.

=head1 SYNOPSIS

    # Logging af timer:
    PerlModule WebObvius::Timer
    PerlPostReadRequestHandler WebObvius::Timer::StartTimer
    PerlLogHandler WebObvius::Timer::LogTimer
    PerlSetVar TimerLog /var/www/www.example.com/logs/timer_log

=head1 DESCRIPTION

Adding the above lines to the configuration-file of a website
(www.example.com/conf/setup.conf) will add logging of request-duration
to www.example.com/conf/timer_log.

=head1 AUTHOR

Peter Makholm, E<lt>pma@fi.dkE<gt>

=head1 SEE ALSO

=cut
