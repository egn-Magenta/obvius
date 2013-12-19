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
        my $ip_match = get_origin_ip_from_request($req);
        $ip_match =~ s!\.\d+$!!;
        my $origin_url = $this->request_to_origin_url(
            $req,
            exclude_args => ['t']
        );
        my $sth = $obvius->dbh->prepare(q|
            select
                sso_ticket_id,
                login,
                permanent_request
            from
                sso_tickets
            where
                ticketcode = ?
                and
                origin = ?
                and
                ip_match = ?
                and
                expires >= NOW()
        |);
        $sth->execute($ticketcode, $origin_url, $ip_match);
        if(my ($ticked_id, $login, $permanent) = $sth->fetchrow_array) {
            my $session_id;
            my $inserter = $obvius->dbh->prepare(q|
                insert into login_sessions (
                    login,
                    session_id,
                    last_access,
                    ip_match,
                    permanent
                )
                values (?, ?, UNIX_TIMESTAMP(), ?, ?)
            |);
            my $try_n_times = 10;
            do {
                $session_id = md5_hex(time . rand);
                eval {
                    $inserter->execute(
                        $login,
                        $session_id,
                        $ip_match,
                        $permanent
                    );
                };
            } while ($try_n_times-- and $@);
            die "Can't create session, maybe because of: $@" if $@;

            # Remove the ticket
            $obvius->dbh->prepare(
                'delete from sso_tickets where sso_ticket_id = ?'
            )->execute($ticked_id);

            my $expires = $permanent ? "Expires=Fri, 21-Nov-2036 06:00:00 GMT" : '';
            $req->headers_out->add(
                "Set-Cookie",
                "obvius_login_session=$session_id; path=/;${expires}"
            );
            $req->notes(user => $login);
            $obvius->{USER} = $login;
            return OK;
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
    if(($ENV{'HTTPS'} || '') eq 'on') {
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

sub redirect_to_minisso_login {
    my ($this, $req) = @_;

    return $this->redirect($req, $this->make_sso_login_url($req), 1);
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
    |);

    $sth->execute($session_id, $session_timeout, $ip_match);

    if(my ($login, $time_diff) = $sth->fetchrow_array) {
        $obvius->{USER} = $login;
        $obvius->read_user_and_group_info;

        $req->notes(user => $login);

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

    # Expire the admin-cookie
    my $cookie = CGI::Cookie->new(
        -name => 'obvius_login_session',
        -value => '',
        -expires => '-1M'
    );
    $cookie->bake($req);

    # Delete any sso session for the user
    if(my $user = $obvius->{USER}) {
        $obvius->dbh->prepare(
            'delete from sso_sessions where login = ?'
        )->execute($user);
    }

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
