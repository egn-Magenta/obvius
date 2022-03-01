package WebObvius::CatalystUtils::Base;

use strict;
use warnings;
use utf8;

use Obvius;
use Obvius::Log;
use WebObvius::CatalystUtils::FakeRequest;
use MIME::Base64 qw(decode_base64);
use HTTP::Status qw(:constants);

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

=item api_auth_check

Looks in request headers and requests params for an API key and if
one is found tries to use it to authenticate a user.

API-keys can be specified using either a `X-Obvius-Admin-Api-Key` header.

If authentication via API key fails standard admin authentication is performed.
=cut
sub api_auth_check {
    my ($c, $return_success_or_fail) = @_;

    $c->set_admin_translations;

    my $api_key = $c->request->header('x-obvius-admin-api-key');

    if($api_key && $api_key eq $c->obvius->config->param('admin_api_key')) {
        $c->obvius->{USER} = 'admin';
        return 1;
    }

    return $c->admin_auth_check($return_success_or_fail);
}

sub admin_auth_check {
    my ($c, $return_success_or_fail) = @_;
    # $c is self

    my $req = $c->fakerequest;
    # Subclasses may overload admin_auth_check to use a different mechanism
    my $auth_res = $c->basic_authen_handler($req);
    if (my $status = $c->response->status) {
        if (!$auth_res) {
            $auth_res = $status;
        }
    }

    if (! grep { $auth_res == $_ } (0, 200)) {
        # If $return_success_or_fail is set, return failure to calling method
        # otherwise detach and let $c->response redirect to login
        return $return_success_or_fail ? 0 : $c->detach();
    }
    # Ensure the username is stored on the obvius obj for later use
    $c->obvius->{USER} = $req->notes('user');
    return 1;
}

sub basic_auth_realm {
    return "Obvius";
}

sub basic_auth_failed {
    my ($c) = @_;
    $c->response->header('www-authenticate' => 'Basic realm="'.$c->basic_auth_realm.'"');
    $c->response->status(401);
    $c->response->body('');
    return $c->detach;
}

sub basic_authen_handler {
    my ($c) = @_;

    my $req = $c->fakerequest;

    my $auth_header = $req->headers_in->{'authorization'};
    if (!$auth_header) {
        return $c->basic_auth_failed;
    }

    my ($credentials_b64) = ($auth_header =~ m/Basic ([\w=]+)/);
    if (!$credentials_b64) {
        return $c->basic_auth_failed;
    }
    my ($login, $password) = split(':', decode_base64($credentials_b64));

    if (!$login || !$password) {
        return $c->basic_auth_failed;
    }

    my $obvius = Obvius->new($c->obvius->config, $login, $password);
    if (!$obvius) {
        # Obvius constructor will return undef if $login is set and credentials are incorrect
        return $c->basic_auth_failed;
    }

    my $user = $obvius->get_user($login);
    if (exists($user->{admin}) && !$user->{admin}) {
        # We are not checking whether the user is an admin user, only if they can access /admin
        return $c->basic_auth_failed;
    }

    $req->notes(user=>$login);

    return 200;
}

sub set_admin_translations {
    my ($c) = @_;

    $c->siteconfig->{admin}->setup_translations($c->fakerequest, $c->obvius);
}

sub standalone_admin_mason_interp {
    my ($c) = @_;

    if(!$c->stash->{standalone_admin_mason_interp}) {
        # We can not use the admin interp, as this is bound to apache,
        # but we can create a new one with the same settings.
        my $admin_interp = $c->siteconfig->{admin}->{handler}->{interp};
        my $new_interp = HTML::Mason::Interp->new(
            comp_root => $admin_interp->{comp_root},
            escape_flags => $admin_interp->{escapes},
            data_dir => $admin_interp->{data_dir},
            allow_globals => $admin_interp->{compiler}->{allow_globals},
            # Turn off autohandlers, since the admin one requires $doc to
            # be set.
            autohandler_name => '',
        );
        $c->stash->{standalone_admin_mason_interp} = $new_interp;
    }

    return $c->stash->{standalone_admin_mason_interp};
}

sub expand_admin_mason {
    my ($c, $comp, %ARGS) = @_;

    $c->set_admin_translations;

    my $interp = $c->standalone_admin_mason_interp;

    # Set global $r unless it was passed in %ARGS
    if(!$ARGS{'$r'}) {
        $interp->set_global('$r' => $c->fakerequest);
    }

    # Allow setting global variables by setting for example $ARGS{'$docs'}
    foreach my $g (@{$interp->{compiler}->{allow_globals} || []}) {
        if(my $val = delete $ARGS{$g}) {
            $interp->set_global($g => $val);
        }
    }

    my $output = '';

    my $debug_mason = $c->obvius->config->param('debug_mason');

    my $mason_request = $interp->make_request(
        max_recurse     => 64, # Default is 32,
        autoflush       => 0,
        out_method      => \$output,
        error_mode      => $debug_mason ? 'output' : 'fatal',
        error_format    => $debug_mason ? 'html' : 'text',
        dhandler_name   => '', # No dhandlers in standalone mode
        comp            => $comp,
        args            => [%ARGS]
    );

    my $retval = eval { $mason_request->exec };
    if (my $err = $@) {
        if(isa_mason_exception($err, 'Abort')) {
            $retval = $err->aborted_value;
        } elsif(isa_mason_exception($err, 'Decline')) {
            $retval = $err->declined_value;
        } else {
            # Rethrow the exception
            croak $err;
        }
    }

    if($retval && $retval != HTTP_OK) {
        $c->response->status($retval);
        return $c->detach;
    }

    return $output;
}


=item json_result($status, $data)

Sets the specified HTTP status code and outputs the given data as JSON
in the HTTP response. Aborts further processing and returns the response
to the client.

Arguments:

    $status
        HTTP status code to set

    $data
        Data to be returned as JSON
=cut
sub json_result {
    my ($c, $status, $data) = @_;

    my $json_string = JSON->new->utf8->encode(
        Obvius::CharsetTools::mixed2utf8($data)
    );

    $c->response->status($status);
    $c->response->body($json_string);
    $c->response->content_length(length $json_string);
    $c->response->content_type('application/json; charset=utf-8');

    return $c->detach;
}

=item json_error($status, $message)

Sets HTTP status code and returns an error message in JSON format to
the client. Further processing of the request is aborted.

Arguments:

    $status
        HTTP status code to set

    $message
        The error message to return to the client.

=cut
sub json_error {
    my ($c, $status, $message) = @_;

    return $c->json_result($status, {
        http_status => $status,
        http_status_message =>
            $status . " " . HTTP::Status::status_message($status),
        message => $message
    });

}


1;
