package Obvius::Robot::Infopaq;

use strict;
use warnings;

our @ISA = qw(Exporter);
our @EXPORT_OK = qw( get_infopaq_docs );
our @EXPORT = qw();
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

use XML::Parser;
use URI::Escape;

use POSIX qw(strftime);

use Unicode::String qw(utf8);

use Obvius::Robot;

use Data::Dumper;

our $DEBUG = 0;

sub get_infopaq_docs {
    my (%options) = @_;

    # Set debug;
    $DEBUG = $options{debug};

    # Search url
    my $url = 'http://levering.infopaq.dk/biotikportalen/bioTIKportalen.asp';

    # Limit days
    my $days = $options{days} || 3;
    $url .= "?days=$days";

    print STDERR "Search url is <<$url>>\n" if($DEBUG);

    # retrieve the text
    my $text = retrieve_uri($url);

    print STDERR "No data recieved from <<$url>>\n" unless($text);
    return undef unless($text);

    print STDERR "--> Data Retrieved\n$text\n<--End Of Data\n\n" if ($DEBUG > 2);


    # We get the data as UTF-8 .. convert it
    Unicode::String->stringify_as('latin1');

    my $parser = new XML::Parser (
                                    Handlers => {
                                                    Start => \&starthandler,
                                                    End => \&endhandler,
                                                    Char => \&charhandler,
                                    }
                  );

    # Set some defaults
    $parser->{CURRENT_ELEMENT} = '';

    $parser->{CURRENT_DATA} = '';

    $parser->{DOCS} = [];

    # current doc;
    $parser->{DOC} = {};

    $parser->parse($text);

    return $parser->{DOCS};
}

sub charhandler {
    my ($self, $data) = @_;

    return unless($data);
    my $u = Unicode::String->new($data);
    $u->utf8($data);
    print STDERR "Charhandler: $u\n" if($DEBUG > 2);

    $self->{CURRENT_DATA} .= $u;

}


sub starthandler {
    my ($self, $element, %attr) = @_;

    print STDERR "Starthandler: $element\n" if($DEBUG > 2);
    $self->{CURRENT_ELEMENT} = $element;

}

sub endhandler {
    my ($self, $element) = @_;

    my $u = Unicode::String->new($element);
    $u->utf8($element);

    print STDERR "Endhandler: $u\n" if($DEBUG > 2);

    # Save the element on $parser->{DOC}
    $self->{DOC}->{$u} = $self->{CURRENT_DATA};
    $self->{CURRENT_DATA} = '';

    if($element eq 'medie') {
        my %data;
        for(keys %{ $self->{DOC} }) {
            my $val = $self->{DOC}->{$_};
            $val =~ s/^[\n\r]*//;
            $data{lc($_)} = $val;
        }

        # Add the finished doc
        push(@{ $self->{DOCS} }, \%data);

        # Start on a new one
        $self->{DOC} = {};
    }

}



1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Obvius::Robot::Infopaq - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Obvius::Robot::Infopaq;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Obvius::Robot::Infopaq, created by h2xs. It looks like the
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
