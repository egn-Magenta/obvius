#!/usr/bin/env perl

=head1 Documentation

=begin text
    ### PURPOSE ###
    Run all of the migrations! This script invokes Obvius::DatabaseMigrator
    using the directories specified in the site conf for the specified
    `confname`. It is also possible to specifiy dirs when invoking this script.

    The script attempts to fail as many times as possible before running
    migrations to ensure we don't end up in a broken state. When we finally
    invoke Obvius::DatabaseMigrator, we know that directories containing
    migrations are valid.

    The migration table name used to track migrations is hardcoded and corresponds
    to the table name used in the migration that creates the table.

    ### INVOCATION ###

    perl db/migrate.pl --confname <conf> [--migration_dirs </dir1/,/dir2/>]

    ### OPTIONS ###

    --confname: Required.

    --migration_dirs: A comma-separated list of directories containing migrations.
    Read from site config if not provided

    ### SAFE TO USE? ###

    No. Running this script will trigger database operations if there are new migrations.

=end text

=cut

use strict;
use warnings;
use utf8;

use Getopt::Long;

use Obvius;
use Obvius::DatabaseMigrator;

my $migration_dirs = '';
my $migration_table = 'applied_migrations';
my $confname = '';

GetOptions(
    'migration-dirs=s' => \$migration_dirs,
    'confname=s' => \$confname,
);

die 'Please specify a confname' if !$confname;

my $obvius_config = Obvius::Config->new($confname);
die "Could not load Obvius for $confname" if !$obvius_config;

if (!$migration_dirs) {
    $migration_dirs = $obvius_config->param('migration_dirs');
    die 'No migration dir(s) specified' if !$migration_dirs;
}

my @dirs = split ',', $migration_dirs;
foreach my $migration_dir (@dirs) {
    die "$migration_dir is not a valid directory" if ! -d $migration_dir;
}

foreach my $migration_dir (@dirs) {
    my $migrator = Obvius::DatabaseMigrator->new_with_obvius_config(
        $obvius_config,
        {
            'migrations_dir' => $migration_dir,
            'migration_table' => $migration_table,
        }
    );
    $migrator->create_or_update_database();
}
