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

use Obvius;
use Obvius::DocType;

use LWP::UserAgent;
use HTML::Parser;
use URI;
use URI::Escape;

our @ISA = qw( Obvius::DocType );
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

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
    my $fetch_url=$input->param('obvius_proxy_url') || $base_url;
    $output->param(url=>$fetch_url);

    # Check whether fetch_url is within what we are allowed to proxy:
    if (!check_url_against_prefixes($fetch_url, [ $base_url, @$prefixes ])) {
        $output->param('error'=>'URL to be fetched is outside the allowed range for this proxy-document. Nothing fetched.');
        warn "URL $fetch_url to be fetched is outside the allowed range $base_url @$prefixes. Nothing fetched.";
        return OBVIUS_OK;
    }

    # Do request:
    my $response=make_request($fetch_url, $via, $input, $output);
    unless ($response) {
        $output->param(error=>'Can not handle request');
        return OBVIUS_OK;
    }

    # Filter content:
    $output->param(proxy_content=>filter_content($response->content, $fetch_url, $base_url, $prefixes));

    # Take care of the result of the request:
    handle_response($response, $fetch_url, $base_url, $prefixes, $via, $output);

    return OBVIUS_OK;
}

sub check_via_ok {
    my ($input, $via)=@_;

    my $header_via=$input->param('OBVIUS_HEADERS_IN')->{Via};

    # XXX This is an odd way of (an attempt at) finding a substring
    # within a string:
    my $pattern='[' . (join "][", split '', $via) . ']';
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
    my ($content, $fetch_url, $base_url, $prefixes)=@_;

    my $parser=HTML::Parser->new(
                                 api_version=>3,
                                 start_h=>[ \&start_element, 'self, tagname, attr, attrseq' ],
                                 end_h=>[ \&end_element, 'self, tagname' ],
                                 default_h=>[ \&catch_all, 'self, dtext' ],
                                 unbroken_text=>1,
                                );


    $parser->{OBVIUS_OUTPUT}='';
    $parser->{OBVIUS_IN_BODY}=0;
    $parser->{OBVIUS_FETCH_URL}=$fetch_url;
    $parser->{OBVIUS_BASE_URL}=$base_url;
    $parser->{OBVIUS_PREFIXES}=$prefixes;

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

sub start_element {
    my ($self, $tagname, $attr, $attrseq)=@_;

    if ($tagname eq 'body') {
        $self->{OBVIUS_IN_BODY}=1;
        return;
    }

    return unless $self->{OBVIUS_IN_BODY};

    $self->{OBVIUS_OUTPUT}.='<' . $tagname;

    my @out_attrs=();
    foreach my $name (@$attrseq) {
        if ($name eq '/') { # Special case, apparantly HTML::Parser don't know short elements!
            $self->{OBVIUS_OUTPUT}.=' /';
            next; # This should/must also be last
        }

        my $value=filter_attribute($tagname, $name, $attr->{$name}, $self->{OBVIUS_FETCH_URL}, $self->{OBVIUS_BASE_URL}, $self->{OBVIUS_PREFIXES});

        my $delim=($value=~/[\"]/ ? "'" : '"');
        push @out_attrs, $name . '=' . $delim . $value . $delim;
    }
    $self->{OBVIUS_OUTPUT}.=' ' . (join ' ', @out_attrs) if (scalar(@out_attrs));

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

    return $value;
}

sub absolutify {
    my ($url, $fetch_url)=@_;

    my $uri=URI->new_abs($url, $fetch_url);
    my $abs=$uri->as_string;

    return $abs;
}

sub absolutify_and_proxy {
    my ($url, $fetch_url, $base_url, $prefixes)=@_;

    $url=absolutify($url, $fetch_url);

    # Now, if the uri matches $base_url or one of the prefixes,
    # change it to ./?obvius_proxy_url=$uri
    if (check_url_against_prefixes($url, [$base_url, @$prefixes])) {
        $url='./?obvius_proxy_url=' . uri_escape($url);
    }

    return $url;
}

sub check_url_against_prefixes {
    my ($url, $prefixes)=@_;

    foreach my $prefix (@$prefixes) {
        return 1 if (lc(substr($url, 0, length($prefix))) eq lc($prefix));
    }

    return 0;
}

sub end_element {
    my ($self, $tagname)=@_;

    if ($tagname eq 'body') {
        $self->{OBVIUS_IN_BODY}=0;
    }

    return unless $self->{OBVIUS_IN_BODY};

    $self->{OBVIUS_OUTPUT}.='</' . $tagname . '>';
}

sub catch_all {
    my ($self, $dtext)=@_;

    return unless $self->{OBVIUS_IN_BODY};

    $self->{OBVIUS_OUTPUT}.=$dtext if (defined $dtext);
}

my %client_to_proxy_headers=(
                             'user-agent'=>1,       # Lowercase for simple comparison
                             'accept'=>1,
                             'accept-language'=>1,
                             'accept-charset'=>1,
                             # 'cookie'=>1, # XXX For cookies not to bleed, handling is necessary!
                             'cache-control'=>1,
                             'via'=>1,
                             );

# This is a bit of a mess, these things get added to input, and there
# is no way to tell them apart from incoming variables:
my %incoming_variables_prune=(
                              NOW=>1,
                              IS_ADMIN=>1,
                              THE_REQUEST=>1,
                              REMOTE_IP=>1,
                              OBVIUS_HEADERS_IN=>1,
                              OBVIUS_COOKIES=>1,
                             );

sub make_request {
    my ($url, $via, $input, $output)=@_;

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
            $formdata{$key}=$input->param($key);
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

my %proxy_to_client_headers_prune=(
                                   'content-length'=>1,
                                   'connection'=>1,
                                   'accept-ranges'=>1,
                                   'date'=>1,
                                   'set-cookie'=>1, # XXX For cookies not to cross-pollenate
                                                    #     special handling will be required
                                  );

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

=head1 AUTHOR

Adam Sjøgren, E<lt>asjo@magenta-aps.dkE<gt>

=head1 SEE ALSO

L<Obvius::DocType>.

=cut
