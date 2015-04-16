package WebObvius::FormEngine;

use strict;
use warnings;
use utf8;

use Data::Dumper;
use WebObvius::FormEngine::Fields;

my $formcount = 0;

sub new {
    my ($package, $formname, $mason, %options) = @_;

    my @themes = ("default");
    if(my $theme = delete $options{theme}) {
        unshift(@themes, $theme);
    }

    my $ref = {
        fields => [],
        field_by_name => {},
        anon_field_nr => 0,
        themes => \@themes,
        comp_path_cache => {},
        render_as => "div",
        method => "post",
        errors => [],
        %options
    };

    $ref->{formname} = $formname;
    $ref->{mason} = $mason;

    return bless($ref, $package);
}

sub mason { $_[0]->{mason} }
sub obvius { $_[0]->execute_comp('get_obvius.mason') }
sub name { $_[0]->{formname} }
sub method { $_[0]->{method} }
sub form_id { $_[0]->{form_id} || $_[0]->{formname} }
sub action { $_[0]->{action} || '' }
sub field { $_[0]->{fields_by_name}->{$_[1]} }
sub fields { $_[0]->{fields} }
sub field_list { @{ $_[0]->fields } }
sub fields_list { @{ $_[0]->fields } }
sub errors { $_[0]->{errors} }
sub error_list { @{ $_[0]->errors || [] } }
sub errors_list { @{ $_[0]->errors || [] } }
sub warnings { $_[0]->{warnings} || [] }
sub warning_list { @{ $_[0]->warnings } }
sub warnings_list { @{ $_[0]->warnings } }

sub translate_labels { $_[0]->{translate_labels} }
sub html5 { $_[0]->{html5} }

# Field creators
{
    no strict 'refs';
    foreach my $type (WebObvius::FormEngine::Fields::get_types()) {
        my $target_method = "${type}_field";
        my $create_method = __PACKAGE__ . "::${target_method}";
        my $add_method = __PACKAGE__ . "::add_${type}_field";
        
        *{$create_method} = sub {
            my $self = shift;
            WebObvius::FormEngine::Fields->$target_method($self, @_);
        };
        *{$add_method} = sub {
            my $self = shift;
            my $f = WebObvius::FormEngine::Fields->$target_method(
                $self, @_
            );
            $self->add_field($f);
            return $self;
        };
    }
}

