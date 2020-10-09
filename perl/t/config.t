#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use Test::Exception;
use File::Temp qw(tempdir);

require_ok("Obvius::Config");

my $confdir = tempdir(CLEANUP => 1);

my $defaults_file   = "${confdir}/defaults.conf";
my $main_file       = "${confdir}/test.conf";
my $env_file        = "${confdir}/test-environment.conf";
my $local_file      = "${confdir}/test-local.conf";

my %contents;

$contents{$defaults_file} =<<'EOT';
defaults_value = default
value0 = from_defaults
value1 = from_defaults
value2 = from_defaults
value3 = from_defaults
EOT

$contents{$main_file} =<<EOT;
main_value = main
value1 = from_main
test = test
list_value = (a, b, c, d)
spacing_does_not_matter \t  =   \t true  \t
EOT

$contents{$env_file} =<<'EOT';
env_value = env
value2 = from_env
EOT

$contents{$local_file} =<<'EOT';
local_value = local
value3 = from_local
EOT

# Set the directory we use under testing
lives_ok {
    $Obvius::Config::confdir = $confdir;
} 'Assign test config directory ok';

is($Obvius::Config::confdir, $confdir, 'Test directory set ok');

lives_ok {
    foreach my $filename (sort keys %contents) {
        open(FH, ">", $filename) or die "Could not open $filename for writing";
        print FH $contents{$filename};
        close(FH);
    }
} 'Test config files written ok';

# Try loading a config that does not exist
dies_ok {
    Obvius::Config->new("Does not exist");
} 'Loading non-existing configuration fails';

my $config;

lives_ok {
    $config = Obvius::Config->new("test");
} 'Test config loads ok';

is(ref($config), 'Obvius::Config', 'Config object is an Obvius::Config object');

is($config->param('defaults_value'), 'default', 'Expected value from defaults');
is($config->param('main_value'), 'main', 'Expected value from main');
is($config->param('env_value'), 'env', 'Expected value from env');
is($config->param('local_value'), 'local', 'Expected value from local');

is($config->param('value0'), 'from_defaults', 'Non-overriden value is from defaults');
is($config->param('value1'), 'from_main', 'Overriding in main works');
is($config->param('value2'), 'from_env', 'Overriding in environment works');
is($config->param('value3'), 'from_local', 'Overriding in local works');

is($config->param('does_not_exist'), undef, 'Value for non-existing key is undef');

is($config->param('TesT'), 'test', 'Case of key does not matter');

is($config->param('test' => 'test2'), 'test', 'Setting new value returns old');
is($config->param('test'), 'test2', 'New value is set correctly');
$config->param('test' => '');
is($config->param('test'), '', 'Value can be reset to empty string');

is_deeply($config->param('list_value'), [qw(a b c d)], 'List values work');

is($config->param('spacing_does_not_matter'), 'true', 'Extra whitespace is not an issue');

{
    # New value to check for
    my $value = "overriden from shell env";

    # Set environment that overrides config at load time
    local $ENV{OBVIUS_CONFIG_TEST_TEST} = $value;

    my $env_conf = Obvius::Config->new("test");

    is($env_conf->param('test'), $value, 'Overriding with %ENV works');
}

done_testing();
