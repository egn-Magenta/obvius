package WebObvius::Site::MultiMason;

use strict;
use warnings;

use WebObvius::Site::Mason;
use Obvius::MultiSite;

use Fcntl ':flock';


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

    if($obvius->{SITEROOT}) {
        $req->notes('siteroot' => $obvius->{SITEROOT})
    }

    $obvius->cache(1);
    $req->register_cleanup(sub { $obvius->cache(0); $obvius->{DB}=undef; 1; } );

    $req->pnotes(obvius => $obvius);
    return $obvius;
}


sub save_in_cache {
    my ($this, $req, $s) = @_;

    my $obvius=$req->notes('obvius');

    my $log;
    if (defined $obvius) {
        $log = $obvius->log;
    } else {
        $log = Obvius::log();
    }

    my $id = $req->notes('cache_id');
    return unless ($id);
    return unless ($this->{WEBOBVIUS_CACHE_INDEX} and $this->{WEBOBVIUS_CACHE_DIRECTORY});

    my $dir = $req->notes('cache_dir');
    unless (-d $dir) {
        my $d;
        my @dirs = split '/', $dir;
        if ($dirs[0] eq '') {
            $dir = '/'; shift @dirs;
        } else {
            $dir = ''
        }
        while ($d = shift @dirs) {
            $dir .= $d . '/';
            unless (-d $dir) {
                mkdir($dir, 0775) or do{$log->debug("Couldn't make dir: $dir"); return};
                chmod(0775, $dir);
            }
        }
    }

    my $file = $req->notes('cache_file');

    $log->debug("Cache file name $file");
    unlink($file);

    my $fh = new Apache::File('>'.$file);
    if ($fh) {
        $log->debug("Cache file open ok");
        print $fh (ref($s) ? $$s : $s);
        $fh->close;

        my $extra = '';
        my $qstring = $req->args;
        if($qstring and $qstring =~ /^size=\d+x\d+$/) {
            $extra = $qstring;
        }

        if (! -e $this->{WEBOBVIUS_CACHE_INDEX} . "-off") {
            # Add to cache-db
            $fh = new Apache::File('>>' . $this->{WEBOBVIUS_CACHE_INDEX});
            if (open FH, '>>', $this->{WEBOBVIUS_CACHE_INDEX}) {
                if (flock FH, LOCK_EX|LOCK_NB) {
                    my $siteroot = $req->notes('siteroot') || '';
                    print $fh $siteroot, $req->uri, $extra, "\t", $req->notes('cache_url'), "\n";
                    $log->debug(" ADDED TO CACHE: " . $req->uri);
                } else {
                    $log->debug("Couldn't lock WEBOBVIUS_CACHE_INDEX-file");
                }
                close FH;
            } else {
                $log->debug("Couldn't write to WEBOBVIUS_CACHE_INDEX-file ($this->{WEBOBVIUS_CACHE_INDEX})");
            }
        }
    }
    $log->debug("Cache file done");
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
