package Obvius::Robot::Berlingske;

########################################################################
#
# Berlingske.pm - Search robot for www.berlingske.dk
#
# Copyright (C) 2000 Magenta Aps, Denmark (http://www.magenta-aps.dk/)
#
# Author: René Seindal (rene@magenta-aps.dk)
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

require 5.005_62;
use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);
our @EXPORT_OK = qw( search_berlingske );
our @EXPORT = qw();
our $VERSION="1.0";

use HTML::Parser ();
use URI;
use URI::Escape;
use POSIX qw(strftime);

use Obvius::Robot;


sub search_berlingske {
    my (%options) = @_;

    my $url = sprintf('http://www.berlingske.dk/soeg?s=%s&s_o=1&s_a=1',
		      join('%20', map { uri_escape($_) } @{$options{words}}));

    print STDERR "Search url is «$url»\n" if ($options{debug});

    my $text = retrieve_uri($url);
    return undef unless ($text);

    my $parser = new HTML::Parser(api_version => 3,
				  start_h => [\&start_tag, "self,tagname,text,attr"],
				  end_h   => [\&end_tag, "self,tagname,text"],
				  comment_h   => [\&comment_tag, "self,text"],
				 );

    if ($options{period}) {
	my $limit = strftime('%Y-%m-%d', localtime(time() - $options{period}*24*60*60));
	$parser->{TIME_LIMIT} = $limit;
    }
    $parser->{KNOWN_DOCS} = $options{known_docs};
    $parser->{DEBUG} = $options{debug};
    $parser->{BASE_URL} = $url;

    $parser->{DOCS} = [];
    $parser->{ACTIVE} = 0;

    $parser->parse($text);

    return $parser->{DOCS} unless ($options{stopwords} and @{$options{stopwords}});

    use Data::Dumper;

    return [
	    grep {
		my $stop = 0;
		for my $s (@{$options{stopwords}}) {
		    $stop++ if (index($_->{title}, $s) >= 0 or index($_->{teaser}, $s) >= 0);
		}
		# This was reversed?!?!
		$stop ? 0 : 1;
	    } @{$parser->{DOCS}}
	   ];
}

sub store_document {
    my $self = shift;

    # Uden en URL, intet dokument
    if ($self->{DOC}->{url} and $self->{DOC}->{title} and $self->{DOC}->{teaser}) {
	unless ($self->{KNOWN_DOCS} and $self->{KNOWN_DOCS}->{$self->{DOC}->{url}}) {
	    $self->{KNOWN_DOCS}->{$self->{DOC}->{url}}++;

	    $self->{DOC}->{docdate} = get_article_date($self->{DOC}->{url}) || '0000-01-01';

	    unless ($self->{TIME_LIMIT} and $self->{DOC}->{docdate} lt $self->{TIME_LIMIT}) {
		print(STDERR "\nSAVING ", $self->{DOC}->{url}, "\n")
		    if ($self->{DEBUG} > 1);

		$self->{DOC}->{title} =~ s/\s+/ /g;
		$self->{DOC}->{title} =~ s/^\s+//;
		$self->{DOC}->{title} =~ s/\s+$//g;

		$self->{DOC}->{teaser} =~ s/\s+/ /g;
		$self->{DOC}->{teaser} =~ s/^\s+//;
		$self->{DOC}->{teaser} =~ s/\s+$//g;

		push(@{ $self->{DOCS} }, $self->{DOC});
	    }
	}
    }

    # Initialiser nyt document
    $self->{DOC} = {};
}

sub comment_tag {
    my ($self, $text) = @_;

    if ($text eq '<!-- Template c_soeg begin -->') {
        $self->{ACTIVE} = 1;
    } elsif ($text eq '<!-- Template c_soeg end -->') {
	$self->eof;
    }
}

sub start_tag {
    my ($self, $tag, $text, $attr) = @_;

    return unless $self->{ACTIVE};

    #print STDERR "START $tag $text\n";

    # En lille optimering
    # HUSK AT SYNKRONISERE MED KODEN HERUNDER
    return unless ($tag =~ /^(span|a)$/);

    if ($tag eq 'span') {
	if ($attr->{class} eq 'header02') {
	    $self->handler(text => sub {
			       my $self = shift;
			       $self->{DOC}->{title} .= shift;
			   }, "self,dtext");
	    $self->{DOC}->{title} = '';
	    return;
	}
	if ($attr->{class} eq 'summary') {
	    $self->handler(text => sub {
			       my $self = shift;
			       $self->{DOC}->{teaser} .= shift;
			   }, "self,dtext");
	    $self->{DOC}->{teaser} = '';
	    return;
	}
	return;
    }

    if ($tag eq 'a' and ($attr->{href} || '') =~ m!^/artikel:aid! ) {
	$self->{DOC}->{url} = URI->new_abs($attr->{href}, $self->{BASE_URL})->as_string;
	store_document($self);
	return;
    }
}

sub end_tag {
    my ($self, $tag, $text) = @_;

    return unless $self->{ACTIVE};

    #print STDERR "END $tag $text\n";

    # En lille optimering
    # HUSK AT SYNKRONISERE MED KODEN HERUNDER
    return unless ($tag =~ /^(span)$/);

    # Fjern text handleren, hvis vi var ved at læse dokumentets titel
    $self->handler(text => '');
}


########################################################################
#
#	Separat parser for at få datoen
#
#########################################################################

sub get_article_date {
    my ($uri) = @_;

    #print STDERR "get_article_date $uri\n";

    my $text = retrieve_uri($uri);
    return undef unless ($text);

    my $parser = new HTML::Parser(api_version => 3,
				  start_h => [\&date_start_tag, "self,tagname,text,attr"],
				 );
    $parser->parse($text);

    #print STDERR "get_article_date in: ", $parser->{DATE}, "\n";

    my %month = (
		 januar => 1,
		 februar => 2,
		 marts => 3,
		 april => 4,
		 maj => 5,
		 juni => 6,
		 juli => 7,
		 august => 8,
		 september => 9,
		 oktober => 10,
		 november => 11,
		 december => 12,
		);

    if ($parser->{DATE} and $parser->{DATE} =~ /(?:dag|den|de)\s+(\d+)\.?\s*(\w+)\s+(\d+)/) {
	my $year = $3;
	$year += 1900 if $year < 1900;

	my $date = sprintf('%04d-%02d-%02d', $year, $month{$2}, $1);

	#print STDERR "get_article_date out: $date\n";

	return $date;
    }

    $parser->{DATE} ||= '<NULL>';
    print STDERR "Berlingske: date \"$parser->{DATE}\" not recognised\n\t<$uri>\n";

    return undef;
}

sub date_start_tag {
    my ($self, $tag, $text, $attr) = @_;

    if ($tag eq 'p' and $attr->{class} and $attr->{class} eq 'source') {
	$self->handler(text => sub {
			   my $self = shift;
			   $self->{DATE} .= shift;
		       }, "self,dtext");
	$self->handler(end => sub {
			   my $self = shift;
			   $self->eof;
		       }, "self");
	$self->{DATE} = '';
	return;
    }
}



1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Magenta::NormalMgr::Robot::Berlingske - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Magenta::NormalMgr::Robot::Berlingske;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Magenta::NormalMgr::Robot::Berlingske, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head2 EXPORT

None by default.


=head1 AUTHOR

A. U. Thor, a.u.thor@a.galaxy.far.far.away

=head1 SEE ALSO

perl(1).

=cut
