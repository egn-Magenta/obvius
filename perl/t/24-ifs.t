#!/usr/bin/perl -w
print "1..4\n";

use WebObvius::Template;

my $tmpl = new WebObvius::Template(path=>'t');

my $test;
my $ok;

my $text;
my $res;
my $expect;

$text = <<'EOF';
first
#if $(test1)
test1 = $(test1)
# if $(test2)
test2 = $(test2)
# else !test2
not test2
# fi
#else !test1
not test1
# if $(test2)
test2 = $(test2)
# else !test2
not test2
# fi
#endif
last
EOF



$test = 1;				# none

$tmpl->clear;
$tmpl->param(test1=>0);
$tmpl->param(test2=>0);

$expect = <<'EOF';
first
not test1
not test2
last
EOF

$res = $tmpl->expand(\$text);
$ok = ($res eq $expect);

#print STDERR ">>\n$expect<<\n>>\n$res<<\n";

print($ok ? "ok $test\n" : "not ok $test\n");


$test = 2;				# test1

$tmpl->clear;
$tmpl->param(test1=>'yes');
$tmpl->param(test2=>0);

$expect = <<'EOF';
first
test1 = yes
not test2
last
EOF

$res = $tmpl->expand(\$text);
$ok = ($res eq $expect);

#print STDERR ">>\n$expect<<\n>>\n$res<<\n";

print($ok ? "ok $test\n" : "not ok $test\n");


$test = 3;				# test2

$tmpl->clear;
$tmpl->param(test1=>0);
$tmpl->param(test2=>1);

$expect = <<'EOF';
first
not test1
test2 = 1
last
EOF

$res = $tmpl->expand(\$text);
$ok = ($res eq $expect);

#print STDERR ">>\n$expect<<\n>>\n$res<<\n";

print($ok ? "ok $test\n" : "not ok $test\n");


$test = 4;				# test1 and test2

$tmpl->clear;
$tmpl->param(test1=>'non void');
$tmpl->param(test2=>'true');

$expect = <<'EOF';
first
test1 = non void
test2 = true
last
EOF

$res = $tmpl->expand(\$text);
$ok = ($res eq $expect);

#print STDERR ">>\n$expect<<\n>>\n$res<<\n";

print($ok ? "ok $test\n" : "not ok $test\n");
