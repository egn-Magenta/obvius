package WebObvius::FormEngine::Fields;

use strict;
use warnings;
use utf8;

=head1 NAME

  WebObvius::FormEngine::Fields

=cut

=head1 SYNOPSIS

  use WebObvius::FormEngine::Fields;



=cut

my %typemap;

=head1 CLASS METHODS

=head2 get_types

  WebObvius::FormEngine::Fields->get_types();

=cut

sub get_types { return keys %typemap }


=head2 register_field_type

  WebObvius::FormEngine::Fields->register_field_type($classOrPackage);

=cut

sub register_field_type {
    shift if((ref($_[0]) || $_[0]) eq __PACKAGE__);

    my $class = ref($_[0]) || $_[0];
    my $type = $class->type;

    $typemap{$type} = $class;
    
    no strict 'refs';
    my $create_method = __PACKAGE__ . '::' . $type . '_field';
    *{$create_method} = sub {
        shift if((ref($_[0]) || $_[0]) eq __PACKAGE__);
        return $class->new(@_);
    }
}


=head2 make_field

  my $field = $fieldsBase->make_field($classOrPackage);

=cut

sub make_field {
    # Throw away package argument if it's the package name or a blessed object
    shift if((ref($_[0]) || $_[0]) eq __PACKAGE__);

    my $form = shift;
    
    my $hashref = ref($_[0]) eq 'HASH' ? $_[0] : { @_ };
    
    my $name = delete $hashref->{name};
    my $type = delete $hashref->{type} || 'text';
    if ($type =~ m{::}) {
        return $type->new($form, $name, %$hashref);
    } elsif(my $pkg = $typemap{$type}) {
        return $pkg->new($form, $name, %$hashref);
    } else {
        die "Unknown field type '$type'";
    }
}

1;

package WebObvius::FormEngine::Fields::Base;

use strict;
use warnings;
use utf8;

=head1 OBJECT-ORIENTED METHODS

=head2 new

  my $fieldsBase = WebObvius::FormEngine::Fields::Base->new(
    $form, $name, %data
  );

=cut

sub new {
    my ($package, $form, $name, %data) = @_;

    $data{name} = $name;
    $data{form} = $form;
    $data{name} ||= $form->make_anonymous_fieldname;
    $data{errors} ||= [];
    $data{value} = $data{default};

    return bless(\%data, $package);
}

sub form { $_[0]->{form} }
sub mason { $_[0]->{form}->mason }

sub id { $_[0]->{id} || $_[0]->{name} }
sub name { $_[0]->{name} }
sub submit_name {
    join("-", grep { $_ } ($_[0]->{name_prefix}, $_[0]->name))
}
sub type { die "Field must have its own own type" }
sub input_type { $_[0]->type }

sub value { $_[0]->{value} }
sub cleaned_value { $_[0]->value }
sub selected_values { return ($_[0]->value => 1) }


=head2 label

  my $label = $fieldsBase->label();

=cut

sub label {
    my $self = shift;
    my $label = $self->{label} || $self->{name};

    if ($self->translate_labels) {
        return $self->form->mason->scomp(
            '/shared/msg', text=>$label
        );
    } else {
        return $label;
    }
}

sub required { $_[0]->{required} }

sub errors { $_[0]->{errors} }
sub error_list { @{ $_[0]->errors } }

# Configuration methods
sub is_multivalue { 0 }
sub edit_component { "input.mason" }
sub label_component { "label.mason" }
sub field_component { "field.mason" }

sub extra_attributes { (); }

sub translate_labels {
    exists $_[0]->{translate_labels} ?
        $_[0]->{translate_labels} :
        $_[0]->form->translate_labels
}

# Rendering


=head2 html_escape

  $fieldsBase->html_escape($text);

=cut

sub html_escape { $_[0]->form->html_escape($_[1]) }


=head2 render_label

  my $html = $fieldsBase->render_label();

=cut

sub render_label {
    my ($self, %options) = @_;

    my $comp = $self->label_component(%options);
    return $self->form->render_comp($comp, %options, field => $self);
}


=head2 render_control

  my $html = $fieldsBase->render_control(%options);

=cut

