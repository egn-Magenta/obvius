#!/usr/bin/perl -w
print "1..1\n";

use WebObvius::Template;

my $tmpl = new WebObvius::Template(path=>'t');
my $expect = <<'EOF';
Testing
Second line
Third line
EOF

my $res = $tmpl->expand(\*DATA);

# print STDERR ">>\n$expect<<\n>>\n$res<<\n";

print 'not ' if ($res ne $expect);
print "ok 1\n";

__DATA__
Testing
Second line
Third line
