#!/usr/bin/perl -w

##### Usage and License

# This script activates a subscription from ForbrugerPortalens
# extensions to the MCM subscription procedure.

# Each subscriber shoul reply to a mail which contains a cookie in the
# subject line. This mail should just be feeded into this script

# No exit codes, no nothing!

use lib '/home/httpd/root/perl';
use lib '/usr/lib/perl/5.6.0/';

use Obvius;
use Digest::MD5 qw(md5_base64);
use Mail::Header;

use Getopt::Long;

use locale;
use Carp;

use Data::Dumper;


######
# Connection to Obvius database
######

my ($obvius, $debug) = (undef,0);

GetOptions('site=s'      => \$obvius,
           'debug'       => \$debug,
          );

exit 0
    unless (defined($obvius));


########################################################################
#
# Opsætning af Obvius (nyt system)
#
########################################################################

use Obvius;
use Obvius::Config;
use Obvius::Data;

croak ("No site defined")
  unless (defined($obvius));

my $conf = new Obvius::Config($obvius);
#print Dumper($conf);
croak ("Could not get config for $obvius")
  unless(defined($conf));

$obvius = new Obvius($conf);
#print Dumper($obvius);
croak ("Could not get Obvius object for $obvius")
  unless(defined($obvius));

$obvius->{USER} = 'admin';


######
# Read incomming email from STDIN
######

my ($head, $subject, $email, $cookie, $subscriber);

$head = new Mail::Header \*STDIN;
$subject = $head->get('Subject');
chomp $subject;
$subject =~ s/\s//g;  # nogle mailere kan ikke folde ordentligt!
@line = split /::/, $subject;
$email = pop @line;
$cookie = pop @line;


print STDERR "Email: ${email}, Cookie: ${cookie}\n" if $debug;


$subscriber = $obvius->get_subscriber({email => $email});

exit 0 unless defined($subscriber);

print Dumper $subscriber;

my $passwd = $subscriber->{passwd};

print STDERR "Passwd: ${passwd}\n" if $debug;

$subscriber_cookie = md5_base64($subscriber->{email},
				$subscriber->{name},
				$subscriber->{passwd});

print STDERR "Calculated Cookie: $subscriber_cookie\n";


exit 0 if ($cookie ne $subscriber_cookie);

$obvius->update_subscriber({suspended => 0}, email=>$email);

exit 0;

