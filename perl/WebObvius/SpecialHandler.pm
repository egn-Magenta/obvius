package WebObvius::SpecialHandler;

# Base module used for wrinting Special Obvius handler modules

use CGI::Cookie;

sub new {
    my ($classname, %args) = @_;

    $args{'state'} ||= "new";
    return bless(\%args, $classname);
}

# Accessors

sub root_uri { $_[0]->{root_uri} }
sub req { $_[0]->{_request} }
sub obvius { $_[0]->{_obvius} }
sub doc { $_[0]->{_doc} }
sub vdoc { $_[0]->{_vdoc} }
sub state { $_[0]->{state} }
sub set_state { $_[0]->{state} = $_[1] }
sub input { $_[0]->{_input_object} }
sub output { $_[0]->{_output_object} }

sub cookies {
    my $self = shift;
    if(my $cached = $self->req->pnotes('_incoming_cookie_hash')) {
        return $cached;
    }
    my $cookies = CGI::Cookie->fetch || {};
    $self->req->pnotes('_incoming_cookie_hash' => $cookies);
    return $cookies;
}

sub cookie_value {
    my $c = shift->cookies->{(shift)};
    return $c ? $c->value : $c;
}

sub set_cookie {
    my ($self, $name, $value, %extra) = @_;

    my %args = (
        -name => $name,
        -value => $value
    );

    for my $k (qw(expires domain path secure)) {
        $args{$k} = $extra{$k} if(defined($extra{$k}));
    }

    my $cookie = new CGI::Cookie(%args);
    $cookie->bake($self->req);

    return $cookie;
}

# Handlers

sub apache_handler {
    my ($self, $req, $obvius, $doc, $vdoc) = @_;

    $self->{_request} = $req;
    $self->{_obvius} = $obvius;
    $self->{_doc} = $doc;
    $self->{_vdoc} = $vdoc;
    $self->set_state("apache_handler");

    # Return value of undef means no action, can also return HTTP_STATUS
    # codes to perform redirects etc.
    return undef;
}

sub public_mason_handler {
    my ($self, $mason, %ARGS) = @_;

    $self->{_mason} = $mason;
    $self->set_state("public_mason");

    # Returning a non-undef value will cause the public switch to
    # return that value. Can be used to render an anternative component
    return undef;
}

sub common_mason_handler {
    my ($self, $mason, $output, %ARGS) = @_;

    $self->{_mason} = $mason;
    $self->set_state("common_mason");

    # Returning a non-undef value will cause the public switch to
    # return that value. Can be used to render an anternative component
    return undef;
}

sub admin_mason_handler {
    my ($self, $mason, %ARGS) = @_;

    $self->{_mason} = $mason;
    $self->set_state("admin_mason");

    # Returning a non-undef value will cause the public switch to
    # return that value. Can be used to render an anternative component
    return undef;
}

# Data mangling methods
sub before_handle_operation {
    my ($self, $input, $output) = @_;

    $self->{_input_object} = $input;
    $self->{_output_object} = $output;
    $input->param('_special_handler' => $self);

    return undef;
}

sub after_handle_operation {
    my ($self) = @_;

    # Avoid cyclic references
    if(my $input = $self->input) {
        $input->param('_special_handler' => undef);
    }

    delete $self->{_input_object};

    return undef;
}

# Utility methods
sub redirect {
    my ($self, $url, $http_status) = @_;

    $http_status ||= 302;

    my $state = $self->state;
    if($state eq 'apache_handler') {
        my $r = $self->req;
        $r->method('GET');
        $r->headers_in->unset('Content-length');
        $r->content_type('text/html');
        $r->headers_out->add(Location => $url);
        $r->send_http_header;
        return $http_status;
    } elsif($state eq 'public_mason') {
        die "Can not redirect from public mason - " .
            "do it in apache_handler instead";
    } elsif($state eq 'common_mason' or $state eq 'admin_mason') {
        $self->mason->comp(
            '/shared/redirect',
            location => $url,
            http_status => $http_status
        );
        return 1;
    }
    return $http_status;
}

sub render_comp {
    my ($self, $comp, %args) = @_;

    my $mason = $self->mason;
    die sprintf(
        "render_comp called in state %s, no mason object present",
        $self->state
    ) unless($mason);

    $mason->comp($comp, %args);

    return 1;
}

sub render_subsite_comp {
    my ($self, $comp, %args) = @_;
    if($self->state eq 'common_mason') {
        return $self->render_comp($comp, %args);
    }

    # We needs pnotes, so we have to upgrade
    $self->upgrade_request;

    my $r = $self->req;
    $r->pnotes('override_subsite_comp' => $comp);
    $r->pnotes('extra_subsite_comp_args' => \%args);

    return undef;
}

# This method should return the path of the component used to render a named
# customization component called using mason/common/shared/render_special.
sub get_special_component_path {
    my ($self, $compname) = @_;

    return undef;
}

sub disable_obvius_cache {
    my ($self) = @_;
    $self->req->notes('nocache' => 1);
    if(my $output = $self->output) {
        $output->param('obvius_side_effects' => 1);
    }
}

sub disable_browser_cache {
    shift->req->no_cache(1);
}

sub upgrade_request {
    my ($self) = @_;
    my $r = $self->req;
    unless($r->notes('request_upgraded')) {
        $r = $self->{_request} = new Apache2::Request($r);
        $r->notes('request_upgraded' => 1);
    }
}

1;
