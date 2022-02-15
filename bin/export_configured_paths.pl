#!/usr/bin/perl

=head1 Documentation
=begin text
    ### PURPOSE ###
    Like importexport.pl, but only exports paths defined in the config variable `scheduled_export_paths`

    ### INVOCATION ###

    perl export_configured_paths.pl <configname>

=cut

use strict;
use warnings;

use lib '/var/www/obvius/perl';

use Obvius::ExportImport;
use Obvius;
use Obvius::Config;
use File::Copy qw(move);
use File::Path qw(make_path);
use POSIX qw(strftime);

sub clean_path {
    my ($path, $add_slashes) = @_;
    # Clean path;
    # remove whitespace, optionally make sure it's of the format /path/to/export/,
    # and dedup slashes
    $path =~ s{^\s+|\s+$}{}g;
    if ($add_slashes) {
        $path = "/$path/";
    }
    $path =~ s{//+}{/}g;
    return $path;
}

my $config_name = $ARGV[0];
if (!$config_name) {
    die("Must specify config name as first argument")
}

my $config = Obvius::Config->new($config_name);
my $obvius = Obvius->new($config);
my $docpaths = $config->param('scheduled_export_paths');

if (!$docpaths) {
    print "No scheduled_export_paths found in config, not exporting anything\n";
    exit 0;
}
my $importexport_dir = $config->param('importexport_dir');
if (!$importexport_dir) {
    die("No importexport_dir in config");
}
if (!($importexport_dir =~ m{^/})) {
    die("importexport_dir must begin with a slash");
}
my @docpaths = split(',', $docpaths);
my $local_root = $config->param('importexport_dir') . '/local';

# Dynamically select and instantiate class
my $perlname = $config->param('perlname');
my $module = "${perlname}::ExportImport";
require "${perlname}/ExportImport.pm";
my $exporter = $module->new($obvius);


$exporter->set_options({
    depth => -1,
    version_depth => -1,
    only_public_or_latest_version => 1,
    zip => 1,
    include_references => 0
});

my $status = 0;
for my $path (@docpaths) {

    $path = clean_path($path, 1);

    my $dest_path = join("/", $local_root, $path);
    make_path($dest_path);

    my $now = strftime('%Y-%m-%d_%H:%M:%S', localtime);

    my $output_file = clean_path("$dest_path/exporting.zip", 0);
    my $success_file = clean_path("$dest_path/exported_$now.zip", 0);

    if (-f $output_file) {
        die("Another dump is already being created. If this is incorrect, remove $output_file");
    }
    opendir(my $dh, $dest_path) || die("Can't opendir $dest_path: $!");
    my @zipfiles = map { "$dest_path/$_" } grep { /\.zip(\.failed)?$/i && -f "$dest_path/$_" } readdir($dh);
    unlink(@zipfiles);
    closedir $dh;

    eval {
        $exporter->export_to_folder($dest_path, $path);
        move($output_file, $success_file);
    };
    if ($@) {
        if (-f $output_file) {
            unlink($output_file);
        }
        print STDERR $@;
        $status = 1;
    }
}
exit $status;
