package Obvius::Robot::Politiken;

# $Id$

require 5.005_62;
use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(search_politiken);
our @EXPORT = ();
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

use HTML::Parser ();
use URI;
use URI::Escape;
use POSIX qw(strftime);

use Obvius::Robot;

sub search_politiken {
    my (%options) = @_;

    my $url = q{http://politiken.dk/visartikel.asp?TemplateID=1355&StringOr=};

    $url .= '&StringAnd=' . join('%20', map { uri_escape("\"$_\"") } @{$options{words}});
    $url .= '&StringNot=' . join('%20', map { uri_escape("\"$_\"") } @{$options{stopwords}});

    if ($options{categories}) {
	for (@{$options{categories}}) {
	    $url .= '&Category=' . uri_escape($_);
	}
    }
    # what => HEADING or what => ALL
    $url .= '&What=' . (uc($options{what}) || 'ALL');

    # Seems to work up to 200
    $url .= '&PerPage=' . ($options{max} || '200');

    print STDERR "Search url is «$url»\n" if ($options{debug});

    my $text = retrieve_uri($url);
    return undef unless ($text);

    my $parser = new HTML::Parser(api_version => 3,
				  start_h => [\&start_tag, "self,tagname,text,attr"],
				 );

    if ($options{period}) {
	my $limit = strftime('%Y-%m-%d', localtime(time() - $options{period}*24*60*60));
	print STDERR "LIMIT $limit\n" if ($options{debug});
	$parser->{TIME_LIMIT} = $limit;
    }
    $parser->{KNOWN_DOCS} = $options{known_docs};
    $parser->{DEBUG} = $options{debug};
    $parser->{BASE_URL} = $url;
    $parser->{DOCS} = [];
    $parser->parse($text);

    return $parser->{DOCS};
}

our %monthmap =
    (
     'jan'=>'01', 'feb'=>'02', 'mar'=>'03', 'apr'=>'04',
     'maj'=>'05', 'jun'=>'06', 'jul'=>'07', 'aug'=>'08',
     'sep'=>'09', 'okt'=>'10', 'nov'=>'11', 'dec'=>'12',
    );

sub store_document {
    my $self = shift;

    # Uden en URI, intet dokument
    if ($self->{DOC}->{url} and $self->{DOC}->{docdate} and $self->{DOC}->{title}) {
	unless ($self->{KNOWN_DOCS} and $self->{KNOWN_DOCS}->{$self->{DOC}->{url}}) {
	    $self->{KNOWN_DOCS}->{$self->{DOC}->{url}}++;

	    if ($self->{DOC}->{docdate} =~ /\((\d+)\s+(\w+)\s+(\d+)\)/) {
		$self->{DOC}->{docdate} = sprintf('%04d-%02d-%02d', $3, $monthmap{$2}, $1);
	    } else {
		warn("Failed to recognise date \'$self->{DOC}->{docdate}\'\n");
	    }

	    unless ($self->{TIME_LIMIT} and $self->{DOC}->{docdate} lt $self->{TIME_LIMIT}) {
		print(STDERR "\nSAVING ", $self->{DOC}->{url}, "\n\n")
		    if ($self->{DEBUG} > 1);

		$self->{DOC}->{source} = $self->{source};
		$self->{DOC}->{contributors} = $self->{contributors};

		$self->{DOC}->{title} =~ s/\s+/ /g;
		$self->{DOC}->{title} =~ s/^\s+//;
		$self->{DOC}->{title} =~ s/\s+$//g;

		push(@{ $self->{DOCS} }, $self->{DOC});
	    }
	}
    }

    # Initialiser nyt document
    $self->{DOC} = {};
}

sub start_tag {
    my ($self, $tag, $text, $attr) = @_;

    # print STDERR "$tag $text\n";

    # En lille optimering
    # HUSK AT SYNKRONISERE MED KODEN HERUNDER
    return unless ($tag =~ /^(a|meta|font)$/);

    if ($tag eq 'meta') {
	return unless ($attr->{name});
	$self->{source} = $attr->{content} if ($attr->{name} eq 'publisher');
	$self->{contributors} = $attr->{content} if ($attr->{name} eq 'copyright');
	return;
    }

    if ($tag eq 'a') {
	return if ($attr->{target});
	return unless ($attr->{href} and $attr->{href} =~ m!^/VisArtikel.sasp\?!);
	return unless ($attr->{class} and $attr->{class} eq 'noline');

	$self->{DOC}->{url} = URI->new_abs($attr->{href}, $self->{BASE_URL})->as_string;

	$self->{DOC}->{title} = '';
	$self->handler(text => sub {
			   my $self = shift;
			   $self->{DOC}->{title} .= shift;
		       }, "self,dtext");
	$self->handler(end => sub {
			   my ($self, $tag) = @_;
			   if ($tag eq 'a') {
			       $self->{read_date} = 1;

			       $self->handler(text => '');
			       $self->handler(end => '');
			   }
		       }, "self,tagname");

	$self->{read_date} = 0;
	return;
    }

    return unless ($self->{read_date});

    if ($tag eq 'font') {
	$self->{DOC}->{docdate} = '';
	$self->handler(text => sub {
			   my $self = shift;
			   $self->{DOC}->{docdate} .= shift;
		       }, "self,dtext");
	$self->handler(end => sub {
			   my ($self, $tag) = @_;
			   if ($tag eq 'font') {
			       $self->handler(text => '');
			       $self->handler(end => '');

			       store_document($self);
			   }
		       }, "self,tagname");
    }
}


1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Obvius::Robot::Politiken - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Obvius::Robot::Politiken;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Obvius::Robot::Politiken, created by h2xs. It looks like the
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
