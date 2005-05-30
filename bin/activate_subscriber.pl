#!/usr/bin/perl -w

# activate_subscriber.pl - a script to activate subscribers in MCMS
#                          when emails are received to a special address.
#
#   Assumption: equal signs are rare or more specific neither
#   passwords nor domain names contains equal signs.
#
#   Example reply-to:
#
#    Reply-To: abonnement-www.website.dk+pAssWd=user=domain@www.server.dk
#
#   Example entry in /etc/aliases:
#
#    abonnement-www.website.dk: |"/var/www/mcms/bin/activate_subscriber.pl --site website"
#
#
# Copyright 2002-2004 (C) FI, Magenta. By Peter Makholm, Adam Sjøgren. Under the GPL.

use Obvius;
use Obvius::Config;

use Getopt::Long;

use locale;
use Carp;

my ($obvius, $extension, $debug) = (undef,undef,0);
GetOptions('site=s'      => \$obvius,
	   'extension=s' => \$extension,
           'debug'       => \$debug,
          );
$extension ||= $ENV{EXTENSION} || $ENV{EXT}; # should work with both postfix and qmail


croak ("No site defined")
  unless (defined($obvius));

my $conf = new Obvius::Config($obvius);
croak ("Could not get config for $obvius")
  unless(defined($conf));

$obvius = new Obvius($conf);
croak ("Could not get Obvius object for $obvius")
  unless(defined($obvius));
$obvius->{USER} = 'admin';



my ($passwd, $email) = ($extension =~ /([^=]*)\=(.*)/);
$email =~ s/=(?=[^=]*$)/\@/;

print STDERR "email = $email\tKode = $passwd\n" if ($debug);

# It would be nice to call Obvius::DocType::Subscribe::action but I'm lazy.

my $subscriber = $obvius->get_subscriber( {email => $email, passwd => $passwd} );

if ($subscriber) {
  $obvius->update_subscriber({suspended => 0}, email=>$email);
} else {
  # Do nothing?
}


