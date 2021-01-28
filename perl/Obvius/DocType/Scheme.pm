package Obvius::DocType::Scheme;

########################################################################
#
# Scheme.pm - Scheme Document Type
#
# Copyright (C) 2001 Magenta Aps, Denmark (http://www.magenta-aps.dk/)
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

our @ISA = qw( Obvius::DocType );
our $VERSION="1.0";

sub action {
    my ($this, $input, $output, $doc, $vdoc, $obvius) = @_;

    my @row_types = map {$_->Id } grep { $_ and $_->Name =~ /^SchemeRow/ } @{$obvius->{DOCTYPES}};

    my $doctypematch = "('" . join("','", @row_types) . "')";

    my $is_admin = $input->param('IS_ADMIN');

    my %search_options=(
                    needs_document_fields => [ 'parent' ],
                    sortvdoc => $vdoc,
                    notexpired=>!$is_admin,
                    public=>!$is_admin,
                );

    my $subdocs = $obvius->search([], "parent = " . $doc->Id . " AND type IN " . $doctypematch , %search_options);
    $subdocs = [] unless($subdocs);


    # Get data from the subdocs
    my $max_num_fields = 0;
    my @scheme_data;
    my $counter = 0;
    for(@$subdocs) {
        my $data;
        $data->{type} = $obvius->get_version_field($_, 'schemerowtype');
        next unless($data->{type});

        $data->{id} = $_->DocId;

        my $doctype = $obvius->get_doctype_by_id($_->Type);
        my @fields = sort map {lc($_)} grep { $_ =~ /^FIELD/i } keys %{$doctype->{FIELDS}};
        $max_num_fields = scalar(@fields) if(scalar(@fields) > $max_num_fields);

        if($data->{type} eq 'schemeheading') {
            $data->{start_table} = 1;
            $data->{end_table} = 1 unless($counter == 0);
            $data->{title} = $obvius->get_version_field($_, 'title');
        } elsif($data->{type} eq 'subheading') {
            $data->{title} = $obvius->get_version_field($_, 'title');
        } elsif($data->{type} eq 'columnheadings' or $data->{type} eq 'fields') {
            $obvius->get_version_fields($_, \@fields);
            for my $f (@fields) {
                my $fieldname = $f;
                $f = { text => $_->field($fieldname) || '' };
            }
            $data->{fields} = \@fields;
        } else {
            print STDERR "Warning: Unknown scemerowtype '" . $data->{type} . "' in Obvius::DocType::Scheme\n";
            next;
        }
        push(@scheme_data, $data);
        $counter++;
    }


    #Process data for the template system
    for(@scheme_data) {
        $_->{max_num_fields} = $max_num_fields;

        # Make sure we always have max_num_fields fields
        my $fields = $_->{fields};
        if($fields) {
            for(0..($max_num_fields - 1)) {
                $fields->[$_] = { text => '' } unless $fields->[$_];
            }
        }
    }
    $scheme_data[0]->{start_table} = 1;

    $output->param(scheme_data => \@scheme_data);

    my $print = $input->param('print');
    $output->param(print => 1) if($print);

    $output->param(is_admin => 1) if($is_admin);

    return OBVIUS_OK;
}

1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Obvius::DocType::Scheme - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Obvius::DocType::Scheme;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Obvius::DocType::Scheme, created by h2xs. It looks like the
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
