package Obvius::Translations::ExtractPlugins::Doctypes;

use strict;
use warnings;
use utf8;

use base qw(Locale::Maketext::Extract::Plugin::Base);
use HTML::Mason::Compiler::ToObject;
use Obvius::CharsetTools;

sub file_types { qr{.+\.txt} }

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

        my $linenr = 0;
        foreach my $line (split(/\n/, $input)) {
            $linenr++;

            if($line =~ /^\#/ || $line =~ /^\s*$/) {
                next;
            }
            $line =~ s/^\s*//;

            if($line =~ /^\s*DocType: (\w+)/ ) {
                $self->add_entry('doctypename:' . $1, $linenr);
            }
            elsif($line =~ /^\s*(\w+):\s*(.*)/ ) {
                my($key, $value)=(lc($1), $2);

                $value =~ s/(^\s+|\s+$)//g;

                if($key eq 'title') {
                    $self->add_entry('editpagetitle:' . $value, $linenr);
                } elsif($key eq 'fields') {
                    my ($field, $label) = (
                        $value =~ m{^(\S+)(?:\s+([^;]+))?}
                    );
                    $label ||= $field;
                    $self->add_entry('editpagelabel:' . $label, $linenr);
                    # Find any labels in the options
                    if($value =~ s{^[^;]+;\s*}{}) {
                        foreach my $kv_pair (split(/\s*(?!\\),\s*/, $value)) {
                            my ($k, $v) = (
                                $kv_pair =~ m{((?:\\=|[^=])+)=\s*(.*)}
                            );
                            if($k =~ m{^label_} and $v) {
                                $self->add_entry(
                                    'editpagelabel:' . $v, $linenr
                                );
                            } elsif($k =~ m{^subtitle} and $v) {
                                $self->add_entry(
                                    'editpagesubtitle:' . $v, $linenr
                                );
                            }
                        }
                    }
                }
            }
        }
    } else {
        die "Don't know how to process " . $self->{_current_file};
    }
}

1;