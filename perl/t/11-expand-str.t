#!/usr/bin/perl -w
print "1..1\n";

use WebObvius::Template;

my $tmpl = new WebObvius::Template(path=>'t');
my $text = <<'EOF';
Testing
Second line
Third line
EOF

my $res = $tmpl->expand(\$text);

print 'not ' if ($res ne $text);
print "ok 1\n";
