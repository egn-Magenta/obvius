package Obvius::EncryptionModule;

use strict;
use warnings;

use Crypt::TripleDES;
use APR::Base64;
use Data::Dumper;

our @ISA = ('Obvius::Data');
our $VERSION="1.0";

sub new {
    my($proto, $passphrase) = @_;
    my $self = $proto->SUPER::new(passphrase => $passphrase);
    return bless($self, __PACKAGE__);
}

######
# 1) $userinfo supplied by callee (if none is given then Dumper($obvius->{USER}) is used
# 2) $req -> the Apache(2)::Request object
# 3) $msg - the message supplied by the callee (if none is given then '' is used)
######
sub log_access {
    my($self, $obvius, $userinfo, $req, $msg) = @_;
    my $dbh = $obvius->dbh;

    $userinfo = Dumper($obvius->get_user($obvius->{USER})) unless ($userinfo);
    $userinfo ||= 'no-user';
    my $reqInfo = $self->createRequestInfo($req);
    $msg ||= '';

    my $stmt = $dbh->prepare("INSERT INTO protected_access_logging " .
			     "(id, timeofentry, userinfo, requestinfo, message) values " .
			     "(NULL, now(), ?, ?, ?)");
    my $result = $stmt->execute($userinfo, $reqInfo, $msg);
    die __PACKAGE__ . "::log_access -> Failed when inserting values: [" . 
	join(', ',  ($userinfo, $reqInfo, $msg)) . "]\n" unless ($result);
}

sub encrypt_data {
    my($self, $plaindata) = @_;
    $plaindata =~ s/^\s+|\s+$//g;
    my $ct = new Crypt::TripleDES;
    my $cr = $ct->encrypt3($plaindata, $self->{passphrase});
    $cr = APR::Base64::encode($cr);
    undef($ct);
    return $cr;
}

sub decrypt_data {
    my($self, $cipherdata) = @_;
    $cipherdata = APR::Base64::decode($cipherdata);
    my $ct = new Crypt::TripleDES;
    my $dt = $ct->decrypt3($cipherdata, $self->{passphrase});
    $dt =~ s/\s+$//;
    undef($ct);
    return $dt
}

sub createRequestInfo {
    my($self, $req) = @_;
    my $infostr = '';
    $infostr .= "REMOTE-IP => " . $req->connection->remote_ip . "\n";
    $infostr .= "REMOTE-HOST => " . $req->connection->get_remote_host . "\n";
    $infostr .= "THE-REQUEST => " . $req->the_request . "\n";
    $infostr .= "---------- HEADERS-IN ----------------------------\n";
    my $hin = $req->headers_in;
    foreach my $key ( keys(%{$hin}) ) {
	$infostr .= $key  . " => " . $hin->{$key} . "\n";
    }
    my @param_names = $req->param;
    if ( $#param_names >= 0 ) {
	$infostr .= "-----------PARAMETERS ---------------------------\n";
	foreach my $par ( @param_names ) {
	    $infostr .= $par  . " => " . $req->param($par) . "\n";
	}
    }
    return $infostr;
}

### Std. return value
1;
