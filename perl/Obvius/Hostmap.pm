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

our $VERSION="1.0";

*new = \&create_hostmap;

sub new_with_obvius {
     my ($class, $obvius) = @_;
     return $class->create_hostmap($obvius->{OBVIUS_CONFIG}{HOSTMAP_FILE}, $obvius->{OBVIUS_CONFIG}{ROOTHOST});
}

sub create_hostmap {
    my ($this, $path, $roothost, %options) = @_;

    die "$path does not exist" unless(-f $path);
    die "$path is not readable" unless(-r $path);

    my %new = (
                path => $path,
                roothost => $roothost,
                last_change => 0,
                hostmap => {},
                regexp => '',
                %options
            );
    my $new = bless(\%new, $this);
    $new->get_hostmap;

    return $new;
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


        for(@lines) {
            if(/^(\S+)\s+(\S+)/) {
                $siteroot_map->{lc($2)} = $1;
            }
        }

        $this->{regexp} = "^(" . join("|", reverse sort keys %$siteroot_map) . ")";

        $this->{last_change} = $file_timestamp;
    }

    return $this->{hostmap};
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
    my ($this, $uri, $hostname) = @_;

    my $hostmap = $this->get_hostmap;
    my $roothost = $this->{roothost} || '';
    $hostname ||= $roothost;

    my $new_host = '';
    my $subsiteuri = '';
    my $levels_matched = 0;

    if($uri =~ m!$this->{regexp}!i) {
	 $subsiteuri = $1;
	 $new_host = lc $hostmap->{lc $1};
    }

    if($new_host) {
        # Remove the subsiteuri from the URI:
        $uri =~ s!^\Q$subsiteuri\E!/!i;

        # If hostname is not the same as the current prefix the URI
        # with correct hostname:
        if($new_host ne $hostname) {
            $uri = 'http://' . $new_host . $uri;
        }
    } else {
        if($hostname ne $roothost) {
            $uri = 'http://' . $roothost . $uri;
        }
    }


    if(wantarray) {
        if($subsiteuri) {
            my @parts = split("/", $subsiteuri);
            $levels_matched = (scalar(@parts) - 1);
        }
        return ($uri, $new_host, $subsiteuri, $levels_matched);
    } else {
        return $uri;
    }
}

sub find_host_prefix {
     my ($this, $uri) = @_;
     
     my ($best_prefix) = $uri =~ /$this->{regexp}/i;
     
     return $best_prefix;
}

1;