sub render_control {
    my ($self, %options) = @_;

    my $comp = $self->edit_component(%options);
    return $self->form->render_comp($comp, %options, field => $self);
}


=head2 render

  my $html = $fieldsBase->render(%options);

=cut

sub render {
    my ($self, %options) = @_;

    my $comp = $self->field_component(%options);
    return $self->form->render_comp($comp, %options, field => $self);
}


=head2 render_as_hidden

  my $html = $fieldsBase->render_as_hidden();

=cut

sub render_as_hidden { '' }


=head2 render_extra_attributes

  my $attrString = $fieldsBase->render_extra_attributes();

=cut

sub render_extra_attributes {
    my ($self) = @_;
    
    my %attrs = $self->extra_attributes;

    my @classes;

    # Get single class if specified
    if(my $class = $self->{class}) {
        push(@classes, $class);
    }
    # Get multiple classes if specified
    if (my $classes = $self->{classes}) {
        push(@classes, @$classes);
    }
    # Get classes specified as extra attributes
    if (my $class = delete $attrs{class}) {
        push(@classes, $class);
    }
    if (@classes) {
        $attrs{class} = join(" ", @classes);
    }

    return join(" ", map {
        my $k = $_;
        my $v = $attrs{$k};
        qq|$k="$v"|
    } sort keys %attrs);
}

=head2 render_container_classes

  my $classesString = $fieldsBase->render_container_classes();
  my $classesString = $fieldsBase->render_container_classes(
    "myClass1", "otherClass", ...
  );

=cut

sub render_container_classes {
    my ($self) = shift;
    
    my @classes = @_;

    # Get single class if specified
    if(my $class = $self->{container_class}) {
        push(@classes, $class);
    }
    # Get multiple classes if specified
    if (my $classes = $self->{container_classes}) {
        push(@classes, @$classes);
    }
    if (@classes) {
        return 'class="' . join(" ", @classes) . '"';
    }
    return "";
}


=head2 required_marker_label

  my $label = $fieldsBase->required_marker_label();

=cut

sub required_marker_label {
    my ($self) = @_;

    return $self->required ? $self->form->required_marker_label : '';
}


=head2 required_marker

  my $marker = $fieldsBase->required_marker();

=cut

sub required_marker {
    my ($self) = @_;

    return $self->form->required_marker($self->required);
}


=head2 required_message

  my $message = $fieldsBase->required_message();

=cut

sub required_message { $_[0]->form->translate("This field is required") }


=head2 render_errors

  my $html = $fieldsBase->render_errors(%options);

=cut

sub render_errors {
    my ($self, %options) = @_;

    return $self->form->render_comp(
        'field_errors.mason',
        %options,
        field => $self
    );
}


# Validation and processing

=head2 process_request

  $fieldsBase->process_request($request);

=cut

sub process_request {
    my ($self, $r) = @_;

    my @values = $r->param($self->name);

    if (@values > 1) {
        warn (sprintf(
            "Multiple values submitted for single-value field " .
            "'%s' in the form '%s'",
            $self->name,
            $self->form->name
        ));
    }
    
    $self->{value} = $values[0];
}


=head2 get_clean_value

  my $cleanvalue = $fieldsBase->get_clean_value();

=cut

sub get_clean_value {
    my ($self) = @_;

    unless(exists $self->{cleaned_value}) {
        $self->{cleaned_value} = $self->value;
    }

    return $self->{cleaned_value};
}


=head2 is_empty

  my $empty = $fieldsBase->is_empty();

=cut

sub is_empty {
    my ($self) = @_;

    return !$self->get_clean_value();
}


=head2 add_error

  $fieldsBase->add_error($message[, $param1[, $param2 ... ]]);

=cut

sub add_error {
    my ($self, $message, @args) = @_;

    $message = $self->form->translate($message);

    push(@{ $self->{errors} }, sprintf($message, @args));
}


=head2 validate

  my $valid = $fieldsBase->validate();

=cut

sub validate {
    my ($self) = @_;

    my $res = $self->validate_by_required();
    return $res if(defined($res) and not $res);

    $res = $self->validate_by_regex();
    return $res if(defined($res) and not $res);

    $res = $self->validate_by_hook();
    return $res if(defined($res) and not $res);

    return 1;
}


