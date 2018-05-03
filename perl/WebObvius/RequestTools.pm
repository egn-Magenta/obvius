package WebObvius::RequestTools;

# This package provides some tools for working with the mod_perl request object
# without having to load WebObvius::Site, which wont load outside of an apache
# environment.

use strict;
use warnings;
use utf8;

use Exporter;

our @ISA = qw(Exporter);
our @EXPORT = qw(
    get_origin_ip_from_request
    get_remote_ip_from_request
);

# get_origin_ip_from_request($req) -
# Method for extracting the client's origin IP from the request object, taking
# proxies into consideration.
sub get_origin_ip_from_request {
    my ($req) = @_;

    # Apace 2.4 provides $req->useragent_ip, event though it is not in the
    # documentation.
    if($req->UNIVERSAL::can("useragent_ip")) {
        return $req->useragent_ip;
    }

    # Get the first IP in the X-FORWARDED-FOR header
    if(my $ip = $req->headers_in->{"X-FORWARDED-FOR"}) {
	$ip =~ s!,.*!!;
	return $ip;
    }

    # Default to the remote ip of the connection
    return $req->connection->remote_ip;
}

# get_remote_ip_from_request($req) -
# Method for extracting the IP at the remote end of the connection to the
# server. If the site is served behind a reverse proxy this will most likely be
# the IP address of the proxy server.
sub get_remote_ip_from_request {
    my ($req) = @_;

    # Apache 2.4 provides $req->connection->client_ip, event though it is not
    # in the documentation.
    if($req->connection->UNIVERSAL::can("client_ip")) {
        return $req->connection->client_ip;
    }

    # Use pre-Apache 2.4 method
    return $req->connection->remote_ip;
}