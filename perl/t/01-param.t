#!/usr/bin/perl -w
print "1..5\n";

use WebObvius::Template;

my $tmpl = new WebObvius::Template(path=>'t');

my $test;
my $ok;

my $text;
my $res;


$test = 1;				# set(n,v) and param(n)

$text = 'This is a simple string';
$tmpl->set('test', $text);
$res = $tmpl->param('test');
$ok = ($res eq $text);

print($ok ? "ok $test\n" : "not ok $test\n");


$test = 2;				# param(n,v) and param(n)

$text = 'This is a simple string';
$tmpl->param('test', $text);
$res = $tmpl->param('test');
$ok = ($res eq $text);

print($ok ? "ok $test\n" : "not ok $test\n");


$test = 3;				# unset(n) and param(n)

$tmpl->unset('test');
$res = $tmpl->param('test');
$ok = !defined($res);

print($ok ? "ok $test\n" : "not ok $test\n");



$test = 4;				# clear

$text = 'This is a simple string';
$tmpl->param('test', $text);
$tmpl->clear;
$res = $tmpl->param('_test');
$ok = !defined($res);

print($ok ? "ok $test\n" : "not ok $test\n");



$test = 5;				# param

my @vars = qw(test1 test2 test3 whatever more_test);

foreach (@vars) {
    $tmpl->param($_ => $_ x 3);
}

$ok = 0;
foreach ($tmpl->param) {
    $ok++ if ($tmpl->param($_) eq $_ x 3);
}
$ok = ($ok-1 == $#vars);

print($ok ? "ok $test\n" : "not ok $test\n");
