# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test;
BEGIN { plan tests => 5 };
use Obvius::Config;
ok(1); # If we made it this far, we're ok.

#########################

# Insert your test code below, the Test module is use()ed here so read
# its man page ( perldoc Test ) for help writing this test script.

my $configname='testobvius';
my $c = new Obvius::Config $configname;

ok($c) || print STDERR "Perhaps you don't have /etc/obvius/$configname.conf on your system?\n";

# Previous value of a is not defined:
ok($c->param('a', 'dublet'), undef);

# Setting a to 'test', returning previous value 'dublet':
ok($c->param('a', 'test'), 'dublet');

# Checking that the current value is test now:
ok($c->param('a'), 'test');
