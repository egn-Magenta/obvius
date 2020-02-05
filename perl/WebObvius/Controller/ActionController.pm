package WebObvius::Controller::ActionController;

use strict;
use warnings;
use utf8;

use WebObvius::MasonCommands;

sub new {
    my ($package) = @_;

    my $environment = {
        doc     => $WebObvius::MasonCommands::doc,
        prefix  => $WebObvius::MasonCommands::prefix,
        uri     => $WebObvius::MasonCommands::uri,
        vdoc    => $WebObvius::MasonCommands::vdoc,
        obvius  => $WebObvius::MasonCommands::obvius,
        doctype => $WebObvius::MasonCommands::doctype,
        r       => $WebObvius::MasonCommands::r,
        m       => $HTML::Mason::Commands::m->instance
    };

    my %obj;
    $obj{_environment} = sub { $environment };

    return bless(\%obj, $package);
}

sub environment { $_[0]->{_environment}() }
sub doc { $_[0]->environment->{doc} }
sub prefix { $_[0]->environment->{prefix} }
sub uri { $_[0]->environment->{uri} }
sub vdoc { $_[0]->environment->{vdoc} }
sub obvius { $_[0]->environment->{obvius} }
sub doctype { $_[0]->environment->{doctype} }
sub r { $_[0]->environment->{r} }
sub m { $_[0]->environment->{m} }
sub action { $_[0]->{action} }

sub translate_prefix { return shift->base_name . ":" }
sub translate_raw { shift; return WebObvius::MasonCommands::__(@_) }
sub translate {
    my ($self, $key, @args) = @_;

    return $self->translate_raw($self->translate_prefix . $key, @args);
}

# The base name, used for building mason paths below mason_base_path
sub base_name {
    my ($self) = @_;

    unless($self->{base_name}) {
        my $pkgname = ref($self) || $self;
        $pkgname =~ s{.*::([^:]+$)}{$1};

        $self->{base_name} = lc($pkgname);
    }

    return $self->{base_name};
}

sub obvius_command_name {
    return "obvius_command_" . $_[0]->base_name;
}

# The base path used for calling mason components
sub mason_base_path { "/action/" }

# The path to where templates are stored
sub template_root {
    my ($self) = @_;

    my $action = $self->base_name;

    return $self->mason_base_path . "${action}_files/";
}

# Given a template name, return the full path to the template, postfixed with .mason
sub template_path {
    my ($self, $template) = @_;

    return $self->template_root . $template . ".mason";
}

# Render a template and return the generated content.
# equipvalent to $m->scomp(...)
sub render_template {
    my ($self, $template, %args) = @_;

    return $self->m->scomp(
        $self->template_path($template),
        %args,
        controller => $self
    );
}

# output a template, equipvalent to $m->comp(...) or <& template &>
sub output_template {
    my ($self, $template, %args) = @_;

    return $self->m->comp(
        $self->template_path($template),
        %args,
        controller => $self
    );
}

sub dispatch {
    my ($self, @args) = @_;

    my $r = $self->r;

    my $action = $r->param('action') || 'default';
    $self->{action} = $action;

    if($self->UNIVESAL::can("perform_${action}")) {
        my $method = "perform_${action}";
        return $self->$method(@args);
    } else {
        return $self->dispatch_default(@args);
    }
}

sub dispatch_default {
    my ($self, @args) = @_;

    my $action = $self->action;
    my $pkg = __PACKAGE__;

    warn "No perform_${action} method. " .
         "Maybe add sub { shift->output_action_template(\@_) } to $pkg.\n";

    return $self->output_action_template(@args);
}

sub output_action_template {
    my ($self, @args) = @_;

    my $action = $self->action;
    
    return $self->output_template($action, @args);
}

# Builds a link that refers back to the the controller with
# certain request parameters removed and certain extra parameters
# added.
# Example:
#  $controller->build_link(
#    remove => "order_by",
#    append => "order_by=myfield:desc"
#  )
# Would create a link that links back to the current page, but changes
# "order_by" to "myfield:desc"
#
sub build_link {
    my ($self, %args) = @_;

    my $remove = $args{remove} || [];
    $remove = [$remove] unless(ref($remove));

    my %remove = map { $_ => 1 } @$remove;

    my $request_param_hash = $self->request_param_hash;

    my @pairs;

    foreach my $name (@{ $request_param_hash->{order} }) {
        next if($remove{$name});
        my $values = $request_param_hash->{values}->{$name} || [];
        foreach my $val (@$values) {
            push(@pairs, "${name}=" . URI::Escape::uri_escape($val));
        }
    }

    if(my $append = $args{append}) {
        push(@pairs, $append);
    }

    my $prefix = $args{no_prefix} ? "" : $self->prefix;

    return $prefix . $self->uri . "?" . join("&", @pairs);
}

1;