=head2 validate_by_required

  my $valid = $fieldsBase->validate_by_required();

=cut

sub validate_by_required {
    my ($self) = @_;

    if($self->required && $self->is_empty) {
        $self->add_error($self->required_message);
        $self->form->add_error(
            $self, "The field '%s' must be specified", $self->label
        );
        return 0;
    } else {
        return 1;
    }
}


=head2 label

  my $valid = $fieldsBase->validate_by_regex();

=cut

sub validate_by_regex {
    my ($self) = @_;
    
    if (my $regex = $self->{validate_regex}) {
        unless($self->value =~ m{$regex}) {
            $self->add_error(
                $self->{validate_regex_message} ||
                'The specified value is not formatted correctly'
            );
            $self->form->add_error(
                $self,
                (
                    $self->{validate_regex_form_message} ||
                    ("The value of the field '%s' has not been filled " .
                     "out correctly")
                ),
                $self->label
            );

            return 0;
        }
    }

    return 1;
}


=head2 validate_by_hook

  my $valid = $fieldsBase->validate_by_hook();

=cut

sub validate_by_hook {
    my ($self) = @_;    

    if (my $hook = $self->{validate_hook}) {
        return $hook->($self);
    }

    return 1;
}

1;





=head1 NAME

  WebObvius::FormEngine::Fields::MultipleBase

=cut

=head1 SYNOPSIS

  use WebObvius::FormEngine::Fields::MultipleBase;

=cut

package WebObvius::FormEngine::Fields::MultipleBase;

use strict;
use warnings;
use utf8;

use WebObvius::FormEngine::Option;

our @ISA = qw(WebObvius::FormEngine::Fields::Base);

=head2 new

  my $multipleBase = WebObvius::FormEngine::Fields::MultipleBase->new($form, $name, %data);

=cut

sub new {
    my ($package, $form, $name, %data) = @_;
    
    my $default = delete $data{default};

    my $options = delete $data{options};

    my $obj = $package->SUPER::new($form, $name, %data);
    bless($obj, $package);
    
    $obj->{option_count} = 0;
    
    $obj->setup_options($options);
    $obj->setup_default($default);
    $obj->update_selected;

    return $obj;
}

sub options { shift->{options} }
sub options_list { @{ shift->options } }

sub cleaned_value {
    my $self = shift;
    my $v = $self->value;
    return $self->is_multivalue ? $v : $v->[0]
}
sub value_list { @{ shift->value } }
sub selected_map { return map { $_ => 1 } shift->value_list }

sub is_empty { (shift->value_list) == 0 }

sub default { shift->{default} }
sub default_list { @{ shift->default }}

sub option_separator { "\n" }

sub required_message {
    my $self = shift;

    if ($self->is_multivalue) {
        return $self->form->translate(
            "You must choose at least one value for this field"
        )
    } else {
        return $self->form->translate(
            "You must choose a value for this field"
        )
    }
}

sub next_id {
    my ($self) = @_;

    return $self->id . '-' . $self->{option_count}++;
}

sub process_request {
    my ($self, $r) = @_;

    my @values = $r->param($self->name);

    $self->{value} = \@values;
    $self->update_selected;
}

sub setup_options {
    my ($self, $options) = @_;

    my @options;
    
    unless($options) {
        die "You must specify options for multivalue field " .
            sprintf("'%s'", $self->label);
    }

    if (ref($options) eq 'HASH') {
        while (my ($v, $l) = each(%$options)) {
            push(@options, WebObvius::FormEngine::Option->new(
                $self,
                text => $l, value => $v
            ));
        }
    } elsif(ref($options) eq 'ARRAY') {
        foreach my $o (@$options) {
            push(@options, WebObvius::FormEngine::Option->new(
                $self,
                $o
            ));
        }
    } else {
        die "Options must be specified as either a hashref or an " .
            "arrayref";
    }

    unless(@options) {
        die "You must specify at least one option for multivalue " .
            "fields";
    }
    
    $self->{options} = \@options;
}

