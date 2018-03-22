package WebObvius::Recaptcha2;

use strict;
use warnings;
use utf8;

use LWP::UserAgent;
use JSON qw(from_json);
use WebObvius::RequestTools qw(get_origin_ip_from_request);

my $secret;

my $verify_url = 'https://www.google.com/recaptcha/api/siteverify';

sub setup {
    my ($obvius) = @_;

    $secret = $obvius->config->param('recaptcha_secret');
}


sub validate {
    my ($response_token, $remoteip) = @_;

    my $ua = LWP::UserAgent->new(
        agent => "Obvius CMS reCaptcha verifier/0.1",
    );
    my %data = (
        secret => $secret,
        response => $response_token,
    );
    if($remoteip) {
        $data{remoteip} = $remoteip;
    }

    my $response = $ua->post($verify_url, \%data);
    my $result = 0;
    eval {
        my $response_data = from_json($response->content);
        $result = $response_data->{success};
    };
    if($@) {
        warn("Error while validating recaptcha2: " . $@);
    }
    return $result;
}

sub validate_from_input {
    my ($input) = @_;

    return validate(
        $input->param("g-recaptcha-response"),
        $input->param('OBVIUS_ORIGIN_IP') || $ENV{'REMOTE_ADDR'}
    );
}

sub validate_from_request {
    my ($request) = @_;

    return validate(
        $request->param("g-recaptcha-response"),
        get_origin_ip_from_request($request) || $ENV{'REMOTE_ADDR'}
    );
}
