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

use Apache;
use Apache::Log;
use Obvius::Log;

our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;
our $AUTOLOAD;

# At least implement the same functions as Apache::Log
use subs qw(emerg alert crit error warn notice info debug);

sub new {
    my ($class) = @_;
    my $this;
    
    bless \$this, $class
}

sub AUTOLOAD {
    my $this = shift;
    return if $AUTOLOAD =~ /::DESTROY$/;

    my $name = $AUTOLOAD;
    $name =~ s/.*:://;
    
    my $log;
    
    if (exists $ENV{'MOD_PERL'}) {
        if (my $r = Apache->request) {
            $log = $r->log;
        } elsif (my $s = Apache->server) {
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
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Obvius::Log::Apache - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Obvius::Log::Apache;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Obvius::Log::Apache, created by h2xs. It looks
like the author of the extension was negligent enough to leave the
stub unedited.

Blah blah blah.

=head2 EXPORT

None by default.


=head1 AUTHOR

A. U. Thor, E<lt>a.u.thor@a.galaxy.far.far.awayE<gt>

=head1 SEE ALSO

L<perl>.

=cut
