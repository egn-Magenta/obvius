package WebObvius::RequestTools;

# This package provides some tools for working with the mod_perl request object
# without having to load WebObvius::Site, which wont load outside of an apache
# environment.

use strict;
use warnings;
use utf8;

use Exporter;

our @ISA = qw(Exporter);
our @EXPORT = qw( get_origin_ip_from_request );

# get_origin_ip_from_request($req) -
# Method for extracting the client's origin IP from the request object, taking
# proxies into consideration.
sub get_origin_ip_from_request {
    my ($req) = @_;

    return $req->useragent_ip;

    # Get the first IP in the X-FORWARDED-FOR header
    if(my $ip = $req->headers_in->{"X-FORWARDED-FOR"}) {
	$ip =~ s!,.*!!;
	return $ip;
    }

    # Default to the remote ip of the connection
    return $req->connection->remote_ip;
}