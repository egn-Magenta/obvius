#!/usr/bin/perl -w
print "1..4\n";

# This one does very little - and it inspects object internals

use WebObvius::Template;

my $tmpl = new WebObvius::Template(path=>'t');

my $test;
my $ok;

my $text;
my $res;


$test = 1;				# set_hook

sub test_func { return 'test'; }
$tmpl->set_hook(test => \&test_func);
$ok = ($tmpl->{HOOKS}->{test}->[0] = \&test_func);

print($ok ? "ok $test\n" : "not ok $test\n");




$test = 2;				# set_hook w/user_data

$tmpl->set_hook(test => \&test_func, 'user-data');
$ok = (($tmpl->{HOOKS}->{test}->[0] = \&test_func)
       and ($tmpl->{HOOKS}->{test}->[1] eq 'user-data'));

print($ok ? "ok $test\n" : "not ok $test\n");




$test = 3;				# set_hook_data

$tmpl->set_hook_data('test', 'another user-data');
$ok = (($tmpl->{HOOKS}->{test}->[0] = \&test_func)
       and ($tmpl->{HOOKS}->{test}->[1] eq 'another user-data'));

print($ok ? "ok $test\n" : "not ok $test\n");





$test = 4;				# un_set_hook

$tmpl->unset_hook('test');
$ok = (!defined($tmpl->{HOOKS}->{test}));

print($ok ? "ok $test\n" : "not ok $test\n");
