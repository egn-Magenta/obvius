package Obvius::DocType::DocTypeSearch;

########################################################################
#
# DocTypeSearch.pm - DocTypeSearch Document Type
#
# Copyright (C) 2001 aparte, Denmark (http://www.aparte.dk/)
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

our @ISA = qw( Obvius::DocType );
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

# action - given the usual band of objects, either presents a
#          search-form by consulting the editpage and the field
#          "exclude_fields" OR performs a search with the values
#          submitted from the form - limited to only return documents
#          of the document type given by the field
#          "doctype_2_search". Results and information for the
#          template system are placed on the $output-object.
#          Always returns OBVIUS_OK.
sub action {
    my ($this, $input, $output, $doc, $vdoc, $obvius) = @_;

    $output->param(Obvius_SIDE_EFFECTS => 1);
    my $session = $input->param('SESSION');

    unless ($session->{docs} and @{$session->{docs}}) {
        $obvius->get_version_fields($vdoc, ['doctype_2_search', 'exclude_fields']);
        my $doctype = $obvius->get_doctype_by_name($vdoc->Doctype_2_Search);
        $doctype = $obvius->get_doctype_by_name('Standard') unless($doctype);

        die("No doctype for DocTypeSearch\n") unless($doctype);

        $output->param(doctype_name => $doctype->{NAME});

        my $editpages = $obvius->get_editpages($doctype);
        $editpages = {} unless($editpages);

        my %exclude_fields;
        my $exclude_fields = $vdoc->Exclude_Fields;
        for(split(/\s*,\s*/, $exclude_fields)) {
            $exclude_fields{$_} = 1;
        }

        my @fieldlist;
        for(sort keys %$editpages){
            my $fieldlist = $editpages->{$_}->Fieldlist;
            my @edit_fields = split(/\n/, $fieldlist);
            for(@edit_fields){
                next if($exclude_fields{$_});
                my $data = {};
                my ($id, $desc, $options) = /^(\w*)\s+([^;]*);?(.*)$/;
                next if($exclude_fields{$id} or $exclude_fields{$desc});
                my @options = split(/\s*,\s*/, $options);
                for(@options) {
                    my ($key, $value) = split(/=/, $_);
                    $data->{$key} = $value;
                }
                $data->{description} = $desc;
                $data->{name} = $id;
                push(@fieldlist, $data);
            }
        }

        my $fields = $doctype->Fields;
        $fields = {} unless($fields);

        # Build a list of fields that are both searchable and present in
        # the doctypes' editpages.
        my @fields;
        for my $options (@fieldlist) {

            my $f_name = $options->{name};

            my $field = $fields->{uc($f_name)};
            next unless $field->{'SEARCHABLE'};


            my $f;
            map { $f->{$_} = $options->{$_} } keys %$options;
            $f->{value_field} = $field->{FIELDTYPE}->{VALUE_FIELD};


            # If the edit_args field for the given fieldtype contains a |
            # we build a list of the valid options. We also use text labels
            # from the editpages if they are present.
            my $edit_args = $field->{'FIELDTYPE'}->{'EDIT_ARGS'};
            if($edit_args =~ /.*\|.*/) {
                my @valid_fields = split(/\|/, $edit_args);
                $edit_args = [];
                for(@valid_fields){
                    push(@$edit_args, {
                                        value => $_,
                                        text => $f->{"label_" . $_} ? $f->{"label_" . $_} : $_,
                                        default => ($field->{'DEFAULT_VALUE'} and $field->{'DEFAULT_VALUE'} eq $_)
                                    });
                }
                $f->{edit_options} = $edit_args;
            } else {
                $f->{edit_args} = $edit_args;
            }
            $f->{default_value} = $field->{'DEFAULT_VALUE'};

            push(@fields, $f);
        }

        $output->param(search_fields => \@fields);

        #Default to just printing the search form
        my $op = $input->param('op');

        unless($op and $op eq 'doctypesearch') {
            $output->param(print_form => 1);
            return OBVIUS_OK;
        } else {

            #Start out with an empty session
            $session = {};

            my %op_map = (
                            '=' => '=',
                            '>' => '>',
                            '<' => '<'
                        );

            my @query_fields;
            my $where = "type = " . $doctype->{ID};
            for(@fields){
                my $search_value = $input->param($_->{name});
                next unless($search_value);

                # Magic date stuff
                if($_->{value_field} eq 'date') {
                    if($search_value =~ s/^(\d\d\d\d)[ :\-\/]?(\d\d)[ :\-\/]?(\d\d)//) {
                        my $year = $1;
                        my $month = $2;
                        my $day = $3;

                        if($search_value =~ /\s+(\d\d)[ :\-\/]?(\d\d)[ :\-\/]?(\d\d)\s*$/) {
                            $search_value = "$year-$month-$day $1:$2:$3";
                        } else {
                            $search_value = "$year-$month-$day 00:00:00";
                        }
                    } else {
                        next;
                    }
                } elsif($_->{value_field} eq 'int') {
                    next unless($search_value = ~/^\d+$/);
                } elsif($_->{value_field} eq 'double') {
                    $search_value =~ s/,/\./;
                    next unless($search_value =~ /^\d+\.?\d*/);
                }

                push(@query_fields, $_->{name}) if($obvius->get_fieldspec($_->{name}));

                if(ref($search_value) eq 'ARRAY') {
                    #Here we assume that since this was chosen from a <select multiple> we
                    #should have exact values.
                    my $in = join('\',\'', @$search_value);
                    $where .= ' AND ' . $_->{name} . ' IN (\'' . $in . '\')';
                } else {
                    if($_->{value_field} eq 'text') {
                        $where .= ' AND ' . $_->{name} . ' LIKE \'%' . $search_value . '%\'';
                    } else {
                        my $input_op = $input->param($_->{name} . "_op");
                        $input_op = $op_map{$input_op};
                        $input_op = '=' unless($input_op);

                        $where .= ' AND ' . $_->{name} . ' ' . $input_op . ' \'' . $search_value . '\'';
                    }
                }
            }


            #sorting
            my %sort_map = (
                            'docdate' => 'docdate DESC',
                            'version' => 'version DESC',
                            'title' => 'title'
                        );

            my $sortorder = $input->param('sortorder');
            my $sort_sql = $sort_map{$sortorder};

            push(@query_fields, $sortorder) if($sort_sql
                                                and ! grep{$_ eq $sortorder} @fields
                                                and $obvius->get_fieldspec($sortorder));

            my $is_admin = $input->param('IS_ADMIN');

            $output->param(Obvius_DEPENDENCIES => 1);
            $session->{docs} = $obvius->search(\@query_fields, $where,
                                                'order' => $sort_sql,
                                                'public' => !$is_admin,
                                                'notexpired' => !$is_admin,
                                                'nothidden' => !$is_admin);
            if($session->{docs}) {
                $session->{pagesize} = $input->param('pagesize');

                #Save session on the output object
                $output->param('SESSION' => $session);
            } else {
                $output->param(no_results => 1);
                #Maintain form state
                for(@fields) {
                    $output->param($_->{name} . "_default" => $input->param($_->{name}));
                    $output->param($_->{name} . "_default_op" => $input->param($_->{name} . "_op"))
                        if($input->param($_->{name} . "_op"));
                    $output->param(pagesize_default => $input->param('pagesize'));
                    $output->param(sortorder_default => $input->param('sortorder_default'));
                }
                return OBVIUS_OK;
            }
        }
    }

    # We should always have a session here, either from the input object
    # or the one we made during the search.
    die("No session in DocTypeSearch\n") unless($session);

    if ($session->{pagesize}) {
        my $page = $input->param('p') || 1;
        $this->export_paged_doclist($session->{pagesize}, $session->{docs}, $output, $obvius,
                                        name=>'result_docs', page=>$page,
                                        #prefix => $prefix,
                                        require=>$session->{require},
                                    );
    } else {
        $this->export_doclist($session->{docs},  $output, $obvius,
                                name=>'result_docs',
                                #prefix => $prefix,
                                require=>$session->{require},
                            );
    }

    #make sure we have a session_id
    $output->param('SESSION_ID' => $session->{_session_id}) if($session->{_session_id});

    return OBVIUS_OK;
}

1;
__END__

=head1 NAME

Obvius::DocType::DocTypeSearch - search within one document type only.

=head1 SYNOPSIS

  use Obvius::DocType::DocTypeSearch;

  # Use'd automatically by Obvius.

=head1 DESCRIPTION

The purpose of this document type is to provide a page that can be
used to search for documents that are of one, by the webmaster
defined, document type.

It either presents a search-form displaying the relevant fields that
the user can use to narrow down the search, or it displays the results
of such a search.

=head2 EXPORT

None by default.

=head1 AUTHOR

Jørgen Ulrik B. Krag E<lt>jubk@magenta-aps.dkE<gt>

=head1 SEE ALSO

L<Obvius::DocType>.

=cut
