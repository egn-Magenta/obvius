package WebObvius::Site::MultiMason;

use strict;
use warnings;

use WebObvius::Site::Mason;
use Obvius::MultiSite;

our @ISA = qw( WebObvius::Site::Mason );
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub obvius_connect {
    my ($this, $req, $user, $passwd, $doctypes, $fieldtypes, $fieldspecs) = @_;

    my $obvius = $req->pnotes('obvius');
    return $obvius if ($obvius);

    $this->tracer($req, $user||'-user', $passwd||'-passwd') if ($this->{DEBUG});

    my $rootid;
    my $siteroot = $req->subprocess_env('SITEROOT');

    # If we have a siteroot try to get it from the siteobject cache
    if($siteroot) {
        if(my $id = $this->{SITEROOTS}->{$siteroot}) {
            $rootid = $id;
        }
    }

    $obvius = new Obvius::MultiSite(
                                        $this->{OBVIUS_CONFIG},
                                        $user,
                                        $passwd,
                                        $doctypes,
                                        $fieldtypes,
                                        $fieldspecs,
                                        log => $this->{LOG},
                                        siteroot => $siteroot,
                                        rootid => $rootid
                                    );
    return undef unless ($obvius);

    # Now if we didn't know the rootid, get it from $obvius and store it siteobject cache
    if($siteroot and not $rootid) {
        $this->{SITEROOTS}->{$siteroot} = $obvius->{ROOTID};
    }


    $obvius->cache(1);
    $req->register_cleanup(sub { $obvius->cache(0); $obvius->{DB}=undef; 1; } );

    $req->pnotes(obvius => $obvius);
    return $obvius;
}


1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

WebObvius::Site::MultiMason - Perl extension for blah blah blah

=head1 SYNOPSIS

  use WebObvius::Site::MultiMason;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for WebObvius::Site::MultiMason, created by h2xs. It looks like the
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
