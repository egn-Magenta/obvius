#!/usr/bin/perl -w
print "1..5\n";

use WebObvius::Template;

my $tmpl = new WebObvius::Template(path=>'t', warnings=>1, trace=>0);

my $test;
my $text;
my $ok;

my $res;
my $expect;



$test = 1;				# break in text

$text = <<'EOF';
first
#break
last
EOF

$expect = <<'EOF';
first
EOF

$res = $tmpl->expand(\$text);
$ok = ($res eq $expect);

# print STDERR ">>\n$expect<<\n>>\n$res<<\n";

print($ok ? "ok $test\n" : "not ok $test\n");


$test = 2;				# break in loop

$text = <<'EOF';
first
#loop $(loop)
loop before $(a)
#if $(b)
#break
#endif b
loop after $(a)
#endloop
last
EOF

$tmpl->param(loop=>[ map { { a=>$_, b=>($_==2) } } (0..3) ]);

$expect = <<'EOF';
first
loop before 0
loop after 0
loop before 1
loop after 1
loop before 2
last
EOF

$res = $tmpl->expand(\$text);
$ok = ($res eq $expect);

# print STDERR ">>\n$expect<<\n>>\n$res<<\n";

print($ok ? "ok $test\n" : "not ok $test\n");


$test = 3;				# verb

$text = <<'EOF';
$(test)
#verb $(test)
#ifdef notdef
#verb $(test)
#endif
$(test)
EOF

$tmpl->param(test=>'TEST');

$expect = <<'EOF';
TEST
$(test)
TEST
EOF

$res = $tmpl->expand(\$text);
$ok = ($res eq $expect);

# print STDERR ">>\n$expect<<\n>>\n$res<<\n";

print($ok ? "ok $test\n" : "not ok $test\n");


$test = 4;				# comments

$text = <<'EOF';
$(test)
## $(test)
$(test)
EOF

$tmpl->param(test=>'TEST');

$expect = <<'EOF';
TEST
TEST
EOF

$res = $tmpl->expand(\$text);
$ok = ($res eq $expect);

# print STDERR ">>\n$expect<<\n>>\n$res<<\n";

print($ok ? "ok $test\n" : "not ok $test\n");



$test = 5;				# hooks arg1 user data

$expand = <<'EOF';
#ifdef not_def
not to be printed
#else
to be printed
#endif
EOF

$tmpl->param('code' => $expand);

$text = <<'EOF';
#expand code
EOF

$expect = <<'EOF';
to be printed
EOF

$res = $tmpl->expand(\$text);

#print STDERR ">>\n$expect<<\n>>\n$res<<\n";

$ok = ($res eq $expect);

print($ok ? "ok $test\n" : "not ok $test\n");
