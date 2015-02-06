package Obvius::DocType::Proxy;

########################################################################
#
# Proxy.pm - document type that proxies one or more external pages.
#
# Copyright (C) 2004 Magenta Aps, Denmark (http://www.magenta-aps.dk/)
#
# Author: Adam Sjøgren (asjo@magenta-aps.dk)
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
use Data::Dumper;

use Obvius;
use Obvius::DocType;

use LWP::UserAgent;
use HTML::Parser;
use URI;
use URI::Escape;

use Encode;

our @ISA = qw( Obvius::DocType );
our $VERSION="1.0";

# This is a bit of a mess, these things get added to input, and there
# is no way to tell them apart from incoming variables, so we strip
# them, but we don't know if we strip enough, when more stuff gets
# added to the input-object:
my %incoming_variables_prune=(
                              NOW=>1,
                              IS_ADMIN=>1,
                              THE_REQUEST=>1,
                              REMOTE_IP=>1,
                              OBVIUS_HEADERS_IN=>1,
                              OBVIUS_COOKIES=>1,
			      OBVIUS_RELURL => 1,
			      OBVIUS_ORIGIN_IP => 1
                             );

# action - retrieves and handles the url to be proxied. Returns
#          OBVIUS_OK when done.
sub action {
    my ($this, $input, $output, $doc, $vdoc, $obvius) = @_;

    $obvius->get_version_fields($vdoc, [qw(url prefixes)]);
    my $base_url=$vdoc->field('url');
    my $prefixes=[
                  grep { defined $_ and length $_ > 0 }
                  map { s/^\s*//; s/\s*$//; $_ }
                  split /\n/, ($vdoc->field('prefixes') || '')
                 ];
    $output->param(prefixes=>$prefixes);

    # Check for loop; return immediately if detected:
    #  XXX Set protocol/version automati/dynamically?
    my $via='HTTP/1.1 ' . $obvius->config->Sitename . ' (Obvius::DocType::Proxy ' . $VERSION . ')';
    if (!check_via_ok($input, $via)) {
        $output->param('OBVIUS_HEADERS_OUT'=>{ Via=>$input->param('OBVIUS_HEADERS_IN')->{Via} });;
        $output->param('via_loop_detected'=>1);
        return OBVIUS_OK;
    }

    # Get fetch_url:
    my $incoming_url = $input->param('obvius_proxy_url');
    my $fetch_url = $incoming_url || $base_url;
    $fetch_url =~ s/%([a-f0-9]{2})/chr hex $1/gei;

    # If additional parameters are set we add them to the URL:
    my $additional_parameters=$input->param('obvius_relurl');
    if (!$incoming_url && defined($additional_parameters)) {
	my @newparams;

        foreach my $key ($input->param()) {
            next if ($incoming_variables_prune{$key});

	    my $val = $input->param($key);
	    next unless(defined($val));

	    $val = [ $val ] unless(ref($val));
	    $key = lc($key);

	    foreach my $v (@$val) {
		push(@newparams, [ $key => $v ]);
	    }
        }

	if(@newparams) {
	    $fetch_url = $base_url .
		(($base_url =~ m{[?]}) ? '&' : '?') .
		join("&",
		    map { $_->[0] . "=" . uri_escape($_->[1]) } @newparams
		);
	}
    }

    $output->param(url=>$fetch_url);

    # Check whether fetch_url is within what we are allowed to proxy:
    if (!check_url_against_prefixes($fetch_url, [ $base_url, @$prefixes ])) {
        $output->param('error'=>'URL to be fetched is outside the allowed range for this proxy-document. Nothing fetched.');
        warn "URL $fetch_url to be fetched is outside the allowed range $base_url @$prefixes. Nothing fetched.";
        return OBVIUS_OK;
    }

    # Do request:
    my $response=make_request($fetch_url, $via, $input, $output, $obvius);
    unless ($response) {
        $output->param(error=>'Can not handle request');
        return OBVIUS_OK;
    }

    # Filter content if it is a type we feel know:
    if ($response->headers->header('content-type')=~m!^text/(html|xml|xhtml|plain)!) {
        my $content = $response->content;

        # First, figure out which encoding it is in:
        my ($encoding) = ($response->headers->header('content-type') =~ m!charset\s*=\s*([\w\d-]+)!);
        ($encoding) = ($response->content =~ m!charset\s*=\s*([\w\d-]+)!) unless($encoding);
        $encoding = 'iso-8859-1' unless($encoding and Encode::find_encoding($encoding));

        # Now decode into perl's format and convert anything that is not supported to HTML entities
        $content = Encode::decode($encoding, $content, Encode::FB_HTMLCREF);

        # Convert to ascii with HTML entities for all wide characters
        $content = Encode::encode("ascii", $content, Encode::FB_HTMLCREF);

        # Filter content
        $content = filter_content($content, $fetch_url, $base_url, $prefixes, $encoding);

        # Output should still be ascii with entities
        $output->param(proxy_content=>$content);
    }
    elsif ($response->is_success) {
        # Success, but we don't know how to filter the page, so
        # redirect to the actual url:
        $output->param(redirect=>$fetch_url);
        $output->param(status=>301);
        return OBVIUS_OK;
    }

    # Take care of the result of the request:
    handle_response($response, $fetch_url, $base_url, $prefixes, $via, $output);

    return OBVIUS_OK;
}

# check_via_ok - given the input-object and our own via-line, checks
#                whether the via-line is included in the incoming
#                Via-hader. Returns true if it isn't, false if it is.
sub check_via_ok {
    my ($input, $via)=@_;

    my $header_via=$input->param('OBVIUS_HEADERS_IN')->{Via};

    # XXX This is an odd way of (an attempt at) finding a substring
    #     within a string:              escape any [ and ]'s:
    my $pattern='[' . (join "][", map { s/\[/\\[/; s/\]/\\]/; $_ } split '', $via) . ']';
    return (defined $header_via ? $header_via!~m/$pattern/i : 1);
}

# filter_content - given the url-string, prefixes linefeed-delimited
#                  string and content-string, filters the HTML, and
#                  changes the attributes to have links function as
#                  they should.
#
#                  Only the HTML inside the body-element is returned
#                  (and considered).
#
#                  The actual filtering of attributes is done in
#                  start_element() below.
#
#                  The rest of the stuff is basically just putting the
#                  split-up back together again.
#
#                  The filtered content is collected inside the
#                  parser-object, also that is where state is kept
#                  (whether inside body or not).
sub filter_content {
    my ($content, $fetch_url, $base_url, $prefixes, $encoding)=@_;

    my $parser=HTML::Parser->new(
                                 api_version=>3,
                                 start_h=>[ \&start_element, 'self, tagname, attr, attrseq' ],
                                 end_h=>[ \&end_element, 'self, tagname' ],
                                 default_h=>[ \&catch_all, 'self, text' ],
                                 unbroken_text=>1,
                                );

    $parser->{OBVIUS_OUTPUT}='';
    $parser->{OBVIUS_IN_BODY}=0;
    $parser->{OBVIUS_FETCH_URL}=$fetch_url;
    $parser->{OBVIUS_BASE_URL}=$base_url;
    $parser->{OBVIUS_PREFIXES}=$prefixes;
    $parser->{OBVIUS_URL_ENCODING}=$encoding;
    my $ret=$parser->parse($content);
    $parser->eof;

    my $filtered_content;
    if ($ret) {
        $filtered_content=$parser->{OBVIUS_OUTPUT};
    }
    else {
        my $warning=__PACKAGE__ . ' HTML-parser failed, returning unfiltered output.';
        warn $warning;
        $filtered_content='<!-- ' . $warning . ' -->' . $content;
    }

    return $filtered_content;
}

# start_element - called by HTML::Parser everytime a new element is
#                 encountered. Attributes are filtered and the,
#                 possibly changed, text is stored - if we are inside
#                 the (/a) body-element.
sub start_element {
    my ($self, $tagname, $attr, $attrseq)=@_;

    if ($tagname eq 'body') {
        $self->{OBVIUS_IN_BODY}=1;
        return;
    }

    return unless $self->{OBVIUS_IN_BODY};

    if ( lc($tagname) eq 'form' ) {
	if ( lc($self->{OBVIUS_URL_ENCODING}) eq 'iso-8859-1' ) {
	    #### Setup ISO-8859-1 character set on appropriate form attributes
	    push(@$attrseq, 'accept-charset') if (! exists($attr->{'accept-charset'}) );
	    $attr->{'accept-charset'} = 'ISO-8859-1';
	    if ( ! exists($attr->{'onsubmit'}) ) {
		push(@$attrseq, 'onsubmit');
		$attr->{'onsubmit'} = "document.charset = 'ISO-8859-1'";
	    } else {
		my $curJS = $attr->{'onsubmit'};
		$attr->{'onsubmit'} = "var rEtUrNvAl = (function() {$curJS})(); document.charset = 'ISO-8859-1'; return rEtUrNvAl;";
	    }
	}
    }

    $self->{OBVIUS_OUTPUT}.='<' . $tagname;

    my @out_attrs=();
    my $add_last=undef;
    foreach my $name (@$attrseq) {
        if ($name eq '/') { # Special case, apparantly HTML::Parser don't know short elements!
            $add_last=' /';
            next;
        }

        my $value=filter_attribute($tagname, $name, $attr->{$name}, $self->{OBVIUS_FETCH_URL}, $self->{OBVIUS_BASE_URL}, $self->{OBVIUS_PREFIXES});

        my $delim=($value=~/[\"]/ ? "'" : '"');
        push @out_attrs, $name . '=' . $delim . $value . $delim;
    }
    $self->{OBVIUS_OUTPUT}.=' ' . (join ' ', @out_attrs) if (scalar(@out_attrs));
    $self->{OBVIUS_OUTPUT}.=$add_last if (defined $add_last);
    $self->{OBVIUS_OUTPUT}.='>';
}

# These attributes on these elements contain links that should be
# absolutified (1) and absolutified+proxied (2):
my %filter_attributes_elements=(
                                href    =>{ a=>2, area=>2 },
                                src     =>{ img=>1, input=>1 },
                                longdesc=>{ img=>2 },
                                action =>{ form=>2 },  # May need extra handling
                                                       # (if params in action, when
                                                       # method is post, is a problem)
                                usemap  =>{ img=>2, input=>2 },
                               );

# filter_attribute - given an element-name, attribute-name and -value
#                    and the urls and prefixes in play changes the
#                    attribute according to the table
#                    filter_attribute_elements.
sub filter_attribute {
    my ($tagname, $name, $value, $fetch_url, $base_url, $prefixes)=@_;

    my $elements=$filter_attributes_elements{$name};
    if ($elements and $elements->{$tagname}) {
        my $orig=$value;
        if ($elements->{$tagname}>1) { # Proxy:
            $value=absolutify_and_proxy($value, $fetch_url, $base_url, $prefixes);
        }
        else {
            # Only absolutify:
            $value=absolutify($value, $fetch_url);
        }
        #print STDERR "$tagname $name = ( $orig -> $value )\n" if ($orig ne $value);
    }
    else {
        # No filtering
    }

    return Encode::encode("ascii", $value, Encode::FB_HTMLCREF);
}

# absolutify - given a (full, absolute, relative) url and the url of
#              the fetched page, returns the full url.
sub absolutify {
    my ($url, $fetch_url)=@_;

    my $uri=URI->new_abs($url, $fetch_url);
    my $abs=$uri->as_string;

    return $abs;
}

# absolutify_and_proxy - given a (full, absolute, relative) url, the
#                        url of the fetched page and information about
#                        base_url and prefixes, returns the absolute
#                        url, perhaps rewritten to a proxy-argument,
#                        if it matches the base_url or one or more of
#                        the prefixes.
sub absolutify_and_proxy {
    my ($url, $fetch_url, $base_url, $prefixes)=@_;

    $url=absolutify($url, $fetch_url);

    # Now, if the uri matches $base_url or one of the prefixes,
    # change it to ./?obvius_proxy_url=$uri
    if (check_url_against_prefixes($url, [$base_url, @$prefixes])) {
        # Don't escape the anchor part of the URL if present:
        my $anchor = '';
        if($url =~ s!(#[^#]+)$!!) {
            $anchor = $1;
        }
        $url='./?obvius_proxy_url=' . uri_escape($url) . $anchor;
    }

    return $url;
}

# check_url_against_prefixes - given a full url and an array-ref to
#                              prefixes, checks whether the url
#                              matches at least one prefix. Returns
#                              true if so, otherwise false.
sub check_url_against_prefixes {
    my ($url, $prefixes)=@_;

    foreach my $prefix (@$prefixes) {
        return 1 if (lc(substr($url, 0, length($prefix))) eq lc($prefix));
    }

    return 0;
}

# end_element - called by HTML::Parser whenever the end of an element
#               is reached. Keeps track of whether we are inside the
#               (a) body element.
sub end_element {
    my ($self, $tagname)=@_;

    if ($tagname eq 'body') {
        $self->{OBVIUS_IN_BODY}=0;
    }

    return unless $self->{OBVIUS_IN_BODY};

    $self->{OBVIUS_OUTPUT}.='</' . $tagname . '>';
}

# catch_all - called by HTML::Parser for everything that isn't covered
#             by other handlers (start_element, end_element). Outputs
#             the (decoded) text if inside the body element.
sub catch_all {
    my ($self, $dtext)=@_;

    return unless $self->{OBVIUS_IN_BODY};

    $self->{OBVIUS_OUTPUT}.=$dtext if (defined $dtext);
}

# These are the headers that are passed from the client on to the
# server (everything else is stripped):
my %client_to_proxy_headers=(
                             'user-agent'=>1,       # Lowercase for simple comparison
                             'accept'=>1,
                             'accept-language'=>1,
                             'accept-charset'=>1,
                             # 'cookie'=>1, # XXX For cookies not to bleed, handling is necessary!
                             'cache-control'=>1,
                             'via'=>1,
                             );

# make_request - given a url, a via-line and the input- and
#                output-objects, constructs and sends the request to
#                the url. POST and GET methods are handled. Returns a
#                response-object if successful, otherwise returns
#                undef.
sub make_request {
    my ($url, $via, $input, $output, $obvius)=@_;

    # Read headers from the hashref $input->param('OBVIUS_HEADERS_IN');
    my %headers_to_external_server=();
    foreach my $header (keys %{$input->param('OBVIUS_HEADERS_IN')}) {
        $headers_to_external_server{$header}=$input->param('OBVIUS_HEADERS_IN')->{$header} if ($client_to_proxy_headers{lc($header)});
    }
    # Add to via:
    $headers_to_external_server{Via}=(exists $headers_to_external_server{Via} ? $headers_to_external_server{Via} . ', ' . $via : $via);


    # User-Agent, Request, Response:
    my $ua=LWP::UserAgent->new(
                               agent=>'Obvius::DocType::Proxy ' . $VERSION,
                               requests_redirectable=>[],
                               parse_head=>0,
                               protocols_forbidden=>[qw(mailto file)],
                               max_size=>4*1024*1024,
                              );

    my %headers=map { $_=>$headers_to_external_server{$_} } keys %headers_to_external_server;

    # XXX Check ua->is_protocol_supported

    my $response;
    my $request_method=$ENV{REQUEST_METHOD};
    if ($request_method eq 'POST') { # Transfer incoming formdata
        my %formdata;
        foreach my $key ($input->param()) {
            next if ($incoming_variables_prune{$key});
            $formdata{lc($key)}=$input->param($key); # XXX lowercasing the key here, because we do
                                                     #     not have the original "casing" available!
                                                     #     Potential hard-to-figure-out problem!!
        }

        $response=$ua->post($url, \%formdata, %headers);
    }
    elsif ($request_method eq 'GET') { # It's all in the URL, so it will be passed
        $response=$ua->get($url, %headers);
    }
    else {
        warn "Unknown request method \"$request_method\", aborting";
        return undef;
    }

    return $response;
}

# These are the headers that are removed from the response from the
# url, when passing them back to the client:
my %proxy_to_client_headers_prune=(
                                   'content-length'=>1,
                                   'connection'=>1,
                                   'accept-ranges'=>1,
                                   'date'=>1,
                                   'set-cookie'=>1, # XXX For cookies not to cross-pollenate
                                                    #     special handling will be required
                                  );

# handle_response - given a response-object and information about
#                   urls, via and the output-object, checks the status
#                   of the request - handles the headers to be
#                   returned, redirects if need be or returns an
#                   error-code if relevant. Doesn't return anything
#                   directly, but put things on the output-object.
sub handle_response {
    my ($response, $url, $base_url, $prefixes, $via, $output)=@_;

    # XXX Check "Client-Aborted" (if size is too big)

    if ($response->is_success) {
        # Set resulting headers by creating the hashref
        # $output->param('OBVIUS_HEADERS_OUT');

        my %headers_to_client=();
        $response->headers->scan( sub { my ($h, $v)=@_; $headers_to_client{$h}=$v unless ($h=~/^Client/ or $proxy_to_client_headers_prune{lc($h)}); } );

        if (exists $headers_to_client{Server}) {
            $headers_to_client{'X-Original-Server'}=$headers_to_client{Server};
            delete $headers_to_client{Server};
        }
        $headers_to_client{Via}=(exists $headers_to_client{Via} ? $headers_to_client{Via} . ', ' . $via : $via);

        $headers_to_client{Warning}='Includes part of ' . $url;
        $output->param('OBVIUS_HEADERS_OUT'=>\%headers_to_client);
    }
    else {
        # XXX Should perhaps signal that no caching should be done?
        my $status=$response->code();
        if ($status==403) { # Forbidden
            if ($response->headers->header('via')) {
                # If there is a Via-header, it's probably why we got a Forbidden; loop:
                $output->param(error=>'403 Proxying of a proxy-document detected');
            }
            else {
                $output->param(error=>'403 Forbidden');
            }
        }
        elsif ($status==404) { # Not found
            $output->param(error=>'404 Not Found');
        }
        elsif ($status==301 or $status==302 or $status==303 or $status==307) {
            # Moved permanently, Found, See other, Temporary Redirect
            #  XXX Read rfc to check semantics.
            my $location=absolutify_and_proxy($response->headers->header('location'), $url, $base_url, $prefixes);
            $output->param(redirect=>$location);
            $output->param(status=>$response->code);
        }
        else {
            $output->param(error=>$status . ' Unhandled error');
        }
    }
}

1;
__END__

=head1 NAME

Obvius::DocType::Proxy - Perl module implementing a proxy document type.

=head1 SYNOPSIS

  used automatically by Obvius.

=head1 DESCRIPTION

A document of this type has two important fields used for the
functionality implemented:

 url      - one line
 prefixes - zero or more lines

When the document is displayed, it tries to fetch the page pointed to
by url.

If successful, the content is filtered, links that either match url or
one or more of the prefixes are rewritten to point to the
Proxy-document with the real url as an argument.

If there is an argument pointing to a real url, and that url matches
url or one or more of the prefixes, that url is fetched instead.

If the url to be fetched returns a redirect instruction, that new url
is handled as well (if it is within etc. etc.).

Relevant headers are proxied forth and back, and a Via-header is used
to detect, and break, proxying of Proxy-documents.

=head1 CAVEATS

Cookies are stripped, both ways. This is to prevent cross-pollenation
- cookies are set based on hostname (and, optionally, path), but if
you have multiple Proxy-documents on the same website, the hostname is
the same and you potentially send cookies from one site to another;
not good at all.

Filtering is performed only if the content-type is one that the
Proxy-documenttype feels it can handle. If it can't, Proxy.pm
redirects to the real url instead. (This is probably always desired
behaviour; when we don't know how to filter a, say, PDF-document, it
is better to let the client retrieve it for themself).

Filtering does not handle frames. Don't use frames, please. It is not
1995 any more.

=head1 BUGS

The Via-header has HTTP/1.1 hardcoded into it.

=head1 AUTHOR

Adam Sjøgren, E<lt>asjo@magenta-aps.dkE<gt>

=head1 SEE ALSO

L<Obvius::DocType>, L<RFC 2616 - HTTP>, L<RFC 2109 - Cookies>.

=cut
