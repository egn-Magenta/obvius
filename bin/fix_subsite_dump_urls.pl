#!/usr/bin/perl

use strict;
use warnings;

use Obvius::Hostmap;
use Getopt::Long;

my ( $source_map, $dest_map, $source_roothost, $dest_roothost, $help, $debug);

GetOptions(
        'source_map=s',   => \$source_map,
        'dest_map=s'        => \$dest_map,
        'source_roothost=s' => \$source_roothost,
        'dest_roothost=s' => \$dest_roothost,
        'help'            => \$help,
        'debug'           => \$debug,
) or usage();

sub usage
{
        print <<EOT;
Usage: fix_subsite_dump_urls.pl [OPTIONS] filename

  --source_map      Path to file containing hostmap for the source site
  --dest_map        Path to file containing hostmap for the destination
                    site
  --source_roothost Roothost for the source site
  --dest_roothost   Roothost for the destination site
  --help            This help
  --debug           Print debug information to STDERR

EOT
        exit 0;
}

usage() if $help or not @ARGV;

die "You must specify a destination map" unless($dest_map);
die "Destination map is not readable" unless(-r $dest_map);

die "You must specify the destination roothost" unless($dest_roothost);
die "You must specify the source roothost" unless($source_roothost);

warn "You haven't specified a source hostmap - can't rewrite subsite URLs from the source." unless($source_map);
if($source_map) {
    die "Source hostmap is not readable" unless(-r $source_map);
}

my %rewrites_from_source;

$rewrites_from_source{"http://" . $source_roothost . "/"} = "/";

if($source_map) {
    my $source_rewritemap = Obvius::Hostmap->create_hostmap($source_map, $source_roothost);
    my $hostmap = $source_rewritemap->{hostmap} || {};

    for(keys %$hostmap) {
        $rewrites_from_source{"http://" . $hostmap->{$_} . "/"} = $_;
    }
}

my $source_rewrite_regexp = "(" . join("|", sort { length($b) <=> length($a) } keys %rewrites_from_source) . ")";

my $dest_rewritemap = Obvius::Hostmap->create_hostmap($dest_map, $dest_roothost);

open(FH, $ARGV[0]) or die "Couldn't open file $ARGV[0]";
while(<FH>) {
    s!$source_rewrite_regexp!$dest_rewritemap->translate_uri($rewrites_from_source{$1})!gei;
    if($1 and $debug) {
        print STDERR "Rewrote $1 to " . $dest_rewritemap->translate_uri($rewrites_from_source{$1} . "\n")
    }
    print $_;
}
close(FH);
