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
use Encode;
use Unicode::String qw(utf8 latin1);
use Spreadsheet::WriteExcel;

sub make_sure_is_utf8 {
    my $str_list = shift;
    
    $str_list = [$str_list] if (ref $str_list ne 'ARRAY');

    for my $str (@$str_list) {
	my $string = '';

	while($$str) {
	    # Apparently decode, does magic with $str.
	    my $n = decode('utf-8', $$str, Encode::FB_QUIET);
	    $n = encode('iso-8859-1', $n);
	    if (length ($$str)) {
		$n .= substr ($$str, 0, 1);
		$$str = substr($$str,1, length($$str) - 1);
	    }
	    $string .= $n;
	}
	$$str = utf8::upgrade($string);
    }
}

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

    my $entries_xml = join "", $this->get_xml_entries($obvius, docid => $doc->Id);
    make_sure_is_utf8(\$entries_xml);
    
    
    # Remove  xml declaration:

    $xmldata .= "<entries>" . $entries_xml . "</entries>";


    my $formdata_xml = $vdoc->field('formdata') || '';
    make_sure_is_utf8(\$formdata_xml);

    $xmldata .= $formdata_xml . "\n";
    
    $xmldata .= "</formexport>\n";

    my $name = $doc->Name || $doc->Id;

    my $format = $input->param('format') || '';

    if($format eq 'excel') {

        my $d = $this->utf8ify($xmldata);
        my $xml_data = XMLin(   $d,
                                keyattr=>[],
                                forcearray => [ 'field', 'option', 'validaterule', 'entry' ],
                                suppressempty => ''
                            );
        $xml_data = $this->unutf8ify($xml_data);

        my @headers;

        for(@{$xml_data->{fields}->{field} || [] }) {
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

sub flush_xml {
    my ($this, $id, $obvius) = @_;
    my $set = DBIx::Recordset->SetupObject( {'!DataSource' => $obvius->{DB},
                                             '!Table'      => 'formdata'});
    $set->Delete({'docid' => $id});
    $set->Disconnect;
    return OBVIUS_OK;
}

sub action {
    my ($this, $input, $output, $doc, $vdoc, $obvius) = @_;

    # Flushing of XML-file in admin:

    if($input->param('flush_xml')) {
        if ($input->param('is_admin')) {
            my $status = $this->flush_xml($doc->{ID}, $obvius);
            if($status != OBVIUS_OK) {
                print STDERR "Couldn't flush formdata\n";
                return $status;
            }
        } else {
            print STDERR "None-admin tried to flush formula data\n";
            return OBVIUS_OK;
        }
    }



    $obvius->get_version_fields($vdoc, ['formdata' ]);

    my $data = $this->utf8ify($vdoc->field('formdata'));
    my $formdata = XMLin(   $data,
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

#      Get data from datafile:
        my $entries = $this->get_xml_entries($obvius, docid => $doc->{ID}) || [];

#      For each entry, check all fields and see if they're unique and, if they
#      are, match them up against the submitted value for that field.
        for(@$entries) {
            my $entry = XMLin($_);
            my $fields = $entry->{fields}->{field} || [];

            for(@$fields) {
                if($unique{$_->{fieldname}} and ($unique{$_->{fieldname}} eq $_->{fieldvalue})) {
                    $unique_failed{$_->{fieldname}} = 1;
                }
            }
        }
    }


    my @invalid = map {$_->{name}} grep { $_->{invalid} or $_->{mandatory_failed} } @{$formdata->{field}};
    my @not_unique = map {$_->{name}} grep { $unique_failed{$_->{name}} } @{$formdata->{field}};
    if(scalar(@invalid)) { # or scalar(@not_unique)) {
        $output->param('formdata' => $formdata);
        $output->param('invalid' => \@invalid);
        $output->param('not_unique' => \@not_unique);
    } else {
        # Form filled ok, now save/mail the submitted data

        my %entry;

        $entry{date} = $input->param('NOW');
        $entry{fields} = { field => [] };

        for(@{$formdata->{field}}) {
            push(@{$entry{fields}->{field}}, { fieldname => $_->{name}, fieldvalue => $_->{_submitted_value} });
        }

        $this->insert_xml_entry($doc->{ID}, \%entry, $obvius);

        $output->param('submitted_data_ok' => 1);
        $output->param('formdata' => $formdata);
    }

    return OBVIUS_OK;
}


sub get_xml_entries {
    my ($this, $obvius, @how) = @_;
    my @entries;

    my $set = DBIx::Recordset->SetupObject( {'!DataSource' => $obvius->{DB},
                                             '!Table'      => 'formdata'});
    $set->Search({@how});

    while (my $rec = $set->Next) {
        push @entries, $rec->{entry};
    }
    $set->Disconnect();

    return (wantarray ? @entries : \@entries);
}

sub insert_xml_entry {
    my ($this, $id, $entry, $obvius) = @_;

    my $xml = XMLout($entry,
                     rootname => 'entry',
                     noattr => 1);
    
    $obvius->db_begin;

    eval {
	my $set = DBIx::Recordset->SetupObject( 
	    {'!DataSource' => $obvius->{DB}, '!Table'      => 'formdata'});
	$set->Insert( {docid => $id, entry => $xml }); 
	$set->Disconnect();

	$obvius->db_commit;
    };
    
    if ($@) {
	$obvius->db_rollback;
	$this->{DB_Error} = $@;
	$this->{LOG}->error("====> updating form... failed ($@)");
	print STDERR "Couldn't update forms.\n";
    }
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
