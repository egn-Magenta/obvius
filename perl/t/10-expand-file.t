#!/usr/bin/perl -w
print "1..1\n";

use WebObvius::Template;

my $tmpl = new WebObvius::Template(path=>'t', trace=>0, debug=>0);
my $expect = `cat t/simple.in`;
my $res = $tmpl->expand('simple.in');

# print STDERR ">>\n$expect<<\n>>\n$res<<\n";

print 'not ' if ($res ne $expect);
print "ok 1\n";
