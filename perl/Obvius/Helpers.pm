package Obvius::Helpers;

use Obvius;

use locale;

require Exporter;
our @ISA = ("Exporter");

our @EXPORT_OK = qw (escape_uri_argument 
                     unescape_uri_argument 
                     sort_alphabetically);

#\ is used here because % apparently gets mangled...
sub escape_uri_argument {
    my $url = shift;
    $url =~ s|([?&:/=])|sprintf("\\%02d", ord($1))|ge;
    return $url;
}

sub unescape_uri_argument {
    my $url = shift;
    $url =~ s/\\(\d{2})/chr($1)/ge;
    return $url;
}

sub sort_alphabetically {
    my $list = shift;
    @$list = sort {lc($a->{name}->{value}) cmp lc($b->{name}->{value})} @$list;
    return $list;
}

1;
