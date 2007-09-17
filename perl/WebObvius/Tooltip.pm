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
    
    if (defined ($args{doctype}) && defined ($args{field})) {
	$path = join '/', ($tooltip_path, $args{doctype}, $args{field});
    } elsif (defined ($args{doctype})) {
	$path = join '/', ($tooltip_path, $args{doctype});
    } else {
	return undef;
    }
    
    $path .= '/';
    return fix_slashes($path);
}

1;

