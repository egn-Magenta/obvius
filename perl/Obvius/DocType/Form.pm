package Obvius::DocType::Form;

########################################################################
#
# Form.pm - Form Document Type for Obvius[tm].
#
# Copyright (C) 2005 Magenta Aps, Denmark (http://www.magenta-aps.dk/)
#
# Author: Jørgen Ulrik B. Krag (jubk@magenta-aps.dk)
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2, or (at your option)
# any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software Foundation,
# Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
#
########################################################################

# $Id$

use strict;
use warnings;

use Obvius;
use Obvius::DocType;
use Data::Dumper;
use XML::Simple;

our @ISA = qw( Obvius::DocType );
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub action {
    my ($this, $input, $output, $doc, $vdoc, $obvius) = @_;

    $obvius->get_version_fields($vdoc, ['formdata']);

    $obvius->get_version_fields($vdoc, ['formdata']);

    my $formdata = XMLin(
                            $vdoc->field('formdata'),
                            keyattr=>[],
                            forcearray => [ 'field', 'option', 'validaterule' ],
                            suppressempty => ''
                        );


    unless($input->param('obvius_form_submitted')) {
        # Form not submitted yet, just output the form:
        $output->param('formdata' => $formdata);
        return OBVIUS_OK;
    }


    # Ok assume data submitted, now validate:

    my %fields_by_name;

    for my $field (@{$formdata->{field}}) {
        my $value = $input->param($field->{name}) || '';

        # Make sure we have arrays for "multiple" fieldtypes
        if($field->{type} eq 'checkbox' or $field->{type} eq 'selectmultiple') {
            $value ||= [];
            $value = [ $value ] unless(ref($value));

            $field->{has_value} = scalar(@$value) || undef;
        } else {
            $field->{has_value} = $value
        }

        $field->{_submitted_value} = $value;


        my $valrules = $field->{validaterules};
        if($valrules) {
            $valrules = $valrules->{validaterule} || [];
        } else {
            $valrules = [];
        }

        # Validate with user specified rules:
        for(@$valrules) {
            my $type = $_->{validationtype} || '';
            my $arg = $_->{validationargument};

            if($type eq 'regexp') {
                my $test = eval("'" . $value  . "' =~ /" . $arg . "/;");
                if($@) {
                    print STDERR "Failed to test regexp: $@\n";
                    $field->{invalid} = $_->{errormessage};
                    last;
                } else {
                    unless($test) {
                        $field->{invalid} = $_->{errormessage};
                        last;
                    }
                }
            } elsif($type eq 'min_checked') {
                if(scalar(@$value) < $arg) {
                    $field->{invalid} = $_->{errormessage};
                }
            }
        }

        $fields_by_name{$field->{name}} = $field;
    }

    # Make another run to check mandatory fields
    for my $field (@{$formdata->{field}}) {
        my $mandatory = $field->{mandatory} || 0;

        # Don't check fields that are already invalid.
        next if($field->{invalid});

        if($mandatory) {
            if($mandatory eq '1') {
                unless($field->{has_value}) {
                    $field->{mandatory_failed} = 1;
                }
            } else {
                if($mandatory =~ s/^!//) {
                    my $other_field = $fields_by_name{$mandatory};
                    unless($other_field->{has_value}) {
                        unless($field->{has_value}) {
                            $field->{mandatory_failed} = 1;
                        }
                    }
                } else {
                    my $other_field = $fields_by_name{$mandatory};
                    if($other_field->{has_value} and not $other_field->{invalid}) {
                        unless($field->{has_value}) {
                            $field->{mandatory_failed} = 1;
                        }
                    }
                }
            }
        }
    }

    my @invalid = map {$_->{name}} grep { $_->{invalid} or $_->{mandatory_failed} } @{$formdata->{field}};

    $output->param('formdata' => $formdata);
    $output->param('invalid' => \@invalid);

    return OBVIUS_OK;
}

1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Obvius::DocType::Form - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Obvius::DocType::Form;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Obvius::DocType::Form, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head2 EXPORT

None by default.


=head1 AUTHOR

A. U. Thor, E<lt>a.u.thor@a.galaxy.far.far.awayE<gt>

=head1 SEE ALSO

L<perl>.

=cut
