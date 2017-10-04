package Obvius::Hostmap;

########################################################################
#
# Hostmap.pm - Obvius hostmap functionality
#
# Copyright (C) 2001-2006 Magenta Aps, Denmark (http://www.magenta-aps.dk/)
#
# Authors: Jørgen Ulrik B. Krag (jubk@magenta-aps.dk),
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

use strict;
use warnings;

use Obvius::Config;

our $VERSION="1.0";

*new = \&create_hostmap;

sub new_with_obvius {
     my ($class, $obvius, %options) = @_;
     return $class->create_hostmap(
        $obvius->config->param('HOSTMAP_FILE'),
        $obvius->config->param('ROOTHOST'),
        obvius_config => $obvius->config,
        always_https_mode =>
            $obvius->config->param('always_https_mode') ? 1 : 0,
        %options
    );
}

sub create_hostmap {
    my ($this, $path, $roothost, %options) = @_;

    die "$path does not exist" unless(-f $path);
    die "$path is not readable" unless(-r $path);

    my $https_hostmap = $path;
    $https_hostmap =~ s!([^/]+)$!https_$1!;
    if(-s $https_hostmap) {
        $options{https_hostmap} = $https_hostmap;
    }

    my %new = (
                path => $path,
                roothost => $roothost,
                last_change => 0,
                hostmap => {},
                forwardmap => {},
                regexp => '',
                is_https => {},
                obvius_config => $options{obvius_config},
                %options
            );
    my $new = bless(\%new, $this);
    $new->configure_https_mode();
    $new->get_hostmap;

    return $new;
}

=head2 $hostmap->locate_obvius_config($path)

Tries to find the Obvius::Config object associated with the hostmap, store it
in $self and return it.

This is done by assuming the setup.pl file for the Obvius site will be located
in the same folder as the hostmap and that this file will have a line creating
an Obvius::Config object.

=cut
sub locate_obvius_config {
    my ($self, $path) = @_;

    if(ref($self) && $self->{obvius_config}) {
        return $self->{obvius_config};
    }

    $path ||= $self->{path};
    die "No path when looking for config key" unless($path);

    my $conf_file = $path;
    $conf_file =~ s{/[^/]+$}{/setup.pl};
    if(! -f $conf_file) {
        die "Could not find site setup.pl when looking for config key";
    }
    my $conf_key;
    open(FH, $conf_file) or die "Could not open $conf_file for reading";
    while(my $line = <FH>) {
        if($line =~ m{Obvius::Config\(\s*['"]([^'"]+)['"]\s*\)}s) {
            $conf_key = $1;
            last;
        } elsif(
            $line =~ m{Obvius::Config\s*->\s*new\s*\(\s*['"]([^'"]+)['"]\s*\)}s
        ) {
            $conf_key = $1;
            last;
        }
    }
    close(FH);
    if(!$conf_key) {
        die "Could not find config key";
    }
    my $config = Obvius::Config->new($conf_key);
    die "Could not load config" unless($config);

    if(ref($self)) {
        $self->{obvius_config} = $config;
    }
    return $self->{obvius_config};
}

=head2 $hostmap->configure_https_mode()

Ensures that $hostmap->{always_https_mode} is set up according to settings in
the hostmap site's Obvius::Config file.

=cut
sub configure_https_mode {
    my ($self) = @_;

    if(exists $self->{always_https_mode}) {
        return;
    }

    my $config = $self->locate_obvius_config($self->{path});
    $self->{always_https_mode} =
        $config->param('always_https_mode') ? 1 : 0;
}

