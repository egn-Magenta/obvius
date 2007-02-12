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
use POSIX qw(strftime);
use Unicode::String qw(utf8 latin1);
use Spreadsheet::WriteExcel;

our @ISA = qw( Obvius::DocType );
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

# raw_document_data($document, $version, $obvius)
#    - generates a XML document with the colledted form data and returns
#      it as uploaddata with text/xml mimetype. Also sets a filename and
#      content-disposition: attachment to make sure the xml file is
#      downloaded correctly. Doesn't return anything unless in admin
#      and get_file=1 is passed as an URL param
sub raw_document_data {
    my ($this, $doc, $vdoc, $obvius, $input) = @_;

    # Convert input to Apache::Request:
    $input = ref($input) eq 'Apache' ? Apache::Request->new($input) : $input;

    unless($input->param('get_file')) {
        return (undef, undef, undef);
    }

    return undef unless($input->pnotes('site') && $input->pnotes('site')->param('is_admin'));

    $obvius->get_version_fields($vdoc, ['title', 'formdata']);

    my $xmldata = '<?xml version="1.0" encoding="UTF-8" standalone="yes" ?>' . "\n";
    $xmldata .= "<formexport>\n";
    $xmldata .= "  <title>" . $vdoc->field('title') . "</title>\n";
    $xmldata .= "  <url>" . $obvius->get_doc_uri($doc) . "</url>\n";
    $xmldata .= "  <docid>" . $doc->Id . "</docid>\n";
    $xmldata .= "  <version>" . $vdoc->Version . "</version>\n";
    $xmldata .= "  <downloaddate>" . strftime('%Y-%m-%d %H:%M:%S', localtime) . "</downloaddate>\n";

    my $data_dir = $obvius->config->param('forms_data_dir') || '/tmp';
    $data_dir .= "/" unless($data_dir =~ m!/$!);
    my $data_file = $data_dir . $doc->Id . ".xml";

    my $entries_xml = '';

    if(open(FH, $data_file)) {
        $entries_xml = join("", <FH>);
        close(FH);

        # Remove  xml declaration:
        $entries_xml =~ s!^<[?]xml[^>]+>\s*!!s;

        # Indent:
        $entries_xml =~ s/^/  /m;
    }

    $xmldata .= $entries_xml;

    my $formdata_xml = $vdoc->field('formdata') || '';

    $entries_xml =~ s/^/  /m;
    $xmldata .= $formdata_xml . "\n";

    $xmldata .= "</formexport>\n";

    my $name = $doc->Name || $doc->Id;

    my $format = $input->param('format') || '';

    if($format eq 'excel') {

        my $xml_data = XMLin(
                                $xmldata,
                                keyattr=>[],
                                forcearray => [ 'field', 'option', 'validaterule', 'entry' ],
                                suppressempty => ''
                            );
        my @headers;

        for(@{ $xml_data->{fields}->{field} || [] }) {
            my $header = $_->{title} . " (" . $_->{name} . ")";
            $header = $this->unutf8ify($header);
            push(@headers, $header);
        }


        my @data;

        my $tempfile="/tmp/" . $name . ".xls";
        my $workbook=Spreadsheet::WriteExcel->new($tempfile);
        my $worksheet=$workbook->addworksheet();

        # Headers:
        my $header_format=$workbook->addformat();
        $header_format->set_bold();
        $worksheet->write_row(0, 0, \@headers, $header_format);

        # Data:
        my $data_format=$workbook->addformat();
        $data_format->set_align('top');
        my $i=1;

        for(@{ $xml_data->{entries}->{entry} || [] }) {
            my @row;
            my $fields = $_->{fields}->{field} || [];
            for(@$fields) {
                my $val = $_->{fieldvalue};

                if(ref $val) {
                    $val = join(", ", @$val);
                }

                $val = $this->unutf8ify($val);
                push(@row, $val);
            }

            $worksheet->write_row($i, 0, \@row, $data_format);
            $i++;
        }

        # Close $tempfile, read it and delete it:
        my $data='';
        $workbook->close();
        my $fh;
        open($fh, $tempfile) or die "Couldn't open $tempfile, stopping";
        { local $/; $data=<$fh>; }
        close $fh;
        unlink $tempfile;

        return ("application/vnd.ms-excel", $data, $name . ".xls", "attachment");
    }


    return ("text/xml", $xmldata, $name . ".xml", "attachment");
}



