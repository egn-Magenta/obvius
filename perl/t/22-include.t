#!/usr/bin/perl -w
print "1..3\n";

use WebObvius::Template;

my $tmpl = new WebObvius::Template(path=>'t');

my $test;
my $ok;

my $text;
my $res;
my $expect;


$test = 1;				# include

$text = <<'EOF';
#include include.in
EOF

$expect = qx!sed -e '/^#include/{r t/simple.in' -e d -e '}' < t/include.in!;

$res = $tmpl->expand(\$text);
$ok = ($res eq $expect);

# print STDERR ">>\n$expect<<\n>>\n$res<<\n";

print($ok ? "ok $test\n" : "not ok $test\n");





$test = 2;				# computed include

$text = <<'EOF';
#include inc$(include).in
EOF

$tmpl->param(include=>'lude');

#$expect = qx!sed -e '/^#include/{r t/simple.in' -e d -e '}' < t/include.in!;

$res = $tmpl->expand(\$text);
$ok = ($res eq $expect);

#print STDERR ">>\n$expect<<\n>>\n$res<<\n";

print($ok ? "ok $test\n" : "not ok $test\n");




$test = 3;				# include

$text = <<'EOF';
#include no-such-file no-such-file-either include.in
EOF

$expect = qx!sed -e '/^#include/{r t/simple.in' -e d -e '}' < t/include.in!;

$res = $tmpl->expand(\$text);
$ok = ($res eq $expect);

 print STDERR ">>\n$expect<<\n>>\n$res<<\n";

print($ok ? "ok $test\n" : "not ok $test\n");
