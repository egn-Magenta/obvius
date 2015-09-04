package WebObvius::Login::MiniSSO;

use strict;
use warnings;

use CGI::Cookie;
use Apache2::Const qw(:common);
use URI::Escape;
use WebObvius::RequestTools;
use Digest::MD5 qw(md5_hex);

sub minisso_login_handler {
    my ($this, $req) = @_;
    
    return OK if not $req->is_initial_req;

    my $obvius = $this->obvius_connect($req,
                                       undef,
                                       undef,
                                       $this->{SUBSITE}->{DOCTYPES},
                                       $this->{SUBSITE}->{FIELDTYPES},
                                       $this->{SUBSITE}->{FIELDSPECS});

    return SERVER_ERROR if not $obvius;

    return OK if $this->already_logged_in($obvius, $req);

    my $r = WebObvius::Apache::apache_module('Request')-> new($req);
    if(my $ticketcode = $r->param('t')) {
        my $origin_url = $this->request_to_origin_url(
            $req,
            exclude_args => ['t']
        );
        my $sth = $obvius->dbh->prepare(q|
            select
                t.sso_ticket_id,
                s.login,
                s.permanent,
                s.sso_session_id,
                s.ip_match
            from
                sso_tickets t
                join
                sso_sessions s on (
                    t.sso_session_id = s.sso_session_id
                )
            where
                t.ticketcode = ?
                and
                t.origin = ?
                and
                t.expires >= NOW()
        |);
        $sth->execute($ticketcode, $origin_url);
        my (
            $ticket_id,
            $login,
            $permanent,
            $sso_session_id,
            $ip_pattern
        ) = $sth->fetchrow_array;
        if($ticket_id) {
            my $client_ip = get_origin_ip_from_request($req);

            # Check IP match, redirect to error message if it fails
            if ($client_ip !~ m{^\Q$ip_pattern\E}) {
                return $this->redirect_to_ip_mismatch($req, $ip_pattern);
            }

            my $session_id;
            my $inserter = $obvius->dbh->prepare(q|
                insert into login_sessions (
                    login,
                    session_id,
                    last_access,
                    ip_match,
                    permanent,
                    sso_session_id
                )
                values (?, ?, UNIX_TIMESTAMP(), ?, ?, ?)
            |);
            my $try_n_times = 10;
            do {
                $session_id = md5_hex(time . rand);
                eval {
                    $inserter->execute(
                        $login,
                        $session_id,
                        $ip_pattern,
                        $permanent,
                        $sso_session_id
                    );
                };
            } while ($try_n_times-- and $@);
            die "Can't create session, maybe because of: $@" if $@;

            # Remove the ticket
            $obvius->dbh->prepare(
                'delete from sso_tickets where sso_ticket_id = ?'
            )->execute($ticket_id);

            my $expires = $permanent ? "Expires=Fri, 21-Nov-2036 06:00:00 GMT" : '';
            $req->err_headers_out->add(
                "Set-Cookie",
                "obvius_login_session=$session_id; path=/;${expires}"
            );
            $req->notes(user => $login);
            $obvius->{USER} = $login;

            # If admin-request check for the allow-admin-access field in the
            # userdata and fail if it is not set.
            if($r->uri =~ m{^/admin($|/)}) {
                my $userdata = $obvius->get_user($obvius->{USER});
                if(exists $userdata->{admin} and not $userdata->{admin}) {
                    return $this->redirect(
                        $r, $this->make_no_access_url($r), 1
                    );
                }
            }

            # Redirect to current URL without the t parameter
            return $this->redirect(
                $req,
                $this->request_to_origin_url(
                    $req,
                    exclude_args => ['t']
                )
            );
        } else {
            return $this->redirect_to_minisso_login($req);
        }
    }

    return $this->redirect_to_minisso_login($req);
}

# Overwrite the old session authentication handler
sub session_authen_handler {
    return minisso_login_handler(@_);
}

sub request_to_origin_url {
    my ($this, $req, %options) = @_;

    my $url;
    my $config = $this->param('obvius_config');
    if(($req->subprocess_env('IS_HTTPS') || '') eq 'on') {
        my $https_roothost = $config->param('https_roothost');
        $url = "https://$https_roothost" . $req->uri;
    } else {
        my $roothost = $config->param('roothost') || $req->hostname;
        $url = "http://$roothost" . $req->uri;
    }
    if(my $args = $req->args) {
        if(my $ex_args = $options{exclude_args}) {
            for my $rem (@$ex_args) {
                $args =~ s!(^|&)$rem=[^&]+!!g;
            }
            $args =~ s!^&!!;
        }
        $url .= "?" . $args if($args);
    }

    return $url;
}

