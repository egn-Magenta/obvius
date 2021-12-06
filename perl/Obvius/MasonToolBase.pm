package Obvius::MasonToolBase;

use strict;
use warnings;
use utf8;

use HTML::Mason::Interp;
use WebObvius::MasonCommands;

use base 'Obvius::ToolBase';
use URI;

sub new {
    my ($classname, $obvius_or_config) = @_;

    # If called without a obvius or config, try to get it from Mason
    # global variable
    $obvius_or_config ||= $WebObvius::MasonCommands::obvius;

    return $classname->SUPER::new($obvius_or_config);
}

# Mason name, can be public, admin or common
sub mason_name { "public" }

sub mason {
    my ($self) = @_;

    # If running under mason we will already have an instance, so just
    # use that.
    # This will also work as a cache for the instance created below.
    if($HTML::Mason::Commands::m) {
        return $HTML::Mason::Commands::m;
    }

    warn(
        __PACKAGE__ . '::mason is returning an mason interp object, ' .
        'which is probably not what is needed. Look at the ' .
        __PACKAGE__ . '::run_in_mason_context for how to run code ' .
        'in a prober mason context and get access to a mason request ' .
        'handler object instead.'
    );
    return $self->interp;

}

# Returns the current mason ($m) object or generates a new Mason object
# for admin, public or comman as specified by the `mason_name` method.
sub interp {
    my ($self) = @_;


    my $base_dir = $self->obvius->config->param('sitebase');
    die "No sitebase defined" unless($base_dir);
    $base_dir =~ s{/$}{};

    my $obvius_dir = $self->obvius->config->param('obvius_dir');
    die "No obvius_dir defined" unless($obvius_dir);
    $obvius_dir =~ s{/$}{};

    my $output = '';
    $self->{_mason_output} = \$output;

    my $user = $ENV{MOD_PERL} ? 'mod_perl' :
               $ENV{USER}|| getpwuid($<);
    die "No username in environment" unless($user);

    my %comp_roots = (
        public => [
            [docroot  =>"$base_dir/docs"],
            [sitecomp =>"$base_dir/mason/public"],
            [globalpubliccomp =>"$obvius_dir/mason/public"],
            [commoncomp => "$base_dir/mason/common"],
            [globalcommoncomp =>"$obvius_dir/mason/common"],
        ],
        admin => [
            [docroot  =>"$base_dir/docs"],
            [sitecomp =>"$base_dir/mason/admin"],
            [admincomp=>"$obvius_dir/mason/admin"],
            [commoncomp => "$base_dir/mason/common"],
            [globalcommoncomp =>"$obvius_dir/mason/common"],
        ],
        common => [
            [docroot  =>"$base_dir/docs"],
            [sitecomp =>"$base_dir/mason/common"],
            [globalcommoncomp =>"$obvius_dir/mason/common"],
        ]
    );

    my $mason_name = $self->mason_name;

    my $comp_roots = $comp_roots{$mason_name};

    if(!$comp_roots) {
        die "No component roots defined for $mason_name";
    }

    my @default_escape_flags;
    if ($self->obvius_config->param('feature_flag_default_html_escape')) {
        push(@default_escape_flags, 'h');
    }

    my $interp = HTML::Mason::Interp->new(
        comp_root => $comp_roots,
        data_dir => $base_dir . "/var/masontmp_for_${user}" ,
        out_method => $self->{_mason_output},
        allow_globals => [qw(
            $r
            $obvius
            $doc
            $vdoc
            $doctype
            $prefix
            $uri
        )],
        in_package => "WebObvius::MasonCommands",
        # Disable autohandlers
        autohandler_name => "",
        default_escape_flags => \@default_escape_flags
    );
    $interp->set_global('$obvius' => $self->obvius);

    return $interp
}

sub run_in_mason_context {
    my ($self, $sub_ref) = @_;

    my $interp = $self->interp;

    # Make a component that just executes the sub that was sent in
    my $comp = q|
        <%args>
            $method
        </%args>
        <%init>
            return $method->($m, $r);
        </%init>'
    |;
    #$comp =~ s/^\s+//gm;
    my $wrapper_comp = $interp->make_component(comp_source => $comp);

    # Run the component with the sub as an argument
    return $interp->make_request(
        comp => $wrapper_comp, args=>[method => $sub_ref]
    )->exec;
}

sub doc { $WebObvius::MasonCommands::doc; }
sub vdoc { $WebObvius::MasonCommands::vdoc }
sub prefix { $WebObvius::MasonCommands::prefix }
sub uri { $WebObvius::MasonCommands::uri }
sub doctype { $WebObvius::MasonCommands::doctype }
sub r { $WebObvius::MasonCommands::r }

sub set_document {
    my ($self, $doc) = @_;

    if(!$doc) {
        return $self;
    }

    my $obvius = $self->obvius;
    my $vdoc = $obvius->get_public_version($doc) ||
               $obvius->get_latest_version($doc);
    my $doctype = $obvius->get_doctype_by_id($vdoc->Type);
    my $uri = $obvius->get_doc_uri($doc);

    $WebObvius::MasonCommands::doc = $doc;
    $WebObvius::MasonCommands::vdoc = $vdoc;
    $WebObvius::MasonCommands::doctype = $doctype;
    $WebObvius::MasonCommands::uri = $uri;

    return $self;
}

sub set_prefix {
    my ($self, $prefix) = @_;

    $prefix ||= '';

    $WebObvius::MasonCommands::prefix = $prefix;

    return $self;
}

sub set_request {
    my ($self, $uri_with_query) = @_;

    if($ENV{MOD_PERL}) {
        die "You can not set the request while running under mod_perl";
    }

    # Late import of FakeRequest since we do not want it loaded under
    # mod_perl.
    if(!$INC{"WebObvius/FakeRequest.pm"}) {
        require WebObvius::FakeRequest;
    }

    my $uri = URI->new($uri_with_query);

    my $path = $uri->path;
    if($path =~ s/^\/admin//) {
        $self->set_prefix("/admin");
    }
    if(my $doc = $self->obvius->lookup_document($path)) {
        $self->set_document($doc);
    }

    my $request = WebObvius::FakeRequest->new(uri => $uri->path);

    # Convert URI query_form to the params expected in Obvius mason
    # where single values are returned as is and multi-values are
    # returned as an array-ref.
    my @qparams = $uri->query_form;
    while(@qparams) {
        my ($key, $value) = (shift(@qparams), shift(@qparams));
        my $existing = $request->param($key);
        if(defined($existing)) {
            if(ref($existing) eq 'ARRAY') {
                push(@$existing, $value);
            } else {
                $request->param($key => [$existing, $value]);
            }
        } else {
            $request->param($key => $value);
        }
    }

    $WebObvius::MasonCommands::r = $request;

    return $self;
}

sub expand_mason {
    my ($self, $path, @args) = @_;

    if($HTML::Mason::Commands::m) {
        return $HTML::Mason::Commands::m->scomp($path, @args);
    } else {
        return $self->run_in_mason_context(sub {
            my ($m, $r) = @_;

            return $m->scomp($path, @args);
        });
    }
}

1;
