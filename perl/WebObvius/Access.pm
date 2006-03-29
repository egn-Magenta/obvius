# $Id$

package WebObvius::Access;

use 5.006;
use strict;
use warnings;

our @ISA = ();
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

use WebObvius::Apache Constants => qw(:common :methods);


########################################################################
#
#	Access handler (assumes no login)
#
########################################################################

sub access_handler ($$) {
    my ($this, $req) = @_;

    return OK unless ($req->is_main);

    $this->tracer($req) if ($this->{DEBUG});

    $this->add_benchmark($req, 'Access start') if ($this->{BENCHMARK});

    my $uri=$req->uri;
    # map:
    my $remove = $req->dir_config('RemovePrefix');
    $uri =~ s/^\Q$remove\E// if ($remove);
    $uri =~ s/\.html?$//;
    my $prefix = $req->dir_config('AddPrefix') || '';
    $req->notes('prefix', $prefix);

    return $this->redirect($req, "$uri/", 'force-external')
	if ($req->method_number == M_GET and $uri !~ /\/$/ and $uri !~ /\./);

    my $obvius = $this->obvius_connect($req);
    return SERVER_ERROR unless ($obvius);

    my $doc = $this->obvius_document($req);
    return NOT_FOUND unless ($doc);
    return FORBIDDEN unless ($obvius->is_public_document($doc));
    return OK;
}



########################################################################
#
#	Authentication handler (does login)
#
########################################################################

sub authen_handler ($$) {
    my ($this, $req) = @_;

    return OK unless ($req->is_main);

    $this->tracer($req) if ($this->{DEBUG});

    $this->add_benchmark($req, 'Authen start') if ($this->{BENCHMARK});

    my ($res, $pw) = $req->get_basic_auth_pw;
    return $res unless ($res == OK);

    my $login = $req->connection->user;
    unless ($login and $pw and $this->obvius_connect($req, $login, $pw)) {
	$req->note_basic_auth_failure;
	return AUTH_REQUIRED;
    }

    return OK;
}


########################################################################
#
#	Authorization handler (assumes login)
#
########################################################################

# XXX Authorization handler
# XXX Vi ved ikke rigtig endnu hvad brugeren vil.
# XXX Måske skulle vi bare notere os ned hvad brugere må.

sub authz_handler ($$) {
    my ($this, $req) = @_;

    return OK unless ($req->is_main);

    $this->tracer($req) if ($this->{DEBUG});

    add_benchmark($req, 'Authz start') if ($this->{BENCHMARK});

    my $doc = $this->obvius_document($req);
    return NOT_FOUND unless ($doc);
    return OK;
}




1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

WebObvius::Access - Perl extension for blah blah blah

=head1 SYNOPSIS

  use WebObvius::Access;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for WebObvius::Access, created by h2xs. It looks like the
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
