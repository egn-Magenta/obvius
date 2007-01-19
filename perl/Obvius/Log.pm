package Obvius::Log;

########################################################################
#
# Log.pm - A minimalistic logging module.
#
# Copyright (C) 2002-2004 FI, Denmark (http://www.fi.dk/)
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

our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;
our $AUTOLOAD;

# At least implement the same functions as Apache::Log
use subs qw(emerg alert crit error warn notice info debug);

my %loglevel;

{
    my $i;
    $loglevel{$_} = $i++ for qw(debug info notice warn error crit alert emerg none);

    # Backward compatibility:
    $loglevel{0} = $loglevel{info};
    $loglevel{1} = $loglevel{debug};
}

# new - given a log-level (debug=1, info=0, notice, warn, error, crit,
#       alert, emerg, none), returns a log-object that will only
#       output log-messages on that level and above.
sub new {
    my ($class, $loglevel) = @_;

    $loglevel = 'none' unless defined $loglevel;
    $loglevel = exists($loglevel{$loglevel}) ? $loglevel{$loglevel} : $loglevel{none};

    bless \$loglevel, $class
}

sub AUTOLOAD {
    return if $AUTOLOAD =~ /::DESTROY$/;

    my $name = $AUTOLOAD;
    $name =~ s/.*:://;

    no strict 'refs';
    *$AUTOLOAD = sub { my ($this, $message) = @_; print STDERR "[$name] $message\n" if ($loglevel{$name} >= $$this) };
    use strict 'refs';
    goto &$AUTOLOAD;

}

1;
__END__

=head1 NAME

Obvius::Log - Perl module that implements a log-object with different levels of logging.

=head1 SYNOPSIS

  use Obvius::Log;

=head1 DESCRIPTION

=head2 EXPORT

None by default.

=head1 AUTHOR

Peter Makholm, E<lt>pma@fs.dkE<gt>

=head1 SEE ALSO

L<Apache::Log>, L<Obvius>.

=cut
