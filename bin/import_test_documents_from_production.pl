#!/usr/bin/perl

# This script was originally a migration that imported test documents
# in various environments. It has now been converted to a standalone
# script that needs to be explicitly executed. In development environments
# this can be done by running `perl manage.pl import_test_docs`.
# The script will import /testarea/websted/ from the production server
# to /testarea/websted/ in the local environment.
#
# Usage:
#
#  perl import_test_documents_from_production.pl [config_name] [server_address]
#

use strict;
use warnings;
use utf8;

use Carp;
use Obvius::ExportImport;
use WebObvius::Rewriter::ObviusRules;

my $config_name = $ARGV[0];
if (!$config_name) {
    die("Must specify config name as first argument");
}

# TODO: Read from config
my $remote_server = $ARGV[1];
if (!$remote_server) {
    die("Must specify remote server as second argument");
}
my $remote_server_underscore = $remote_server;
$remote_server_underscore =~ s{\.}{_}g;

my $obvius_config = Obvius::Config->new($config_name);

my $cache = eval {
    return WebObvius::Cache::Cache->new(Obvius->new($obvius_config));
};
if (!$cache) {
    carp 'Could not instantiate cache. Running import with cache clearing disabled';
}

# Dynamically select and instantiate class
my $perlname = $obvius_config->param('perlname');
my $module = "${perlname}::ExportImport";

my $m = "${module}.pm";
$m =~ s{::}{/};
require $m;

# $module->import();
my $exportimport = $module->new($obvius_config);
$exportimport->set_options({
    create_dest_if_not_exists => 1,
    clear_cache               => $cache ? 1 : 0,
});

my $paths = $obvius_config->param('scheduled_import_paths');
if (!$paths) {
    carp("Not importing documents from $remote_server; no paths ".
        'specified in scheduled_import_paths');
    exit(0);
}
my @paths = split(',', $paths);

# Check if we have a remote API key and complain if we do not
my $remote_api_key = $obvius_config->param(
    "remote_api_key_for_$remote_server_underscore"
);

if(!$remote_api_key) {
    carp "Cannot import documents from $remote_server since no " .
    "remote API key is defined for $remote_server. You need to set the `" .
    uc("OBVIUS_CONFIG_${config_name}_REMOTE_API_KEY_FOR_${remote_server_underscore}") .
    '` environment variable for the web container. This can be done in the ' .
    'docker-compose.override.yml file in development environments. ' .
    'The key to use is available in Bitwarden.';
    exit(0);
}

for my $path (@paths) {
    # Sanitize path
    $path =~ s{^\s+|\s+$}{}g;
    $path = "/$path/";
    $path =~ s{//+}{/}g;

    $exportimport->import_remote_dump(
        $remote_server,
        $path,
        $path,
        # Always try to fetch latest dump from remote
        use_cache => 0,
    );
}
