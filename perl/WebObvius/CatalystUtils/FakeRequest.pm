package WebObvius::CatalystUtils::FakeRequest;

use Data::Dumper;
use Apache2::Const ("-compile", qw(:methods));

sub new {
    my ($class, $c, %extra) = @_;

    my %me = (
        # Custom data
        %extra,

        # Non-overrideable stuff
        catalyst_context => $c,
        catalyst_request => $c->request,
        request_time => time,
        notes => $c->stash->{"notes"} || {},
        pnotes => $c->stash->{"pnotes"} || {},
    );

    $c->stash({
        notes => $me{notes},
        pnotes => $me{pnotes}
    });

    $me{pnotes}->{site} = $c;
    
    return bless(\%me, $class);
}

# Catalyst context accessor method
sub c { shift->{catalyst_context}; }

# Catalyst request accessor method
sub cr { shift->{catalyst_request}; }

my @direct_proxy_methods = qw(
    content_encoding 
    content_length 
    content_type 
    hostname 
    parameters
    params
    path_info
    user
);

{
    no strict 'refs';
    for my $n (@direct_proxy_methods) {
        my $method = __PACKAGE__ . "::$n";
        *$method = sub {
            my ($fake, @args) = @_;
            $fake->cr->$n(@args);
        }
    }
    use strict;
}

sub notes {
    my ($this, @args) = @_;
    my $notes = $this->{notes};

    return $notes unless(@args);

    my $old_val = $notes->{$args[0]};
    $notes->{$args[0]} = scalar($args[1]) if($args[1]);

    return $old_val;
}

sub pnotes {
    my ($this, @args) = @_;
    my $notes = $this->{pnotes};

    return $notes unless(@args);

    my $old_val = $notes->{$args[0]};
    $notes->{$args[0]} = $args[1] if($args[1]);

    return $old_val;
}

sub args { return shift->cr->uri->query; }

sub uri {
    shift->cr->uri->path;
}

sub request_time {
    shift->{request_time};
}

sub no_cache {
    warn "no_cache needs to be implemented in __PACKAGE__";
}

sub param {
    my ($self, @args) = @_;
    return $self->cr->parameters unless(@args);
    return $self->cr->param(@args);
}

sub the_request {
    warn "Need to implement the_request in " . __PACKAGE__;
    return shift->cr->uri;
}

sub connection { shift }

sub remote_ip { return shift->cr->address; }

sub is_initial_req {
    exists $_[0]->{is_initial_req} ? $_[0]->{is_initial_req} : 1;
}

sub headers_in {
    my $self = shift;
    my $h = $self->{_headers_in};
    if (!$h) {
        $h = $self->cr->headers();
        bless($h, WebObvius::CatalystUtils::FakeRequest::HeadersTable);
        $self->{_headers_in} = $h;
    }

    return $h;
}

sub headers_out {
    my $self = shift;
    my $h = $self->{_headers_out};

    if (!$h) {
        $h = $self->c->response->headers();
        bless($h, WebObvius::CatalystUtils::FakeRequest::HeadersTable);
        $self->{_headers_out} = $h;
    }

    return $h;
}
sub err_headers_out { shift->headers_out(@_) }

sub register_cleanup {}

sub subprocess_env { shift->c->engine->env }

sub method { return shift->cr->method }

sub method_number {
    my $r = shift->cr;
    my $method = "M_" . $r->method;
    return Apache2::Const->$method;
}

sub status { shift->c->response->status(@_) }

sub send_http_header {}

sub dumpobj {
    my $this = shift;
    no strict 'refs';
    my %asdf = map { $_ => [$this->$_] } (
        @direct_proxy_methods,
        qw (
            notes
            pnotes
            uri
            request_time
        ),
    );
    $asdf{param_test} = [$this->param('asdf')];
    return \%asdf;
}

package WebObvius::CatalystUtils::FakeRequest::HeadersTable;

our @ISA = qw(HTTP::Headers);

sub add { shift->push_header(@_) }
sub get { shift->header(@_) }
sub set { shift->header(@_) }
sub unset { shift->remove_header(@_) }

1;