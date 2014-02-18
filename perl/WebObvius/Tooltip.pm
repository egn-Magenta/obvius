package WebObvius::Tooltip;

use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(get_tooltip_path);

our $default_path = '/admin/helpers/';

sub fix_slashes {
    my $string = shift;
    $string .= '/';
    $string =~ s|/+|/|g;

    return $string;
}

# Return the path to the tooltips, given doctype and a field
# or just a field (in absence of a doctype).
sub get_tooltip_path {
    my (%args) = @_;
    my ($tooltip_path, $path);

    if (defined $args{tooltip_path}) {
	$tooltip_path = $args{tooltip_path};
    } else {
	$tooltip_path = $default_path;
    }

    # If we have no doctype we don't have a tooltip
    return undef unless(defined ($args{doctype}));

    my $lang = $args{lang} || '';

    my @parts = ( $tooltip_path, $lang, $args{doctype} );

    if(defined($args{field})) {
        push(@parts, $args{field});
    }

    $path = join("/", @parts);
    
    $path .= '/';
    return fix_slashes($path);
}

1;
