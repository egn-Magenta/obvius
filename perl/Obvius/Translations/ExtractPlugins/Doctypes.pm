package Obvius::Translations::ExtractPlugins::Doctypes;

use strict;
use warnings;
use utf8;

use base qw(Locale::Maketext::Extract::Plugin::Base);
use HTML::Mason::Compiler::ToObject;
use Obvius::CharsetTools;

sub known_file_type {
    my $self = shift;

    my $result = $self->SUPER::known_file_type(@_);
    $self->{_current_file} = $_[0] if($result);
    return $result;
}

sub extract {
    my $self = shift;
    my $input = shift;
    $input = Obvius::CharsetTools::mixed2utf8($input);

    if($self->{_current_file} =~ m{editpages\.txt$}) {
        my (%editpage, $doctypename);

        my $line = 0;
        foreach (split(/\n/, $input)) {
            $line++;

            next if /^\#/;
            next if /^\s*$/;
            s/^\s*//;

            if( /^DocType: (\w+)/ ) {
                $self->add_entry('doctypename:' . $1, $line);
            }
            elsif( /^(\w+): (.*)/ ) {
                my($key, $value)=(lc($1), $2);

                $value =~ s/(^\s+|\s+$)//g;

                if($key eq 'title') {
                    $self->add_entry('editpagetitle:' . $value, $line);
                } elsif($key eq 'fields') {
                    my ($field, $label) = (
                        $value =~ m{^(\S+)(?:\s+([^;]+))?}
                    );
                    $label ||= $field;
                    $self->add_entry('editpagelabel:' . $label, $line);
                }
            }
        }
    } else {
        die "Don't know how to process " . $self->{_current_file};
    }
}

1;