package Obvius::DocType::DocparamMatrix;

########################################################################
#
# DocparamMatrix - Doctype for editing first-level docparams in Obvius.
#
# Copyright (C) 2001 Magenta Aps, Denmark (http://www.magenta-aps.dk/)
#
# Author: Adam Sjøgren (asjo@magenta-aps.dk)
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

our @ISA = qw( Obvius::DocType );
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;




sub action {
    my ($this, $input, $output, $doc, $vdoc, $obvius) = @_;

    $obvius->get_version_fields($vdoc, 255);

    my $docparam_name = $vdoc->field('dp_name');

    unless($docparam_name) {
        $output->param('error' => "No docparam name specified");
        return OBVIUS_OK;
    }

    # We always need the list of first level docs, so look it up here:

    my $first_level_docs;

    my @first_level_docs;

    my $basedoc = $obvius->lookup_document('/');

    $first_level_docs = $obvius->get_docs_by(parent => $basedoc->Id);

    for (@$first_level_docs) {
        my $dp_value = $obvius->get_docparam_value($_, $docparam_name) || '';
        my %values = map { $_ => 1 } split(/\s*,\s*/, $dp_value);

        push(@first_level_docs, {
                                    name => $_->param('name'),
                                    'values' => \%values,
                                    docid => $_->param('id'),
                                    no_docparam_value => (! $dp_value)
                            });
    }

    @first_level_docs = sort { lc($a->{name}) cmp lc($b->{name}) } @first_level_docs;

    $output->param('first_level_docs' => \@first_level_docs);

    my $mode = $input->param('mode') || '';

    if($mode eq 'save') {

        $output->param('mode' => 'save');

        # Check whether the user have the admin capability:

        unless($obvius->user_has_capabilities($doc, qw(admin))) {
            $output->param('error' => 'You are not allowed change the docparams specified in this document');
            return OBVIUS_OK;
        }


        # Loop over the level-1 docs and update each of them with the newly chosen values.

        for(@first_level_docs) {
            # Skip docids that was not submitted. This is to avoid clearing out all the
            # docparams if someone writes ?mode=save on the URL and nothing else

            next unless($input->param($_->{docid} . "_submitted"));

            my $values = $input->param('selection_' . $_->{docid}) || [];
            $values = [ $values ] unless(ref($values));

            my $dp_string = join(", ", sort @$values);

            my $d = $obvius->get_doc_by_id($_->{docid});

            my $new_docparams = new Obvius::Data;

            # Get old docparams:
            my $docparams = $obvius->get_docparams($d);

            for($docparams->param) {
                $new_docparams->param($_ => $docparams->param($_)->param('value'));
            }

            # Set the new value
            $new_docparams->param($docparam_name => $dp_string);

            # Store it:
            $obvius->set_docparams($d, $new_docparams);
        }
    } else {

        $output->param('mode' => 'list');

        # We need to know which options to choose from, so look them up and put them on $output

        # Options can be defined in two ways. Either as "function:functionname" or as a comma
        # separated list of options. If the "function:functionname" syntax is used the
        # doctype will try and call the functionname function on itself and have it return
        # the list of options to use. If the function doesn't exist or an error occur, this
        # is reported.

        my $docparam_options = $vdoc->field('dp_options') || '';

        my $dp_options;

        if($docparam_options) {
            if($docparam_options =~ s!^function:(.*)!$1!i) {
                eval('$dp_options = $this->' . $1 . '($input, $output, $doc, $vdoc, $obvius);');
                if($@) {
                    $output->param('error' => "Docparam options function failed: $@");
                    return OBVIUS_OK;
                }
            } else {
                my @docparam_options = split(/\s*,\s*/, $docparam_options);
                $dp_options = \@docparam_options;
            }
        } else {
            $output->param('error' => "No docparam options specified");
            return OBVIUS_OK;
        }

        $output->param('docparam_options' => $dp_options);

        # If a default set of options is defined parse it and put it on $output:

        if(my $default_str = $vdoc->field('defaultset')) {
            my %defaults = map {$_ => 1} split(/\s*,\s*/, $default_str);

            $output->param('default_set' => \%defaults);
        }

        # If the user lacks capabilities, we make disable the form buttons
        unless($obvius->user_has_capabilities($doc, qw(admin))) {
            $output->param('disable_form' => 1);
        }

    }


    return OBVIUS_OK;
}

sub get_available_doctypes {
    my ($this, $input, $output, $doc, $vdoc, $obvius) = @_;

    my $doctypes = $obvius->param('doctypes');

    my @doctypes = sort map { $_->param('name') } grep { $_ and $obvius->get_editpages($_) } @$doctypes;

    return \@doctypes;
}

1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Obvius::DocType::DocparamMatrix - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Obvius::DocType::DocparamMatrix;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Obvius::DocType::DocparamMatrix, created by h2xs. It looks like the
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
