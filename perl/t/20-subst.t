#!/usr/bin/perl -w
print "1..2\n";

use WebObvius::Template;

my $tmpl = new WebObvius::Template(path=>'t');

my $test;
my $ok;

my $text;
my $res;
my $expect;


$test = 1;				# simple variables

my @vars = qw(test1 test2 test3 whatever more_test);
my %vars = map { $_ => $_ x 3 } @vars;

$tmpl->associate(\%vars);

$text = <<'EOF';
$(test1)
$(test3)
$(more_test)
EOF

$expect = <<'EOF';
test1test1test1
test3test3test3
more_testmore_testmore_test
EOF

$res = $tmpl->expand(\$text);

$ok = ($res eq $expect);

print($ok ? "ok $test\n" : "not ok $test\n");




$test = 2;				# simple variables

$tmpl->param(test1test1test1=>'won\'t see this');

$text = <<'EOF';
$($(test1))
EOF

$expect = <<'EOF';
$(test1test1test1)
EOF

$res = $tmpl->expand(\$text);
$ok = ($res eq $expect);

print($ok ? "ok $test\n" : "not ok $test\n");