sub setup_default {
    my ($self, $defaults) = @_;
    
    my %uniq;
    
    $defaults = [] unless(defined($defaults));

    if ($self->is_multivalue) {
        unless(ref($defaults) eq 'ARRAY') {
            die "Default value for multivalue fields must be a list"
        }
    } else {
        $defaults = [ $defaults ] unless(ref($defaults) eq 'ARRAY');
    }

    foreach my $o ($self->options_list) {
        $uniq{$o->value}++ if($o->default)
    }

    foreach my $k (@$defaults) {
        $uniq{$k}++;
    }

    my @default = sort keys %uniq;
    
    if (!$self->is_multivalue and @default > 1) {
        warn(sprintf(
            "Multiple default values for single-value field '%s'",
            $self->label
        ));
    }

    $self->{default} = \@default;

    # Copy to value, so they will be selected by default
    $self->{value} = [@default];
    $self->update_selected;
}

sub update_selected {
    my ($self) = @_;
    my %selected = $self->selected_map;
    foreach my $o ($self->options_list) {
        $o->selected($selected{$o->value} ? 1 : 0);
    }
}

sub validate_by_regex {
    my ($self) = @_;

    my $regex = $self->{validate_regex};
    return 1 unless($regex);

    my $failed = 0;
    foreach my $v ($self->value_list) {
        unless($v =~ $regex) {
            $self->add_error(
                (
                    $self->{validate_regex_message} ||
                    $self->form->translate(
                        "The value '%s' for the field '%s' is not formatted " .
                        "correctly."
                    )
                ),
                $v,
                $self->label
            );
            $self->form->add_error(
                $self,
                (
                    $self->{validate_regex_form_message} ||
                    $self->form->translate(
                        "The value '%s' for the field '%s' is not formatted " .
                        "correctly."
                    )
                ),
                $v,
                $self->label
            );
            $failed++;
        }
    }
    
    return 0 == $failed;
}

1;



=head1 NAME

  WebObvius::FormEngine::Fields::MultipleBase

=cut

=head1 SYNOPSIS

  use WebObvius::FormEngine::Fields::MultipleBase;

=cut

package WebObvius::FormEngine::Fields::Hidden;

use strict;
use warnings;
use utf8;

our @ISA = qw(WebObvius::FormEngine::Fields::Base);

sub type { "hidden" }
sub edit_component { "input.mason" }

sub render { '' }
sub render_as_hidden { shift->SUPER::render_control(@_) . "\n" }

WebObvius::FormEngine::Fields->register_field_type(__PACKAGE__);

1;

package WebObvius::FormEngine::Fields::Text;

use strict;
use warnings;
use utf8;

our @ISA = qw(WebObvius::FormEngine::Fields::Base);

sub type { "text" }
sub edit_component { "input.mason" }

sub extra_attributes {
    ( size => ($_[0]->{size} || 72) )
}

WebObvius::FormEngine::Fields->register_field_type(__PACKAGE__);

1;

package WebObvius::FormEngine::Fields::Email;

use strict;
use warnings;
use utf8;

use Email::Valid;

our @ISA = qw(WebObvius::FormEngine::Fields::Text);

sub type { "email" }
sub input_type { $_[0]->form->html5 ? "email" : "text" }

sub validate {
    my $self = shift;
    
    $self->SUPER::validate(@_);

    unless($self->error_list) {
        my $val = $self->value;
        return if(!$self->required and !$val);
        
        unless(Email::Valid->address($val)) {
            $self->add_error(
                "'%s' is not a valid email address", $val
            );
            $self->form->add_error(
                $self,
                "'%s' is not a valid email address", $val
            );
        }
    }
}

WebObvius::FormEngine::Fields->register_field_type(__PACKAGE__);

1;


=head1 NAME

  WebObvius::FormEngine::Fields::MultipleBase

=cut

package WebObvius::FormEngine::Fields::Password;

use strict;
use warnings;
use utf8;

our @ISA = qw(WebObvius::FormEngine::Fields::Text);

sub type { "password" }
sub edit_component { "input.mason" }

sub render {
    my ($self, %options) = @_;
    local $self->{value} = "";
    return $self->SUPER::render(%options);
}

WebObvius::FormEngine::Fields->register_field_type(__PACKAGE__);

1;


=head1 NAME

  WebObvius::FormEngine::Fields::FileInput

=cut

package WebObvius::FormEngine::Fields::FileInput;

use strict;
use warnings;
use utf8;

