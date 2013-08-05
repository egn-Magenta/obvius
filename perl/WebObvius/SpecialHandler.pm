package WebObvius::SpecialHandler;

# Base module used for wrinting Special Obvius handler modules

sub new {
    my ($classname, %args) = @_;

    $args{'state'} = "new" unless($args{'state'});
    return bless(\%args, $classname);
}

# Accessors

sub req { shift->{_request} }
sub obvius { shift->{_obvius} }
sub doc { shift->{_doc} }
sub vdoc { shift->{_vdoc} }
sub state { shift->{_state} }
sub set_state { shift->{_state} = shift }
sub input { shift->{_input_object} }
sub output { shift->{_output_object} }

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
        $r->header_out('Location'=>$url);
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
    return 1;
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

    my $r = $self->req;
    $r->pnotes('override_subsite_comp' => $comp);
    $r->pnotes('extra_subsite_comp_args' => \%args);

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

1;