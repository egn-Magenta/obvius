# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test;
BEGIN { plan tests => 19 };
use Obvius::Data;
ok(1); # If we made it this far, we're ok.

#########################

# Insert your test code below, the Test module is use()ed here so read
# its man page ( perldoc Test ) for help writing this test script.

# Construct without arguments
my $d = new Obvius::Data;

ok(defined $d);
ok(not defined $d->param('a'));
ok(not defined $d->param('a', 88888));
ok($d->param('a') == 88888);

ok($d->_a == 88888);
ok($d->A == 88888);
ok($d->_a(99999) == 88888);
ok($d->_a == 99999);

# Construct with another object
my $d2 = new Obvius::Data($d);

ok(defined $d2);
ok($d2->_a == 99999);

# Construct with inline hash
my $d3 = new Obvius::Data(hej => 'med dig', test => 77777);

ok(defined $d3);
ok($d3->param('hej') eq 'med dig');
ok($d3->_hej eq 'med dig');
ok($d3->param('test') == 77777);
ok($d3->_test == 77777);

# Delete
my $d4=new Obvius::Data(test=>'uno');

ok($d4->param('test') eq 'uno');
ok($d4->delete('test') eq 'uno');
ok(not defined $d4->param('test'));