our @ISA = qw(WebObvius::FormEngine::Fields::Base);

sub type { "file" }
sub edit_component { "input.mason" }

WebObvius::FormEngine::Fields->register_field_type(__PACKAGE__);

1;


=head1 NAME

  WebObvius::FormEngine::Fields::TextArea

=cut

package WebObvius::FormEngine::Fields::TextArea;

use strict;
use warnings;
use utf8;

our @ISA = qw(WebObvius::FormEngine::Fields::Base);

sub type { "textarea" }
sub edit_component { "textarea.mason" }

WebObvius::FormEngine::Fields->register_field_type(__PACKAGE__);

1;


=head1 NAME

  WebObvius::FormEngine::Fields::Radio

=cut

package WebObvius::FormEngine::Fields::Radio;

use strict;
use warnings;
use utf8;

our @ISA = qw(WebObvius::FormEngine::Fields::MultipleBase);

sub type { "radio" }
sub label_component { "pseudo_label.mason" }
sub edit_component { "radio.mason" }

WebObvius::FormEngine::Fields->register_field_type(__PACKAGE__);

1;


=head1 NAME

  WebObvius::FormEngine::Fields::YesNo

=cut

package WebObvius::FormEngine::Fields::YesNo;

use strict;
use warnings;
use utf8;

our @ISA = qw(WebObvius::FormEngine::Fields::Radio);

sub type { "yesno" }
sub input_type { "radio" }

sub new {
    my ($package, $form, $name, %data) = @_;
    
    my $obj = $package->SUPER::new(
        $form, $name,
        options => [
            [ $form->translate("Yes") => 1 ],
            [ $form->translate("No") => 0 ]
        ],
        %data
    );

    return bless($obj, $package);
}

WebObvius::FormEngine::Fields->register_field_type(__PACKAGE__);

1;


=head1 NAME

  WebObvius::FormEngine::Fields::CheckBox

=cut

package WebObvius::FormEngine::Fields::CheckBox;

use strict;
use warnings;
use utf8;

our @ISA = qw(WebObvius::FormEngine::Fields::Radio);

sub is_multivalue { 1 }
sub type { "checkbox" }

WebObvius::FormEngine::Fields->register_field_type(__PACKAGE__);

1;


=head1 NAME

  WebObvius::FormEngine::Fields::Select

=cut

package WebObvius::FormEngine::Fields::Select;

use strict;
use warnings;
use utf8;

our @ISA = qw(WebObvius::FormEngine::Fields::MultipleBase);

sub type { "select" }
sub edit_component { "select.mason" }
sub is_empty { shift->value->[0] eq "" }

WebObvius::FormEngine::Fields->register_field_type(__PACKAGE__);

1;


=head1 NAME

  WebObvius::FormEngine::Fields::SelectMultiple

=cut

package WebObvius::FormEngine::Fields::SelectMultiple;

use strict;
use warnings;
use utf8;

our @ISA = qw(WebObvius::FormEngine::Fields::Select);

sub is_multivalue { 1 }
sub type { "select_multiple" }

WebObvius::FormEngine::Fields->register_field_type(__PACKAGE__);

1;


=head1 NAME

  WebObvius::FormEngine::Fields::Submit

=cut

package WebObvius::FormEngine::Fields::Submit;

use strict;
use warnings;
use utf8;

our @ISA = qw(WebObvius::FormEngine::Fields::Base);

sub type { "submit" }
sub field_component { "full_width_field.mason" }
sub edit_component { "input.mason" }

sub render_label {
    my $self = shift;

    if ($self->{show_label}) {
        return $self->SUPER::render_label(@_);
    } else {
        return '';
    }
}

package WebObvius::FormEngine::Fields::SubmitButtons;

use strict;
use warnings;
use utf8;

our @ISA = qw(WebObvius::FormEngine::Fields::MultipleBase);

sub type { "submitbuttons" }
sub input_type { "submit" }
sub field_component { "full_width_field.mason" }
sub edit_component { "input.mason" }

sub render_label {
    my $self = shift;

    if ($self->{show_label}) {
        return $self->SUPER::render_label(@_);
    } else {
        return '';
    }
}

