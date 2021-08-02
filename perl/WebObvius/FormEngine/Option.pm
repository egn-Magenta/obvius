package WebObvius::FormEngine::Option;

use strict;
use warnings;
use utf8;

sub new {
    my $package = shift;
    my $field = shift;
    
    my %obj;
    my $ref = ref($_[0]);
    if ($ref eq 'HASH') {
        my $h = shift;
        
        unless(exists $h->{text} and exists $h->{value}) {
            die "Options specified as hashrefs must have both text " .
                "and value keys specified";
        }

        %obj = (%$h, @_)
    } elsif ($ref eq 'ARRAY') {
        my $a = shift;
        unless(@$a == 2 or @$a == 3) {
            die "Options specified as arrayrefs must have two or " .
            "three values";
        }
        %obj = (
            text => $a->[0],
            value => $a->[1],
            default => $a->[2], @_
        );
    } elsif(@_ == 1) {
        %obj = (text => $_[0], value => $_[0]);
    } else {
        %obj = @_;
        unless(exists $obj{text} and exists $obj{value}) {
            die "Options must have both text and value";
        }
    }

    $obj{id} ||= $field->next_id;
    $obj{selected} = $obj{default} unless(defined($obj{selected}));
    
    return bless(\%obj, $package);
}

sub id { $_[0]->{id} }
sub text { $_[0]->{text} }
sub name { $_[0]->{text} }
sub label { $_[0]->{text} }
sub value { $_[0]->{value} }

sub default { $_[0]->{default} }
sub selected {
    my $v = $_[0]->{selected};
    $_[0]->{selected} = $_[1] if (@_ > 1);
    return $v;
}

1;
