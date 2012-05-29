package WebObvius::Captcha;

use strict;
use warnings;


use Exporter;
use Digest::MD5 qw( md5_hex );
use Captcha::reCAPTCHA;
use WebObvius::Site;

our @EXPORT = qw( check_captcha check_captcha_from_input check_recaptcha_from_input );

sub check_captcha_from_input {
    my ($input) = @_;

    my $captcha_code = $input->param('obvius_cookies')->{captcha_code};
    my $captcha_entered = $input->param('captcha_field');
    
    return check_captcha($captcha_code, $captcha_entered);
}

sub check_captcha {
    my ($captcha_cookie, $captcha_entered) = @_;
    
    my $md5 = md5_hex($captcha_entered);
    return int($captcha_cookie && $md5 && $md5 eq $captcha_cookie);
}

sub check_recaptcha_from_input {
    my ($input) = @_;

    my $challenge = $input->param('recaptcha_challenge_field');
    my $response =  $input->param('recaptcha_response_field');

    my $captcha = Captcha::reCAPTCHA->new;
    my $result = $captcha->check_answer("6Lc2Dc4SAAAAACLl_BaGlOxPMYnYezxkObdGoRJO",
        $input->param('OBVIUS_ORIGIN_IP') || $ENV{'REMOTE_ADDR'},
        $challenge,
        $response
    );

    return $result->{is_valid}; 
}

sub check_recaptcha_from_request {
    my ($req) = @_;

    my $challenge = $req->param('recaptcha_challenge_field');
    my $response =  $req->param('recaptcha_response_field');

    my $ip = WebObvius::Site::get_origin_ip($req);

    my $captcha = Captcha::reCAPTCHA->new;
    my $result = $captcha->check_answer("6Lc2Dc4SAAAAACLl_BaGlOxPMYnYezxkObdGoRJO",
        $ip || $ENV{'REMOTE_ADDR'},
        $challenge,
        $response
    );

    return $result->{is_valid}; 
}

1;