sub make_sso_login_url {
    my ($this, $req) = @_;

    my $config = $this->param('obvius_config');
    my $host = $config->param('https_roothost') ||
               $config->param('roothost') ||
               $req->hostname;

    my $return_uri = uri_escape(
        $this->request_to_origin_url($req, exclude_args => ['t'])
    );

    return "https://${host}/system/sso_login.mason?origin=$return_uri";
}

sub make_no_access_url {
    my ($this, $req) = @_;

    my $config = $this->param('obvius_config');
    my $host = $config->param('https_roothost') ||
               $config->param('roothost') ||
               $req->hostname;

    my $url = "https://${host}/system/no_admin_access.mason";
    if(my $user = $req->notes('user')) {
        $url .= '?user=' . $user;
    }

    return $url;
}

sub make_ip_mismatch_url {
    my ($this, $req, $matched_against) = @_;

    my $config = $this->param('obvius_config');
    my $host = $config->param('https_roothost') ||
               $config->param('roothost') ||
               $req->hostname;

    my $url = "https://${host}/system/sso_ip_mismatch.mason";
    $url .= "?client_ip=" . uri_escape(get_origin_ip_from_request($req));
    $url .= "&match_ip=" . uri_escape($matched_against);
    $url .= "&origin=" . uri_escape($this->request_to_origin_url($req));

    return $url;
}


sub redirect_to_minisso_login {
    my ($this, $req) = @_;

    return $this->redirect($req, $this->make_sso_login_url($req), 1);
}

sub redirect_to_ip_mismatch {
    my ($this, $req, $matched_against) = @_;

    my $url = $this->make_ip_mismatch_url($req, $matched_against);
    return $this->redirect($req, $url, 1);
}

sub already_logged_in {
    my ($this, $obvius, $req) = @_;

    my $session_id;
    my %cookies = CGI::Cookie->fetch;
    $session_id = $cookies{obvius_login_session}->value if($cookies{obvius_login_session});

    return 0 if not $session_id;

    # Default timeout is 20 hours
    my $session_timeout = (
        $obvius->config->param('login_session_timeout') ||
        20 * 60
    ) * 60;

    my $ip_match = get_origin_ip_from_request($req);
    $ip_match =~ s!\.\d+$!!;

    my $sth = $obvius->dbh->prepare(q|
        select
            login,
            UNIX_TIMESTAMP() - last_access time_diff
        from
            login_sessions
        where
            session_id = ?
            and
            (
                permanent = 1
                or
                last_access >= (UNIX_TIMESTAMP() - ?)
            )
            and
            ip_match = ?
            and
            sso_session_id is not null
    |);

    $sth->execute($session_id, $session_timeout, $ip_match);

    if(my ($login, $time_diff) = $sth->fetchrow_array) {
        $obvius->{USER} = $login;
        $obvius->read_user_and_group_info;

        $req->notes(user => $login);

        # Not logged in if request is to admin and the user does not have the
        # allow-admin-login flag
        if($req->uri =~ m{^/admin($|/)}) {
            my $userdata = $obvius->get_user($login);
            return 0 if(exists $userdata->{admin} and not $userdata->{admin});
        }

        # Update last_access timestamp
        if($time_diff > 60) {
            my $sth = $obvius->dbh->prepare(q|
                update login_sessions
                set last_access=UNIX_TIMESTAMP()
                where session_id = ?
            |);
            $sth->execute($session_id);
        }

        return 1;
    }

    return 0;
}

sub perform_sso_logout {
    my ($this, $req, $obvius) = @_;

    # Delete the sso_session, invalidating all login_sessions that belong
    # to it
    my $session_id;
    my %cookies = CGI::Cookie->fetch;
    $session_id = $cookies{obvius_login_session}->value if($cookies{obvius_login_session});

    if($session_id) {
        my $sth = $obvius->dbh->prepare(q|
            select
                sso_session_id
            from
                login_sessions
            where
                session_id = ?
        |);
        $sth->execute($session_id);
        if(my ($sso_session_id) = $sth->fetchrow_array) {
            $obvius->dbh->prepare(
                'delete from sso_sessions where sso_session_id = ?'
            )->execute($sso_session_id);
        }
    }

    # Expire the admin-cookie
    my $cookie = CGI::Cookie->new(
        -name => 'obvius_login_session',
        -value => '',
        -expires => '-1M'
    );
    $cookie->bake($req);

    # Make the URL we want to redirect to afterwards
    my $config = $this->param('obvius_config');
    my $host = $config->param('https_roothost') ||
               $config->param('roothost') ||
               $req->hostname;

    my $return_uri = uri_escape(
        $this->request_to_origin_url($req, exclude_args => [
            't',
            'obvius_command_logout'
        ])
    );

    return "https://${host}/system/sso_login.mason" .
           "?origin=$return_uri&logged_out=true";

}

1;
