#!/usr/bin/perl -w
print "1..4\n";

use WebObvius::Template;

my $tmpl = new WebObvius::Template(path=>'t', warnings=>1, debug=>0);

my $test;
my $text;
my $ok;

my $res;
my $expect;



$test = 1;				# "#loop var", "#loop $(var)"
					# and nested loops

$text = <<'EOF';
first
#loop loop1
loop1 before $(a) $(b) $(loop2)
# loop $(loop2)
loop2 $(a) $(b) $(c)
# endloop loop2
loop1 after  $(a) $(b) $(loop2)
#endloop loop1
last
EOF

my @data = ();
foreach my $loop1 (1..3) {
    my @data2;
    if ($loop1 % 2) {
	foreach my $loop2 (10..10+$loop1) {
	    push(@data2, { a=>$loop2, b=>$loop2+$loop1, c=>$loop2*$loop1 });
	}
    }
    push(@data1, { a=>$loop1, b=>$loop1*$loop1, loop2=>\@data2});
}

$tmpl->param(loop1=>\@data1);

$expect = <<'EOF';
first
loop1 before 1 1 2
loop2 10 11 10
loop2 11 12 11
loop1 after  1 1 2
loop1 before 2 4 0
loop1 after  2 4 0
loop1 before 3 9 4
loop2 10 13 30
loop2 11 14 33
loop2 12 15 36
loop2 13 16 39
loop1 after  3 9 4
last
EOF

$res = $tmpl->expand(\$text);
$ok = ($res eq $expect);

# print STDERR ">>\n$expect<<\n>>\n$res<<\n";

print($ok ? "ok $test\n" : "not ok $test\n");


$test = 2;				# "#loop $[hook]"

$text = <<'EOF';
first
#loop $[hook a 1 5]
loop1 $(a)
#endloop
middle
#loop $[hook test 10 20]
loop2 $(test)
#endloop
last $[hook test 10 20]
EOF

$tmpl->clear;
$tmpl->set_hook(hook=>sub {
		    my ($t, $u, $n, $n1, $n2) = @_;

		    return [ map { { "$n" => $_ } } ($n1..$n2) ];
		});

$expect = <<'EOF';
first
loop1 1
loop1 2
loop1 3
loop1 4
loop1 5
middle
loop2 10
loop2 11
loop2 12
loop2 13
loop2 14
loop2 15
loop2 16
loop2 17
loop2 18
loop2 19
loop2 20
last 11
EOF

$res = $tmpl->expand(\$text);
$ok = ($res eq $expect);

# print STDERR ">>\n$expect<<\n>>\n$res<<\n";

print($ok ? "ok $test\n" : "not ok $test\n");


$test = 3;				# unset loop var

$text = <<'EOF';
first
#loop loop
loop $(a) $(b)
#endloop loop
last
EOF

$tmpl->clear;
# $tmpl->param(loop1=>map { { a=>$_, b=>$_*$_} } (1..3));

$expect = <<'EOF';
first
last
EOF

$res = $tmpl->expand(\$text);
$ok = ($res eq $expect);

# print STDERR ">>\n$expect<<\n>>\n$res<<\n";

print($ok ? "ok $test\n" : "not ok $test\n");


$test = 4;				# #import

$text = <<'EOF';
first
#loop loop
loop before $(a) $(b) $(c)
#import a c
loop after  $(a) $(b) $(c)
#endloop loop
last
EOF

@data = ();
foreach my $loop (1..3) {
    push(@data, { a=>$loop, b=>$loop*$loop, c=>$loop*$loop*$loop });
}

$tmpl->param(loop=>\@data);
$tmpl->param(a=>'A');
$tmpl->param(b=>'B');
$tmpl->param(c=>'C');

$expect = <<'EOF';
first
loop before 1 1 1
loop after  A 1 C
loop before 2 4 8
loop after  A 4 C
loop before 3 9 27
loop after  A 9 C
last
EOF

$res = $tmpl->expand(\$text);
$ok = ($res eq $expect);

# print STDERR ">>\n$expect<<\n>>\n$res<<\n";

print($ok ? "ok $test\n" : "not ok $test\n");


