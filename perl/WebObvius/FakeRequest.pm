package WebObvius::FakeRequest;

use strict;
use warnings;
use utf8;

use Obvius::Data;

use base 'Apache2::FakeRequest';

sub new {
    my ($class, %args) = @_;

    return $class->SUPER::new(
        uri => '/',
        method => 'GET',
        method_numer => 0,
        _obvius_notes => Obvius::Data->new(
            translation_lang => 'da'
        ),
        _obvius_pnotes => Obvius::Data->new(
            site => Obvius::Data->new()
        ),
        _obvius_params => Obvius::Data->new(),
        %args
    );
}

sub notes { shift->{_obvius_notes}->param(@_) }
sub pnotes { shift->{_obvius_pnotes}->param(@_) }
sub param { shift->{_obvius_params}->param(@_) }

1;