#!/usr/bin/perl

use strict;
use warnings;

use Obvius;
use Obvius::Config;
use Obvius::Translations;
use Obvius::Translations::Extract;
use Obvius::Translations::Converter;
use File::Basename;
use File::Find;
use File::Path;
use Data::Dumper;

my %action_map = (
    collect => \&collect,
    collect_obvius => \&collect_obvius,
    compile => \&compile,
    import_old => \&import_old,
    update => \&update,
    help => sub { usage(undef, 0); }
);

sub usage {
    my $message = shift;
    my $exitcode = shift;

    if($message) {
        print STDERR "    Error:\n\n      ", $message, "\n\n";
    }
    print <<EOT;
    Usage:

        $0 <action> [<confname>]

    Where action is on of:

        collect <confname>:
            Collect translations from the source files of the site specified
            by the confname and update the relevant template files and
            *_src.po files.

        collect_obvius [obvius_root_dir]:
            Collect translations from the base Obvius source files and update
            the .pot and .po files for the Obvius codebase.

        import_old <dir>:
            Tries to import the old translations (from .xml files) into the
            .po files present under the specified directory.
            The correcsponding collect action should have been run before
            executing this action.

        update <confname>:
            Collects translations for both the Obvius base and the specified
            confname. Run this to ensure all translations are up to date.

        help:
            This message

EOT
    exit defined($exitcode) ? $exitcode : 1;
}

sub get_config {
    my $confname = shift;
    usage("You must specify a confname") unless($confname);
    
    my $config = Obvius::Config->new($confname);
    die "Could not load config for '$confname'" unless($config);

    return $config;
}

sub get_basedir {
    my $config = shift;
    my $base_dir;
    if($config) {
        if($base_dir = $config->param('sitebase')) {
            $base_dir =~ s{/$}{};
        }
    }

    return $base_dir;
}

sub get_obvius_dir {
    my $config = shift;

    my $dir = (
        $ENV{OBVIUS_ROOT_DIR} ||
        ($config ? $config->param('obvius_dir') : undef) ||
        File::Basename::dirname(File::Basename::dirname(__FILE__))
    );

    return -d $dir ? $dir : undef;
}

my $action = $ARGV[0];
usage("You must specify an action") unless($action);

my $action_method = $action_map{$action};
usage("No such action '$action'") unless($action_method);

$action_method->();

sub collect {
    my $confname = $ARGV[1];

    my $config = get_config($confname);

    my $base_dir = get_basedir($config);
    unless($base_dir) {
        usage("No sitebase defined for configuration '$confname'");
    }

    setup_dir($base_dir);
    Obvius::Translations::Extract::extract_all($base_dir);
    my $domain = Obvius::Translations::build_domain_name($config);
    Obvius::Translations::Extract::merge_and_update(
        $base_dir, $domain, get_obvius_dir($config)
    );
}

sub collect_obvius {
    my $root_dir = defined($_[0]) ? $_[0] : $ARGV[1];

    unless($root_dir) {
        $root_dir = get_obvius_dir();
        print STDERR "No obvius root dir specified, using $root_dir instead\n";
    }

    setup_dir($root_dir);
    Obvius::Translations::Extract::extract_all($root_dir);
    Obvius::Translations::Extract::merge_and_update($root_dir, 'dk.obvius');
}

sub import_old {
    my $dir = $ARGV[1];

    usage("You must specify a directory") unless($dir);

    $dir =~ s{/$}{};

    usage("Not a directory: $dir") unless(-d $dir);

    Obvius::Translations::Converter::convert($dir);
}

sub update {
    my $confname = $ARGV[1];

    my $config = get_config($confname);
    
    collect_obvius(get_obvius_dir($config));
    collect();
}

sub setup_dir {
    my ($dir) = @_;

    $dir .= '/i18n';

    unless(-d $dir) {
        mkdir($dir) or die "Could not create directory $dir";
    }
    my $gi_file = $dir . '/.gitignore';
    unless(-f $gi_file) {
        open(FH, ">$gi_file");
        print FH gitignore_template();
        close(FH);
    }
}

sub gitignore_template {
    return <<EOT;
*.pot
!/extra.pot
*.po
*.mo
!dk.obvius.po
!*_src.po
EOT
}
