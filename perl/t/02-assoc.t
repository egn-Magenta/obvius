#!/usr/bin/perl -w
print "1..2\n";

use WebObvius::Template;

my $tmpl = new WebObvius::Template(path=>'t');

my $test;
my $ok;

my $text;
my $res;


$test = 1;				# associate(hashref)

my @vars = qw(test1 test2 test3 whatever more_test);
my %vars = map { $_ => $_ x 3 } @vars;

$tmpl->associate(\%vars);

$ok = 0;
foreach ($tmpl->param) {
    $ok++ if ($tmpl->param($_) eq $_ x 3);
}
$ok = ($ok-1 == $#vars);

print($ok ? "ok $test\n" : "not ok $test\n");






$test = 2;				# associate(object)

my $tmpl2 = new WebObvius::Template(path=>'t');
$tmpl2->associate($tmpl);

$ok = 0;
foreach ($tmpl2->param) {
    $ok++ if ($tmpl2->param($_) eq $tmpl->param($_));
}
$ok = ($ok-1 == $#vars);

print($ok ? "ok $test\n" : "not ok $test\n");
