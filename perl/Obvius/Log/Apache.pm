package Obvius::Log::Apache;

########################################################################
#
# Apache.pm - A wrapper for logging through Apache::Log-objects
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

# The problem is as follows:
#
# We can't store an Apache::Log-object in the main server and use it in
# a child. When we try to do this apache segfaults. So we either have to
# re-instantiate the log-object in a ChildInitHandler or do it like
# this.
#


use strict;
use warnings;

our $MOD_PERL = (exists $ENV{'MOD_PERL'}) ? (
	( $ENV{'MOD_PERL'} =~ /mod_perl\/2/) ? 2 : 1
) : 0;

if ( $MOD_PERL == 2) {
	eval <<AP2;
use Apache2::RequestUtil; 
use Apache2::ServerUtil; 
use Apache2::Log;
AP2
	die $@ if $@;
} elsif ( $MOD_PERL == 1) {
	eval <<AP1;
use Apache;
use Apache::Log;
AP1
	die $@ if $@;
}
use Obvius::Log;


our $VERSION="1.0";
our $AUTOLOAD;

# At least implement the same functions as Apache::Log
use subs qw(emerg alert crit error warn notice info debug);

# new - returns an Obvius::Log object
sub new {
    my ($class) = @_;
    my $this;

    bless \$this, $class
}

# AUTOLOAD - this is the actual workhorse, doing the logging according to level
sub AUTOLOAD {
    my $this = shift;
    return if $AUTOLOAD =~ /::DESTROY$/;

    my $name = $AUTOLOAD;
    $name =~ s/.*:://;

    my $log;

    if ($MOD_PERL == 1) {
        if (my $r = Apache->request) {
            $log = $r->log;
        } elsif (my $s = Apache->server) {
            $log = $s->log;
	}
    } elsif ( $MOD_PERL == 2) {
        if (my $r = Apache2::RequestUtil->request) {
            $log = $r->log;
        } elsif (my $s = Apache2::ServerUtil->server) {
            $log = $s->log;
	}
    }

    unless ($log) {
        $log = new Obvius::Log;
	$log->info("Not running under mod_perl. Falling back to Obvius::Log") unless $$this++;
    }


    # Force &Apache::Log::debug() to report the file and line number from where we got called
    # from instead of always just reporting this place. If we start handle debug special for
    # some other reason this shouldn't be done for the other functions (emerg, alert, crit &c)

    my ($package, $filename, $line) = caller;
    eval qq{ 
#line $line "$filename"
                     \$log->$name(\@_);
    }

}

1;
__END__

=head1 NAME

Obvius::Log::Apache - A wrapper for logging through Apache::Log-objects

=head1 SYNOPSIS

  use Obvius::Log::Apache;

  my $log=Obvius::Log::Apache->new;

=head1 DESCRIPTION

This module acts as a wrapper around Apache::Log with the same
interface as Obvius::Log (which this module falls back to).

It is used in conf/setup.pl on the various websites.

=head1 AUTHOR

Peter Makholm
Adam Sjøgren E<lt>asjo@magenta-aps.dkE<gt>

=head1 SEE ALSO

L<Apache::Log>.

=cut
