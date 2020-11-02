package WebObvius::Apache2::SOAP;

use strict;
use warnings;
use utf8;

=pod

This module overrides Apache2::SOAP to make it compatible with modern
versions of the HTTP::Headers module. This is done by overriding the
HTTP::Headers::new method and making it convert the first argument
to a list of key value pairs if the first argument is an APR::Table
object.

The overriding is done with a local variable so it only affects the
handler method in this module.

=cut

use base 'Apache2::SOAP';

use HTTP::Headers;
use Data::Dumper;

my $org_headers_new = \&HTTP::Headers::new;

sub replacement_method {
    my ($class, $first_arg, @rest) = @_;

    my @fixed_args;
    if(ref($first_arg) eq 'APR::Table') {
        # Convert the table to a list of key-value pairs
        foreach my $key (keys %{$first_arg}) {
            push(@fixed_args, $key => $first_arg->{$key});
        }
    } else {
        push(@fixed_args, $first_arg);
    }

    return $org_headers_new->($class, @fixed_args, @rest);
};

sub handler {
    # Override constructor of HTTP::Headers to accept an APR::Table object
    # as the first arg.
    no warnings 'redefine';
    local *HTTP::Headers::new = \&replacement_method;
    use warnings;

    return Apache2::SOAP::handler(@_);
}

1;