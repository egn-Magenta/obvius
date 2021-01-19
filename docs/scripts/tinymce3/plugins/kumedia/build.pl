#!/usr/bin/perl

use strict;
use warnings;

use Data::Dumper;
use File::Basename;
use File::Find;

my $win32 = $^O eq 'MSWin32';

my $base_dir = dirname($0) . "/";
$base_dir =~ s!\\!/!g if($win32);
my $org_dir = $base_dir . "../../../tiny_mce/plugins/media/";

my @files;
find(sub { /\.append$/ && push(@files, $File::Find::name); }, $base_dir);

for my $append_file (@files) {
    chomp($append_file);
    my $output_file = $append_file;
    $output_file =~ s!\.append$!!;
    my $org_file = $output_file;
    $org_file =~ s!^\Q$base_dir\E!$org_dir!;
    
    if(-f $org_file and -f $append_file) {
        print "Putting $org_file and $append_file into $output_file\n";

        open(OUT, ">$output_file") or die "Couldn't open $output_file for writing";

        open(ORG, $org_file) or die "Couldn't open $org_file for reading";
        print OUT $_ for(<ORG>);
        close(ORG);

        open(APPEND, $append_file) or die "Couldn't open $append_file for reading";
        print OUT $_ for(<APPEND>);
        close(APPEND);
    }
}

if($win32) {
    system($base_dir . "../../../tools/jstrim.exe", $base_dir . "editor_plugin_src.js", $base_dir . "editor_plugin.js");
} else {
    system("mono", $base_dir . "../../../tools/jstrim_mono.exe", $base_dir . "editor_plugin_src.js", $base_dir . "editor_plugin.js");
}