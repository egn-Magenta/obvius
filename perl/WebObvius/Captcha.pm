package WebObvius::Captcha;

use strict; use warnings;

use Exporter;
use Digest::MD5 qw( md5_hex );

our @EXPORT = qw( check_captcha check_captcha_from_input );

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

1;
