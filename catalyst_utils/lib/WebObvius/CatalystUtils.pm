package WebObvius::CatalystUtils;
use Moose;
use namespace::autoclean;

use Catalyst::Runtime 5.80;

use Obvius;
use Obvius::Log;
use WebObvius::CatalystUtils::FakeRequest;

# Set flags and add plugins for the application
#
#         -Debug: activates the debug mode for very useful log messages
#   ConfigLoader: will load the configuration from a Config::General file in the
#                 application's home directory
# Static::Simple: will serve static files from the application's root
#                 directory

use Catalyst qw/
    -Debug
    ConfigLoader
    Static::Simple
/;

extends 'Catalyst';

our $VERSION = '0.01';
$VERSION = eval $VERSION;

# Configure the application.
#
# Note that settings in obvius_catalystutils.conf (or other external
# configuration file that you set up manually) take precedence
# over this when using ConfigLoader. Thus configuration
# details given here can function as a default configuration,
# with an external configuration file acting as an override for
# local deployment.

__PACKAGE__->config(
    name => 'Obvius::CatalystUtils',
    # Disable deprecated behavior needed by old applications
    disable_component_resolution_regex_fallback => 1,
);

my %sites;

sub register_site {
    my ($self, $confname, $module) = @_;

    {
        no strict 'refs';
        $sites{$confname} = {
            public => ${ $module .'::Public' },
            admin => ${ $module .'::Admin' },
            common => ${ $module .'::Admin' },
        };
    }
}

sub siteconfig {
    my ($c) = shift;

    my $siteconfig = $c->stash->{siteconfig};

    unless($siteconfig) {
        my $confname = $ENV{obvius_confname};
        if ($confname) {
            $siteconfig = $sites{$confname};
            if (!$siteconfig) {
                die "No site with config name '$confname'";
            }
        } else {
            die "No confname in environment";
        }
        $c->stash('siteconfig' => $siteconfig);
    }

    return $siteconfig;
}

sub obvius_config {
    my $c = shift;
    my $config = $c->stash->{obvius_config};

    unless($config) {
        $config = $c->siteconfig->{admin}->{OBVIUS_CONFIG};
        $c->stash('obvius_config' => $config);
    }

    return $config;
}

sub obvius {
    my $c = shift;

    my $obvius = $c->stash->{obvius};

    unless($obvius) {
        my $config = $c->obvius_config;
        my $obvius_log = new Obvius::Log(
            $config->param('obvius_log_level') || 1
        );
        my $obvius_args = $c->siteconfig->{admin}->param('obvius_args');
        my $prototype = $c->siteconfig->{admin}->param('obvius_prototype');
        my $doctypes = $obvius_args->{'doctypes'};
        my $fieldtypes = $obvius_args->{'fieldtypes'};
        my $fieldspecs = $obvius_args->{'fieldspecs'};

        $obvius = Obvius->new(
            $config, # config
            undef, # username
            undef, # password
            $doctypes, # cached doctypes,
            $fieldtypes, # cached fieldtypes,
            $fieldspecs, # cached fieldspecs
            log => $obvius_log, # custom log handler
        );

        $c->stash(obvius => $obvius);
    }

    return $obvius;
}

sub fakerequest {
    my($c) = @_;

    my $req = $c->stash->{fakerequest};
    unless($req) {
        $req = WebObvius::CatalystUtils::FakeRequest->new($c);
        $c->stash(fakerequest => $req);
    }

    return $req;
}


# Start the application
__PACKAGE__->setup();


=head1 NAME

WebObvius::CatalystUtils - Catalyst based application

=head1 SYNOPSIS

    script/webobvius_catalystutils_server.pl

=head1 DESCRIPTION

[enter your description here]

=head1 SEE ALSO

L<WebObvius::CatalystUtils::Controller::Root>, L<Catalyst>

=head1 AUTHOR

Jørgen Ulrik B. Krag,,,

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
