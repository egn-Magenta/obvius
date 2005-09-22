package WebObvius::Site::MultiMason;

########################################################################
#
# MultiMason.pm - ?
#
# Copyright (C) 2004-2005 Magenta Aps, Denmark (http://www.magenta-aps.dk/)
#
# Authors: Jørgen Ulrik B. Krag <jubk@magenta-aps.dk>
#          Adam Sjøgren <asjo@magenta-aps.dk>
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

use WebObvius::Site::Mason;
use Obvius::MultiSite;

use Apache::Constants qw(:common :methods :response);

use Digest::MD5 qw(md5_hex);

use Fcntl ':flock';

our @ISA = qw( WebObvius::Site::Mason );
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

# Note that this method is meant to override the one in WebObvius::Site:

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

# can_use_cache - Check if the given request is fit for being cached or not.
#                 Note: this method overrides the one in WebObvius::Site::Mason
sub can_use_cache {
    my ($this, $req, $output) = @_;

    my $obvius=$req->pnotes('obvius');
    $output ||= $req->pnotes('OBVIUS_OUTPUT');

    return '' if ($output && $output->param('OBVIUS_SIDE_EFFECTS'));
    return '' if ($req->no_cache);
    return '' unless ($req->method_number == M_GET);
    return '' unless ($this->{WEBOBVIUS_CACHE_INDEX} and
                        $this->{WEBOBVIUS_CACHE_DIRECTORY});
    return '' if($req->dir_config('WEBOBVIUS_NOCACHE'));
    return '' if (-e $this->{WEBOBVIUS_CACHE_INDEX} . "-off");

    my $vdoc=$output->param('version');
    my $lang=$vdoc->Lang || 'UNKNOWN'; # Should always be there

    my $content_type = $req->content_type;
    return '' unless ($content_type =~ s|^([a-zA-Z0-9.-]+/[a-zA-Z0-9.-]+).*|$1|);
                                            # Not really the RFC2045 definition but should work most of the time
    $req->content_type($content_type);

    my $siteroot = $obvius->{SITEROOT} || '';

    my $id = md5_hex($siteroot . $req->the_request);
    $id .= '.gz' if ($req->notes('gzipped_output'));

    $req->notes('cache_id' => $id);
    $req->notes('cache_dir' => join '/', $this->{WEBOBVIUS_CACHE_DIRECTORY}, $lang, $req->content_type, substr($id, 0, 2));
    $req->notes('cache_file' => $req->notes('cache_dir') .  '/' . $id);
    $req->notes('cache_url' => join '/', '/cache', $lang, $req->content_type, substr($id, 0, 2), $id);

    Obvius::log->debug("Cache file name %s\n", $req->notes('cache_file'));
    return 1;
}


# save_in_cache - Saves the data in $s in the document cache.
#                 can_use_cache should always be called before calling this method.
#                 Note: this method overrides the one in WebObvius::Site::Mason
sub save_in_cache {
    my ($this, $req, $s) = @_;

    my $obvius=$req->pnotes('obvius');

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
        if ($qstring and $qstring =~ /^size=\d+x\d+$/) {
            $extra = $qstring;
        }

        # Perhaps move this check up, so nothing is written to disk if the cache is off?
        # Add to cache-db
        $fh = new Apache::File('>>' . $this->{WEBOBVIUS_CACHE_INDEX});
        if (open FH, '>>', $this->{WEBOBVIUS_CACHE_INDEX}) {
            if (flock FH, LOCK_EX|LOCK_NB) {
                my $siteroot = $obvius->{SITEROOT} || '';
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
    $log->debug("Cache file done");
}


1;
__END__
=head1 NAME

WebObvius::Site::MultiMason - ?

=head1 SYNOPSIS

  ?

=head1 DESCRIPTION

?

=head1 AUTHORS

Jørgen Ulrik B. Krag E<lt>jubk@magenta-aps.dkE<gt>
Adam Sjøgren E<lt>asjo@magenta-aps.dkE<gt>

=head1 SEE ALSO

L<WebObvius::Site>, L<WebObvius::Site::Mason>.

=cut