sub action {
    my ($this, $input, $output, $doc, $vdoc, $obvius) = @_;


    # Flushing of XML-file in admin:
    if($input->param('is_admin')) {
        if($input->param('flush_xml')) {
            $output->param('flush_xml' => 1);
            if($input->param('confirm')) {
                my $data_dir = $obvius->config->param('forms_data_dir') || '/tmp';
                $data_dir .= "/" unless($data_dir =~ m!/$!);

                my $data_file = $data_dir . $doc->Id . ".xml";

                if(open(FH, ">$data_file")) {
                    print FH '<?xml version="1.0" encoding="UTF-8" standalone="yes" ?>' . "\n";
                    print FH "<entries></entries>\n";
                    close(FH);
                    $output->param('flushed_ok' => 1);
                } else {
                    print STDERR "Couldn't flush datafile $data_file. Permission problem?\n";
                    return OBVIUS_OK;
                }
            }
        }
    }


    $obvius->get_version_fields($vdoc, ['formdata' ]);

    my $formdata = XMLin(
                            $vdoc->field('formdata'),
                            keyattr=>[],
                            forcearray => [ 'field', 'option', 'validaterule' ],
                            suppressempty => ''
                        );
    $formdata=$this->unutf8ify($formdata); # XMLin automatically generates utf8 data.
                                           # We want the data as latin1, so converting here.

    unless($input->param('obvius_form_submitted')) {
        # Form not submitted yet, just output the form:
        $output->param('formdata' => $formdata);
        return OBVIUS_OK;
    }


    # Ok assume data submitted, now validate:

    my %fields_by_name;

    for my $field (@{$formdata->{field}}) {
        my $value = $input->param($field->{name});

        # Make sure we have arrays for "multiple" fieldtypes
        if($field->{type} eq 'checkbox' or $field->{type} eq 'selectmultiple') {
            $value ||= [];
            $value = [ $value ] unless(ref($value));

            $field->{has_value} = scalar(@$value) || undef;
        } else {
            if(defined($value) and $value ne "") {
                $field->{has_value} = 1;
            } else {
                $field->{has_value} = 0;
                $value = ''; # Set value to an empty string for later comparison
            }
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

            # Note that text-tests (length and regexp) is only performed if the
            # submitted field has a value. If you want to make sure a field is
            # filled use the mandatory flag.
            if($type eq 'regexp' and $field->{has_value}) {
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
            } elsif($type eq 'max_checked') {
                if(scalar(@$value) > $arg) {
                    $field->{invalid} = $_->{errormessage};
                }
            } elsif($type eq 'x_checked') {
                if(scalar(@$value) != $arg) {
                    $field->{invalid} = $_->{errormessage};
                }
            } elsif($type eq 'min_length' and $field->{has_value}) {
                if(length($value) < $arg) {
                    $field->{invalid} = $_->{errormessage};
                }
            } elsif($type eq 'max_length' and $field->{has_value}) {
                if(length($value) > $arg) {
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

    # Third run - check for unique data:

    # Build a hash with unique fieldnames as keys and submitted values as values
    my %unique = map { $_->{name} => $_->{_submitted_value} } grep { $_->{unique} } @{$formdata->{field}};
    my %unique_failed;

    if(scalar(%unique)) {

        # Get data from datafile:
        my $data_file = $this->get_datafile_name($obvius, $doc);
        my $xml = $this->get_datafile_xml_data($data_file) || {};

        my $entries = $xml->{entry} || [];

        # For each entry, check all fields and see if they're unique and, if they
        # are, match them up against the submitted value for that field.
        for(@$entries) {
            my $fields = $_->{fields}->{field} || [];

            for(@$fields) {
                if($unique{$_->{fieldname}} and ($unique{$_->{fieldname}} eq $_->{fieldvalue})) {
                    $unique_failed{$_->{fieldname}} = 1;
                }
            }
        }
    }


    my @invalid = map {$_->{name}} grep { $_->{invalid} or $_->{mandatory_failed} } @{$formdata->{field}};
    my @not_unique = map {$_->{name}} grep { $unique_failed{$_->{name}} } @{$formdata->{field}};
    if(scalar(@invalid) or scalar(@not_unique)) {
        $output->param('formdata' => $formdata);
        $output->param('invalid' => \@invalid);
        $output->param('not_unique' => \@not_unique);
    } else {
        # Form filled ok, now save/mail the submitted data

        my $data_file = $this->get_datafile_name($obvius, $doc);
        my $xml = $this->get_datafile_xml_data($data_file);

        return OBVIUS_OK unless($xml);

        my %entry;

        $entry{date} = $input->param('NOW');
        $entry{fields} = { field => [] };

        for(@{$formdata->{field}}) {
            push(@{$entry{fields}->{field}}, { fieldname => $_->{name}, fieldvalue => $_->{_submitted_value} });
        }

        push(@{ $xml->{entry} }, $this->unutf8ify(\%entry));
        #push(@{ $xml->{entry} }, %entry);

        #$xml = $this->utf8ify($xml);

        XMLout(
                $xml,
                rootname=>'entries',
                noattr=>1,
                outputfile => $data_file,
                xmldecl=> '<?xml version="1.0" encoding="UTF-8" standalone="yes" ?>'
            );

        $output->param('submitted_data_ok' => 1);
        $output->param('formdata' => $formdata);
    }

    return OBVIUS_OK;
}

sub unutf8ify {
    my ($this, $obj)=@_;

    my $ref=ref $obj;

    if (!$ref) { # Scalar:
        return utf8($obj)->latin1;
    }
    elsif ($ref eq 'ARRAY') { # Array:
        return [ map { $this->unutf8ify($_) } @$obj ];
    }
    elsif ($ref eq 'HASH') { # Hash:
        return { map { $_ => $this->unutf8ify($obj->{$_}) } keys (%$obj) };
    }
    else {
        return 'UNUNUTF8IFIABLE';
    }
}

sub utf8ify {
    my ($this, $obj)=@_;

    my $ref=ref $obj;

    if (!$ref) { # Scalar:
        return latin1($obj)->utf8;
    }
    elsif ($ref eq 'ARRAY') { # Array:
        return [ map { $this->utf8ify($_) } @$obj ];
    }
    elsif ($ref eq 'HASH') { # Hash:
        return { map { $_ => $this->utf8ify($obj->{$_}) } keys (%$obj) };
    }
    else {
        return 'UNUTF8IFIABLE';
    }
}

sub get_datafile_name {
    my ($this, $obvius, $doc) = @_;

    my $data_dir = $obvius->config->param('forms_data_dir') || '/tmp';
    $data_dir .= "/" unless($data_dir =~ m!/$!);

    my $data_file = $data_dir . $doc->Id . ".xml";

    return $data_file;

}

sub get_datafile_xml_data {
    my ($this, $data_file) = @_;

    if(! -f $data_file) {
        # create the file:
        if(open(FH, ">$data_file")) {
            print FH '<?xml version="1.0" encoding="UTF-8" standalone="yes" ?>' . "\n";
            print FH "<entries></entries>\n";
            close(FH);
        } else {
            print STDERR "Couldn't create datafile $data_file. Form data may be lost.\n";
            return undef;
        }
    }

    my $xml = XMLin($data_file, keyattr=>[], forcearray => [ 'entry', 'field' ], suppressempty => '') || {};

    $xml = $this->unutf8ify($xml);

    $xml->{entry} ||= [];

    return $xml;
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
