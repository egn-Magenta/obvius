package Obvius::Robot::XMLSimple;

# $Id$

use strict;
use warnings;

our @ISA = qw(Exporter);
our @EXPORT_OK = qw( get_xml_simple );
our @EXPORT = qw();
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

use XML::Simple;
use URI::Escape qw(uri_escape);
use Obvius::Robot qw(retrieve_uri);

sub get_xml_simple {
  my (%options) = @_;

  # URL is required
  my $url = $options{url};
  return undef unless $url;

  # Debug
  my $debug = $options{debug} || 0;
  
  # We assume that the rest of the options are query string args
  # Arguments should be passed here un_urlencoded ...
  my $qs = '';
  foreach (keys %options) {
    next if /^(url|debug)$/;
    if (not $qs) { $qs = '?'; }
    else { $qs .= '&'; }

    $qs .= (uri_escape($_) . "=" . uri_escape($options{$_}) );
  }

  $url .= $qs;
  print STDERR "XML url <<$url>>\n" if ($debug);

  # Retrieve Data
  my $text = retrieve_uri($url);
  unless ($text) {
    print STDERR "No data received from <<$url>>\n";
    return undef;
  }
  print STDERR "--> Data\n$text\n<-- End of Data\n\n" if ($debug > 1);

  # Parse
  my $parser = new XML::Simple;
  return $parser->XMLin($text);
}

1;
