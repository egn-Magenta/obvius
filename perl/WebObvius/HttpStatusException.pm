package WebObvius::HttpStatusException;

use strict;
use warnings;
use utf8;

# Constants like NOT_FOUND are present here.
# use HTML::Mason::ApacheHandler;
use WebObvius::Apache
    Constants       => qw(:common :methods :response),
    File            => ''
;

sub new {
    my ($package, $code, $message) = @_;
    # Message is optional, will be picked up in the exception handling in WebObvius::Site::Mason::handler
    my $ref = {
        code => $code,
        message => $message,
    };
    return bless($ref, $package);
}

sub code {
    my ($self) = @_;
    return $self->{code};
}

sub message {
    my ($self) = @_;
    return $self->{message};
}

use constant HTTP404 => WebObvius::HttpStatusException->new(404);  # NOT_FOUND == 404

1;