sub render_control {
    my ($self, %options) = @_;

    my $output = "";
    foreach my $opt ($self->options_list) {
        local $self->{class} = $opt->{class};
        $output .= $self->SUPER::render_control(
            value => $opt->text, # Text on button
            name => $opt->value, # Name used when submitting
            field_id => $self->id . '-' . $opt->value
        ) . "\n";
    }
    return $output;
}


WebObvius::FormEngine::Fields->register_field_type(__PACKAGE__);

1;


=head1 NAME

  WebObvius::FormEngine::Fields::EditEngine2

=cut

package WebObvius::FormEngine::Fields::EditEngine2;

use strict;
use warnings;
use utf8;

our @ISA = qw(WebObvius::FormEngine::Fields::Base);

sub new {
    my $package = shift;
    
    my $obj = $package->SUPER::new(@_);

    unless($obj->{editengine2_comp}) {
        die "You must specify an editengine2 component for " .
            "editengine2 fields";
    }

    return bless($obj, $package);
}

sub type { "editengine2" }

sub render_control {
    my ($self, %options) = @_;

    my $comp = $self->{editengine2_comp};
    my $val = $self->value;
    return $self->form->mason->scomp(
        '/shared/editengine2/type/' . $comp . ":block",
        prefix => "",
        field => {
            name => $self->name,
            label => $self->label
        },
        value => { value => $val },
        style => {}
    );
}

sub process_request {
    my ($self, $r) = @_;
    
    $self->SUPER::process_request($r);

    my $id = $self->name;
    my $data = {
        $id => $self->value
    };

    # Copy in values from previous fields
    foreach my $field ($self->form->field_list) {
        my $name = $field->name;
        last if($name eq $id);
        $data->{$name} = $field->cleaned_value;
    }

    foreach my $df (@{$self->{depends_on_fields} || []}) {
        my $field = $self->form->field($df);
        next unless($field);
        $data->{$field->name} = $field->value;
    }
    
    my $comp = $self->{editengine2_comp};
    $self->mason->comp(
        '/shared/editengine2/type/' . $comp,
        data => $data,
        id => $id,
        validation => {}
    );
    
    $self->{value} = $data->{$id};
}

WebObvius::FormEngine::Fields->register_field_type(__PACKAGE__);

1;




=head1 NAME

  WebObvius::FormEngine::Fields::Custom

=cut

package WebObvius::FormEngine::Fields::Custom;

use strict;
use warnings;
use utf8;

our @ISA = qw(WebObvius::FormEngine::Fields::Base);

sub type { "custom" }
sub edit_component { $_[0]->{edit_component} }

sub new {
    my $package = shift;
    
    my $obj = $package->SUPER::new(@_);

    unless($obj->{edit_component}) {
        die "You must specify an edit component for " .
            "custom fields";
    }

    return bless($obj, $package);
}

WebObvius::FormEngine::Fields->register_field_type(__PACKAGE__);

1;



=head1 NAME

  WebObvius::FormEngine::Fields::CustomMultiple

=cut

package WebObvius::FormEngine::Fields::CustomMultiple;

use strict;
use warnings;
use utf8;

our @ISA = qw(WebObvius::FormEngine::Fields::MultipleBase);

sub type { "custommultiple" }
sub edit_component { $_[0]->{edit_component} }
sub is_multivalue { $_[0]->{is_multivalue} }

sub new {
    my $package = shift;
    
    my $obj = $package->SUPER::new(@_);

    unless($obj->{edit_component}) {
        die "You must specify an edit component for " .
            "custom fields";
    }

    unless($obj->{is_multivalue}) {
        die "You must specify 'is_multivalue' for CustomMultiple fields ";
    }
    
    return bless($obj, $package);
}

WebObvius::FormEngine::Fields->register_field_type(__PACKAGE__);

1;


=head1 NAME

  WebObvius::FormEngine::Fields::SubHeading

=cut

package WebObvius::FormEngine::Fields::SubHeading;

our @ISA = qw(WebObvius::FormEngine::Fields::Base);

sub type { "subheading" }
sub field_component { "subheading.mason" }
sub validate { 1 }
sub value { $_[0]->label }

sub description { $_[0]->{description} || '' }

WebObvius::FormEngine::Fields->register_field_type(__PACKAGE__);

1;