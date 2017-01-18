package WebObvius::CatalystUtils::Base;

use strict;
use warnings;
use utf8;

use Obvius;
use Obvius::Log;
use WebObvius::CatalystUtils::FakeRequest;

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

sub admin_auth_check {
    my ($c) = @_;

    my $auth_res = $c->siteconfig->{admin}->session_authen_handler(
        $c->fakerequest
    );
    if (my $status = $c->response->status) {
        if (!$auth_res) {
            $auth_res = $status;
        }
    }

    if (! grep { $auth_res == $_ } (0, 200)) {
        return $c->detach();
    }
}

sub set_admin_translations {
    my ($c) = @_;

    $c->siteconfig->{admin}->setup_translations($c->fakerequest, $c->obvius);
}

1;