sub extra_form_attributes {
    my $self = shift;

    my $extra_attrs = $self->{extra_form_attributes} || {};

    my %extra = (%$extra_attrs, @_);

    my @result;
    foreach my $key (sort keys %extra) {
        my $value = $extra{$key};
        $value = [ $value ] unless(ref($value) eq  'ARRAY');
        foreach my $v (@$value) {
            $v =~ s{"}{&quot;}g;
            push(@result, q|${key}="${v}"|);
        }
    }

    return join(" ", @result);
}

sub set_fields {
    my $self = shift;

    $self->{fields} = [];
    $self->{field_by_name} = {};
    $self->{anonymous_field_nr} = 0;

    $self->add_fields(@_);

    return $self;
}

sub add_fields {
    my $self = shift;

    while (my $fdata = shift) {
        my $ref = ref($fdata);
        if($ref eq 'ARRAY') {
            $self->add_fields(@$fdata);
        } elsif($ref eq 'HASH') {
            $self->add_field(
                $self->make_field($fdata)
            );
        } elsif(!$ref) {
            # Assume @_ (including $fdata) contains elements of a hash
            $self->add_field(
                $self->make_field({$fdata, @_})
            );
            last;
        } else {
            $self->add_field($fdata);
        }
    }

    return $self;
}

sub set_action {
    my ($self, $action) = @_;
    $self->{action} = $action;
    return $self;
}

sub make_anonymous_fieldname {
    my ($self) = @_;

    return $self->{formname} . "_anonfield" . ++$self->{anon_field_nr};
}

sub make_field {
    my $self = shift;

    return WebObvius::FormEngine::Fields::make_field($self, @_);
}

sub add_field {
    my ($self, $field) = @_;

    unless($field->isa('WebObvius::FormEngine::Fields::Base')) {
        die "Can't add field of type " . (ref($field) || $field);
    }
    
    push(@{ $self->{fields} }, $field);
    $self->{fields_by_name}->{ $field->name } = $field;

    return $self;
}

sub make_and_add_field {
    my $self = shift;
    my $name = shift;

    my $field = $self->make_field(name => $name, @_);
    $self->add_field($field);
}

# Rendering

sub html_escape {
    my ($self, $value) = @_;

    return $self->mason->interp->apply_escapes($value, 'h');
}

sub translate {
    my ($self, $message) = @_;

    return $self->mason->scomp('/shared/msg', text => $message);
}

sub classnames {
    my ($self) = @_;

    return join(" ", grep { $_ } (
        "obvius-formengine-form",
        $self->{classname},
        (
            exists $self->{extra_classnames} ?
            @{ $self->{extra_classnames} } :
            ()
        )
    ));
}

sub locate_comp {
    my ($self, $comp) = @_;

    my $render_as = $self->{render_as} || 'div';
    my $ckey = "$render_as:$comp";
    my $comp_path = $self->{comp_path_cache}->{$ckey};

    unless($comp_path) {
        THEME: foreach my $theme (@{ $self->{themes} }) {
            foreach my $type (($render_as, 'shared')) {
                my $path = "/formengine/${theme}/${type}/${comp}";
                if($self->mason->comp_exists($path)) {
                    $comp_path = $path;
                    $self->{comp_path_cache}->{$ckey} = $comp_path;
                    last THEME;
                }
            }
        }
    }

    die "Form component $comp not found" unless($comp_path);

    return $comp_path;
}

sub render_comp {
    my ($self, $comp, %args) = @_;

    my $comp_path = $self->locate_comp($comp);

    return $self->mason->scomp($comp_path, form => $self, %args);
}

sub execute_comp {
    my ($self, $comp, %args) = @_;

    my $comp_path = $self->locate_comp($comp);

    return $self->mason->comp($comp_path, form => $self, %args);
}


sub render {
    my ($self, %args) = @_;

    if(delete $args{as_table}) {
        $args{render_as} = "table";
    }
    if(delete $args{as_div}) {
        $args{render_as} = "div";
    }

    # Override render_as if relevant
    if(my $render_as = delete $args{render_as}) {
        if($render_as ne $self->{render_as}) {
            local $self->{render_as} = $render_as;
            return $self->render_comp('form.mason', render_args => \%args);
        }
    }

    return $self->render_comp('form.mason', render_args => \%args);
}

sub render_fields {
    my $self = shift;
    my $output = "";

    foreach my $field (@{ $self->{fields} }) {
        $output .= $field->render(@_);
    }

    return $output;
}

sub render_hidden_fields {
    my $self = shift;
    my $output = "";

    foreach my $field (@{ $self->{fields} }) {
        $output .= $field->render_as_hidden(@_);
    }

    return $output;
}

sub render_nonhidden_fields {
    my $self = shift;
    my $output = "";

    foreach my $field (@{ $self->{fields} }) {
        $output .= $field->render(@_);
    }

    return $output;
}

sub required_marker_label {
    my $self = shift;

    my $marker = $self->{required_marker_label};
    unless(defined($marker)) {
        $marker = '<span class="required-marker">*</span>' ;
    }
    return $marker;
}

sub required_marker {
    my $self = shift;
    my $required = shift;

    my $m = $self->{required_marker};
    if(defined($m)) {
        if(ref($m) eq 'ARRAY') {
            return ($required ? $m->[0] : $m->[1]) || '';
        } else {
            return $required ? $self->{required_marker} : '';
        }
    } else {
        return undef;
    }
}

sub render_form_errors {
    my ($self, %options) = @_;

    return $self->render_comp('form_errors.mason', %options, form => $self);
}

sub render_pre_javascript { "" }

sub render_post_javascript {
    $_[0]->{backwards_compatibility} ?
    $_[0]->render_comp('backwards_compatibility_javascript.mason') :
    ''
}

# Validation and processing

sub reset {
    my ($self) = @_;

    $self->{errors} = [];
    $self->{warnings} = [];
    delete $self->{is_valid};
}

sub process_request {
    my ($self, $r) = @_;

    $self->reset;

    foreach my $field ($self->field_list) {
        $field->process_request($r);
    }
}

sub add_error {
    my ($self, $field, $message, @args) = @_;

    $message = $self->translate($message);

    push(@{ $self->{errors} }, [sprintf($message, @args), $field]);
}

sub add_warning {
    my ($self, $message, @args) = @_;

    $message = $self->translate($message);

    push(@{ $self->{warnings} }, sprintf($message, @args));
}

sub is_valid {
    my ($self) = @_;

    unless(exists $self->{is_valid}) {
        my $invalid = 0;
    
        foreach my $field ($self->field_list) {
            unless($field->validate(@_)) {
                $invalid++;
                # TODO: add generic message if we didn't get any
                # specific errors?
            }
        }

        $self->{is_valid} = ($invalid == 0)
    }

    return $self->{is_valid};
}

sub cleaned_values {
    my ($self) = @_;

    my %v;
    foreach my $field ($self->field_list) {
        $v{ $field->name } = $field->cleaned_value;
    }

    return \%v;
}

sub cleaned_values_hash { %{ $_[0]->cleaned_values } }

1;