# sub get_hostmap - Returns the hostmap as a hashref. If the hostmap
#                   is not loaded or the source file have changed the
#                   map will be reloaded.
#
sub get_hostmap {
    my ($this) = shift;

    my $path = $this->{path};

    # If our source file have changed, reload the map:
    my $file_timestamp = (stat $path)[9];
    if($file_timestamp > $this->{last_change}) {
        print STDERR "Reloading hostmap $path\n" if($this->{debug});
        my $siteroot_map = $this->{hostmap} = {};
        $this->{forwardmap} = {};

        open(FH, $path) || die "Couldn't open siteroot file $path";
        my @lines;
        while(<FH>) {
            chomp;
            next if(/^#/);
            next if(/^\s*$/);

            push(@lines, $_);
        }
        close(FH);

        # Now reverse the lines unless a file ${path}.reverse
        # exists. This determines whether the first or last host
        # for a given subsite is used for rewriting urls, which
        # is usefull for test-sites. Note that the default behaviour is
        # to reverse the lines since we want the first line written for
        # a subsite to be the one we rewrite to.
        unless(-f $path . ".reverse") {
            @lines = reverse @lines;
        }

        if(my $https_file = $this->{https_hostmap}) {
            my $is_https = $this->{is_https} = {};
            $this->{https_roothost} = undef;
            open(FH, $https_file)
                or die "Couldn't open https hostmap $https_file";
            my @https_lines;
            while(<FH>) {
                chomp;
                next if(/^#/);
                next if(/^\s*$/);

                if(/^(\S+)\s+(\S+)/) {
                    $is_https->{lc($1)} = $2;
                    if($2 eq '/') {
                        $this->{https_roothost} = $1;
                    } else {
                        $is_https->{lc($2)} = $1;
                        push(@https_lines, $_);
                    }
                }
            }
            die "HTTPS hostmap with no roothost (/) entry" unless(
                $this->{https_roothost}
            );
            unless(-f $path . ".reverse") {
                @https_lines = reverse @https_lines;
            }
            push(@lines, @https_lines);
            # Force some URLs to https:
            for my $uri (qw(/system/login /system/logout)) {
                $is_https->{$uri} = 1;
                $siteroot_map->{$uri} = $this->https_roothost;
            }
        }

        for(@lines) {
            if(/^(\S+)\s+(\S+)/) {
                $siteroot_map->{lc($2)} = $1;
                $this->{forwardmap}->{lc($1)} = $2;
            }
        }

        $this->{regexp} = "^(" . join("|", reverse sort keys %$siteroot_map) . ")";

        $this->{last_change} = $file_timestamp;
    }

    return $this->{hostmap};
}

sub is_https {
    my ($this, $subsite_uri_or_hostname) = @_;

    if($this->{always_https_mode}) {
        return 1;
    }
    
    return $this->{is_https}->{$subsite_uri_or_hostname};
}

sub lookup_is_https {
    my ($this, $url) = @_;

    if($this->{always_https_mode}) {
        return 1;
    }

    # Add last slash in uri if missing
    $url .= '/' unless($url =~ m!/$!);

    if($url =~ m!^https?://(^[/]+)!) {
        return $this->is_https($1);
    } elsif ($url =~ m!^/! and $url =~ m!$this->{regexp}!) {
        return $this->is_https($1);
    } else {
        return $this->is_https($url);
    }
}

sub https_roothost {
    my ($this) = @_;
    if($this->{always_https_mode}) {
        return $this->{roothost};
    } else {
        return $this->{https_roothost} || $this->{roothost};
    }
}

#Finds the longest subsite the uri belongs to.
sub host_uri_belongs_to {
    my ($this, $uri) = @_;

    my ($uri_part) = $uri =~ /$this->{regexp}/i;
    return $uri_part ? $this->{hostmap}{$uri_part} : undef;
}

sub absolute_uri {
    my ($this, $uri) = @_;

    my $host = $this->host_uri_belongs_to($uri);
    $uri =~ s/$this->{regexp}//i if ($host);

    $host ||= $this->{roothost};

    my $candidate = "$host/$uri";
    $candidate =~ s|/+|/|g;

    return $candidate;
}

# sub translate_uri - Given an uri and the current host translates the uri
#                     using the hostmap. The transformation follows these rules:
#                     If a match is found in the hostmap, the part of the uri
#                     that matches is removed. If the matched host does not equal
#                     the current hostname the uri will be prefixed with
#                     http://${new_hostname}. Uris that is not matched by the hostname
#                     will be prefixed with http://${roothost} unless the current
#                     hostname is the roothost.
#                     Returns the translated URL.
sub translate_uri {
    my ($this, $uri, $hostname, $incoming_protocol) = @_;

    my $hostmap = $this->get_hostmap;
    my $roothost = $this->{roothost} || '';
    my $protocol = 'http';
    $hostname ||= $roothost;

    my $new_host = '';
    my $subsiteuri = '';
    my $levels_matched = 0;
    # Always HTTPS mode tells the rewrite system that all URLs should be
    # https, whether or not they actually point to subsites that uses https.
    my $always_https = $this->{always_https_mode};
    if($always_https) {
        $protocol = 'https';
    }

    if($uri =~ m!$this->{regexp}!i) {
        $subsiteuri = $1;
        $new_host = $hostmap->{lc $1};
    }

    my $protocol_mismatch = (
        defined($incoming_protocol) &&
        $incoming_protocol ne $protocol
    );

    if($new_host) {
        my $remove_prefix = 1;
        if($always_https || $this->{is_https}->{$new_host}) {
            $protocol = 'https';
            $remove_prefix = 0 if($new_host eq $this->https_roothost);
        }
        # Remove the subsiteuri from the URI:
        $uri =~ s!^\Q$subsiteuri\E!/!i if($remove_prefix);


        # If hostname is not the same as the current prefix the URI
        # with correct hostname:
        if($new_host ne $hostname or $protocol_mismatch) {
            $uri = $protocol . '://' . $new_host . $uri;
        }
    } else {
        if($hostname ne $roothost) {
            # If we come from a https page, roothost pages should use the
            # https roothost.
            if($always_https || (
                $incoming_protocol and
                $incoming_protocol eq 'https' and
                # Variable instead of method, since method always true
                $this->{https_roothost}
            )) {
                $protocol = 'https';
                $roothost = $this->https_roothost;
            }
            $uri = $protocol .  '://' . $roothost . $uri;
        } elsif($protocol_mismatch) {
            $uri = $protocol . '://' . $hostname . $uri;
        }
    }


    if(wantarray) {
        if($subsiteuri) {
            my @parts = split("/", $subsiteuri);
            $levels_matched = (scalar(@parts) - 1);
        }
        return ($uri, $new_host, $subsiteuri, $levels_matched, $protocol);
    } else {
        return $uri;
    }
}

sub find_host_prefix {
    my ($this, $uri) = @_;

    my ($best_prefix) = $uri =~ /$this->{regexp}/i;

    return $best_prefix;
}

sub host_to_uri {
    my ($this, $host) = @_;

    return $this->{forwardmap}->{lc($host)};
}


# This translates a full URL (with hostname) into a local URI, semilar to how
# the rewriting in apache works. Will return undef if translation is not
# possible.
sub url_to_uri {
    my ($this, $url) = @_;

    if($url =~ m!https?://([^/]+)(.*)!) {
        my $host = $1;
        my $rest = $2;
        if(my $host_uri = $this->host_to_uri($host)) {
            return $host_uri . $rest;
        }
    }
    return undef;
}


# Turns an into a full URL with protocol and hostname. Protocol will be output
# according to the environment settings for https vs non-https.
sub get_full_url {
    my ($this, $uri) = @_;

    my $protocol_in = $ENV{IS_HTTPS} ? 'https' : 'http';

    # Use temporary variable to avoid conflict with wantarray
    my $result = $this->translate_uri($uri, ':bogus:', $protocol_in);
    return $result;
}

1;
