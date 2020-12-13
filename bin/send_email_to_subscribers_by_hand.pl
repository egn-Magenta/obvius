#!/usr/bin/perl

# send_email.pl - send email to a range of subscribers in Obvius
#
# Copyright (C) 2002, Adam Sjøgren. Under the GPL.

# Usage: Modify the send_email sub at the bottom of the script, then
#        run it with --site <sitename> --min <first subscriber-id to send to>
#        --max <last subscriber-id to send to>.

use strict;
use warnings;

use Obvius;
use Obvius::Config;
use Obvius::Data;

use locale;
use Carp;
use Getopt::Long;
use URI::Escape;
use Net::SMTP;

my ($site, $min, $max, $debug);
GetOptions(
	   'site=s',  \$site,
	   'min=i',   \$min,
	   'max=i',   \$max,
	   'debug:i', \$debug,
	  ) or die "Couldn't parse commandline, giving up";

die "Please supply site, min and max, stopping" unless ($site and defined $min and $max);

# Connect to Obvius
my $conf = new Obvius::Config($site);
croak ("Could not get config for $site") unless(defined($conf));

my $obvius = new Obvius($conf);
croak ("Could not get Obvius object for $obvius") unless($obvius);

$obvius->{USER} = 'admin';

# Send email to each subscriber in the range:
foreach my $id ($min..$max) {
    if (my $subscriber=$obvius->get_subscriber({id=>$id})) {
	send_email($subscriber->{name}, $subscriber->{email}, $subscriber->{passwd});
    }
    else {
	warn "No subscriber with id $id found on $site.";
    }
}

exit 0;


sub send_email {
    my ($name, $email, $passwd)=@_;

    my $enc_passwd=uri_escape($passwd);
    my $from='bitbucket@www.sportsfiskeren.dk';

    my $text=<<EOT;
From: Sportsfiskeren.dk <$from>
To: $email
Subject: Abonnement på Sportsfiskeren.dk overflyttet
Reply-to: webmaster\@sportsfiskeren.dk
MIME-Version: 1.0
Content-Type: text/plain; charset=iso-8859-1
Content-Transfer-Encoding: 8bit

Kære abonnent på Sportsfiskeren.dk

Vi har nu overflyttet dit abonnement til det nye website. Du er
registreret med flg. oplysninger:

     navn: $name
    email: $email
  kodeord: $name

Du kan ændre dine abonnementsoplysninger ved hjælp af din
email-adresse og dit kodeord.

Bemærk at vi har sat dit kodeord til dit navn. Dette kan ændres på
websitet. Husk i øvrigt at store og små bogstaver gør forskel.

Du kan gå direkte til abonnementsstyringen ved at klikke på dette
link:

 <http://sportsfiskeren.dk/abonner/?mode=login&email=$email&password=$enc_passwd>

  Mvh.

   Sportsfiskeren.dk
EOT

    my $smtp = Net::SMTP->new($obvius->config->param('smtp') || 'localhost', Timeout=>30, Debug => $debug) or warn "@_";
    $smtp->mail($from) or warn "@_";
    $smtp->to($email) or warn "@_";
    $smtp->data() or warn "@_";
    $smtp->datasend($text) or warn "@_";
    $smtp->dataend() or warn "@_";
    $smtp->quit or warn "@_";
}
