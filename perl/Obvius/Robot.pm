package Obvius::Robot;

# $Id$

use strict;
use vars qw($VERSION @ISA @EXPORT $DEBUG);

require Exporter;

@ISA = qw(Exporter);
@EXPORT = qw(retrieve_uri post_uri request_uri request_post_uri);

( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

use LWP::UserAgent ();
use HTTP::Request ();
use HTTP::Request::Common qw(POST);
use HTTP::Response ();

use Data::Dumper;

$DEBUG = 0;

sub request_uri {
    my ($uri, $ua) = @_;

    unless ($ua) {
	$ua = new LWP::UserAgent;
	$ua->env_proxy();
    }

    my $req = new HTTP::Request(GET=>$uri);
    # $req->authorization_basic('guest', 'guest');

    print(STDERR Dumper($req)) if ($DEBUG > 1);

    print(STDERR "Sending request ...\n") if ($DEBUG);
    my $res = $ua->request($req);

    print(STDERR "Finished request status ",
	  $res->code, ": ", $res->message, "\n") if ($DEBUG);

    print(STDERR Dumper($res)) if ($DEBUG > 1);

    return $res;
}

sub retrieve_uri {
    my $res = request_uri(@_);
    return ($res->is_success ? $res->content : undef);
}

sub request_post_uri {
    my ($uri, $ua, $formdata, @headers) = @_;

    unless ($ua) {
	$ua = new LWP::UserAgent;
	$ua->env_proxy();
    }

    my $req = POST($uri, $formdata, @headers);
    # $req->authorization_basic('guest', 'guest');

    print(STDERR Dumper($req)) if ($DEBUG > 1);

    print(STDERR "Sending request ...\n") if ($DEBUG);
    my $res = $ua->request($req);
    print(STDERR "Finished request status ",
	  $res->code, ": ", $res->message, "\n") if ($DEBUG);

    print(STDERR Dumper($res)) if ($DEBUG > 1);

    return $res;
}

sub post_uri {
    my $res = request_post_uri(@_);
    return ($res->is_success ? $res->content : undef);
}


1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Obvius::Robot - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Obvius::Robot;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Obvius::Robot, created by h2xs. It looks like the
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
