#!/usr/bin/perl -w
print "1..3\n";

use WebObvius::Template;

my $tmpl = new WebObvius::Template(path=>'t');

my $test;
my $ok;

my $text;
my $res;
my $expect;

my $base_text = <<'EOF';
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



$test = 1;				# test1

$tmpl->clear;
$text = "#set test1=yes\n" . $base_text;

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


$test = 2;				# test2

$tmpl->clear;
$text = "#set test2=yes\n" . $base_text;

$expect = <<'EOF';
first
not test1
test2 = yes
last
EOF

$res = $tmpl->expand(\$text);
$ok = ($res eq $expect);

#print STDERR ">>\n$expect<<\n>>\n$res<<\n";

print($ok ? "ok $test\n" : "not ok $test\n");


$test = 3;				# test1 and test2

$tmpl->clear;
$text = ('#set test1=non void' . "\n"
	 . '#set test2=$(test1)$(test1)' . "\n"
	 . $base_text
	);

$expect = <<'EOF';
first
test1 = non void
test2 = non voidnon void
last
EOF

$res = $tmpl->expand(\$text);
$ok = ($res eq $expect);

#print STDERR ">>\n$expect<<\n>>\n$res<<\n";

print($ok ? "ok $test\n" : "not ok $test\n");
