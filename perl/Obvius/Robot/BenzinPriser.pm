package Obvius::Robot::BenzinPriser;

# Get XML data from Infomarked
# Jason Armstrong <ja@riverdrums.com>
#
# $Id$


use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(get_benzinpriser_xml);
our @EXPORT = ();
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

use XML::Parser;
use URI::Escape;
use Obvius::Robot;


##############################################
# 
# Get the data from the website, and return an
# array of documents for further processing
#   Options: url, debug
#
##############################################

sub get_benzinpriser_xml {
  my (%options) = @_;

  # Where the XML is coming from
  my $url = $options{url} || 'http://benzinguide.infomarked.dk/xml/benzinpriser.xml';

  # We also have a debug option, passed into this method
  print STDERR "Benzinpriser url «$url»\n" if ($options{debug});

  # Get the data from the website
  my $text = retrieve_uri($url);
  print STDERR "No data retrieved from website «$url»\n" unless $text;
  return undef unless ($text);

  my $parser = new XML::Parser (
                    Handlers => {
                        Start => \&sthndl,
                        End => \&endhndl,
                        Char => \&chrhndl,
                      }
                  );

  $parser->{CURR_ID} = 0;
  $parser->{CURR_EL} = undef;
  $parser->{DEBUG} = $options{debug};

  # array of documents that we return
  $parser->{DOCS} = [];

  # Work
  $parser->parse($text);

  if ($options{debug} > 1) {
    use Data::Dumper; print STDOUT Dumper $parser->{DOCS};
  }

  return $parser->{DOCS};
}


# Start handler

sub sthndl {
  my $xp = shift;
  my $el = shift;

  $xp->{CURR_EL} = $el;
  if ($el eq 'BenzinguideRegionalPriser') {
    $xp->{CURR_ID} = $el;
  }

  # This section deals with attributes within each element
  if (@_) {
    my %atts = @_;
    my @ids = sort keys %atts;
    foreach my $id (@ids) {
      my $val = $xp->xml_escape($atts{$id}, '"', "\x9", "\xA", "\xD");

      # We are only interested in the ID element of the data
      if ($id eq 'ID') {
        $xp->{CURR_ID} = $val;
      }
    }
  }
}

# End handler

sub endhndl {
  my ($xp, $el) = @_;

  $xp->{CURR_EL} = undef;

  if ($el eq 'BenzinselskabsID' || $el eq 'BenzinguideRegionalPriser') {
    $xp->{CURR_ID} = 0;

    # Add to our array
    push ( @{ $xp->{DOCS} }, $xp->{DOC} );

    # New document
    $xp->{DOC} = {};
  }
}


# Character handler

sub chrhndl {
  my ($xp, $data) = @_;

  chomp $data;
  return undef unless $data;

  if ($xp->{CURR_ID} and $xp->{CURR_EL}) {
    $xp->{DOC}->{$xp->{CURR_ID}}->{$xp->{CURR_EL}} .= $data;
  }
}


1;
__END__

==head1 NAME

Obvius::Robot::BenzinPriser

=head1 SYNOPSIS

  use Obvius::Robot::BenzinPriser qw(get_benzinpriser_xml);

  my $text = get_benzinpriser_xml('http://foo.bar.com/xml');

=head1 AUTHOR

Jason Armstrong E<lt>ja@riverdrums.comE<gt>

=head1 SEE ALSO

L<perl>

=cut
