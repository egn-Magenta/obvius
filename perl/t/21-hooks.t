#!/usr/bin/perl -w
print "1..8\n";

use WebObvius::Template;

my $tmpl = new WebObvius::Template(path=>'t');

my $test;
my $ok;

my $text;
my $res;
my $expect;



$test = 1;				# hooks return value

my @vars = qw(test1 test2 test3 whatever more_test);
my %vars = map { $_ => $_ x 2 } @vars;

$tmpl->associate(\%vars);

$tmpl->set_hook(triple=>sub { 
		    my ($t, $u, $v) = @_;
		    return $v x 3;
		});

$text = <<'EOF';
1 $[triple test1]
2 $[triple $(test1)]
EOF

$expect = <<'EOF';
1 test1test1test1
2 test1test1test1test1test1test1
EOF

$res = $tmpl->expand(\$text);

$ok = ($res eq $expect);

print($ok ? "ok $test\n" : "not ok $test\n");


$test = 2;				# hooks arg1 template

$tmpl->set_hook(type => sub { 
		    my ($t, $u, $v) = @_;
		    return ref($t);
		});

$text = <<'EOF';
$[type]
EOF

$expect = <<'EOF';
WebObvius::Template
EOF

$res = $tmpl->expand(\$text);

$ok = ($res eq $expect);

print($ok ? "ok $test\n" : "not ok $test\n");


$test = 3;				# hooks arg1 user data

$tmpl->set_hook(user_data => sub { 
		    my ($t, $u) = @_;
		    return $u;
		}, 'This will be the expansion');

$text = <<'EOF';
$[user_data]
EOF

$expect = <<'EOF';
This will be the expansion
EOF

$res = $tmpl->expand(\$text);

$ok = ($res eq $expect);

print($ok ? "ok $test\n" : "not ok $test\n");


$test = 4;				# hooks arg1 change user data

$tmpl->set_hook_data(user_data => 'This will be the new expansion');

$text = <<'EOF';
$[user_data]
EOF

$expect = <<'EOF';
This will be the new expansion
EOF

$res = $tmpl->expand(\$text);

$ok = ($res eq $expect);

print($ok ? "ok $test\n" : "not ok $test\n");



$test = 5;				# hooks arguments

$tmpl->set_hook(concat => sub { 
		    my ($t, $u, @a) = @_;
		    local $" = '';
		    return "@a";
		});

$text = <<'EOF';
$[concat this with this and this-too]
$[concat,  this,         with,         this,         and,       this-too]
$[concat:this: with: this : and : this-too]
$[concat, this with, this and, this-too]
EOF

$expect = <<'EOF';
thiswiththisandthis-too
thiswiththisandthis-too
thiswiththis and this-too
this withthis andthis-too
EOF

$res = $tmpl->expand(\$text);

$ok = ($res eq $expect);



# print STDERR ">>\n$expect<<\n>>\n$res<<\n";



print($ok ? "ok $test\n" : "not ok $test\n");


$test = 6;				# hooks - unset_hook

$tmpl->unset_hook('concat');

$text = <<'EOF';
$[concat this with this and this-too]
$[concat,  this,         with,         this,         and,       this-too]
$[concat:this: with: this : and : this-too]
$[concat, this with, this and, this-too]
EOF

$expect = <<'EOF';




EOF

$res = $tmpl->expand(\$text);

$ok = ($res eq $expect);



# print STDERR ">>\n$expect<<\n>>\n$res<<\n";



print($ok ? "ok $test\n" : "not ok $test\n");



$test = 7;				# #call syntax

$tmpl->set_hook(incr => sub { 
		    my ($t, $u, $n) = @_;
		    $t->{VARS}->{$n}++;
		});

$text = <<'EOF';
#call incr a
#call incr a
$(a)
#call incr;a
#call incr,a
$(a)
EOF

$expect = <<'EOF';
2
4
EOF

$res = $tmpl->expand(\$text);

$ok = ($res eq $expect);



#print STDERR ">>\n$expect<<\n>>\n$res<<\n";



print($ok ? "ok $test\n" : "not ok $test\n");


$test = 8;				# hooks by method

sub WebObvius::Template::method_hook {
    my ($t, $u, $v) = @_;
    return $v x 3;
}

@vars = qw(test1 test2 test3 whatever more_test);
%vars = map { $_ => $_ x 2 } @vars;

$tmpl->associate(\%vars);


$text = <<'EOF';
1 $[triple test1]
2 $[triple $(test1)]
EOF

$expect = <<'EOF';
1 test1test1test1
2 test1test1test1test1test1test1
EOF

$res = $tmpl->expand(\$text);

$ok = ($res eq $expect);

print($ok ? "ok $test\n" : "not ok $test\n");


