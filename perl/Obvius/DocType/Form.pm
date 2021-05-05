package Obvius::DocType::Form;

use strict; use warnings; use utf8;

use utf8;
use Digest::MD5 qw(md5_hex);
use Obvius;
use Obvius::DocType;
use Data::Dumper;
use XML::Simple;
use Encode qw( is_utf8 encode decode from_to );
use WebObvius::Captcha;
use Spreadsheet::WriteExcel;
use MIME::Base64;
use MIME::QuotedPrint;
use File::Path qw( mkpath );
use Fcntl qw( :flock );
use JSON qw( to_json from_json );
use URI::Escape;
use Obvius::CharsetTools qw(:all);
use Obvius::Translations qw(gettext);

our @ISA = qw( Obvius::DocType );
our $VERSION="1.0";

sub generate_head_html {
    my ($this, @args) = @_;
    my $super = $this->SUPER::generate_head_html(@args);

    return join "\n", ($this->add_js('//code.jquery.com/jquery-1.8.3.min.js'), $super);
}

sub ensure_decoded {
    my ($val, $charset) = @_;

    $charset ||= 'iso-8859-1';

    if (ref $val eq 'ARRAY') {
        return [map {ensure_decoded($_, $charset)} @$val];
    } elsif (ref $val eq 'HASH') {
        return { map {ensure_decoded($_, $charset)} %$val};
    } elsif (ref $val eq 'SCALAR') {
        my $scal = ensure_decoded($$val, $charset);
        return \$scal;
     } elsif (ref $val) {
         die "Unknown type: " . ref $val;
     } else {
         return is_utf8($val) ? $val : decode($charset, $val);
     }
}

sub preprocess_fields {
    my ($formspec, $input, $charset) = @_;
    my %outfields;
     
    for my $fn (keys %$formspec) {
	my $field = $formspec->{$fn};

        ### Skip the fieldarea and fieldarea-end field when a form is submitted
	next if ( $field->{type} eq 'fieldset' or $field->{type} eq 'fieldset_end' );
        
        my $value = $input->{$fn};
        my $of = $outfields{$fn} = {};
        
        if ($field->{type} eq 'checkbox' || $field->{type} eq 'selectmultiple') {
             $value = !defined $value ? [] : ref $value ? $value : [ $value ];
             $of->{has_value} = scalar(@$value);
        } elsif (defined $value && $value ne "") {
             $of->{has_value} = 1;
        } else {
             $of->{has_value} = 0;
             $value = "";
        }
        $of->{name} = $field->{name};
        $of->{value} = ref $value ? $value : mixed2perl($value);
        if (!ref ($of->{value})) { 
            $of->{value} =~ s/(?:^\s+|\s+$)//g;
        }
        $of->{type} = $field->{type};
    }

    return \%outfields;
}     


sub is_unique {
    my ($docid, $name, $value, $obvius) = @_;

    my $res = $obvius->execute_select("select id from formdata_entry fe
        join formdata_entry_data using (entry_id)
        where docid=? and name=? and value=? and 
        not fe.deleted",
        $docid, $name, $value);

    return !@$res;
}

# Show placeholder when system is in readonly mode
sub is_readonly { return 0; }

sub validate_mandatory {
    my ($mandatory, $has_value, $fields) = @_;

    if ($mandatory eq '1') {
        return $has_value;
    } elsif ($mandatory =~ s/^!//) {
        return $has_value if(! $fields->{$mandatory}{has_value});
    } elsif ($mandatory) {
        return $has_value if($fields->{$mandatory}{has_value});
    }

    return 1;
}

sub validate_by_rule {
    my ($value, $valrule) = @_;

    my $type = $valrule->{validationtype} || '';
    my $arg = $valrule->{validationargument};
    my $error_msg = $valrule->{errormessage};

    if ($type eq 'regexp') {
        my $res = 1;
        eval  { $res = $value =~ /$arg/ };
        return (!$res, $error_msg);
    } elsif ($type eq 'min_checked') {
        return (ref $value eq 'ARRAY' && @$value < $arg, $error_msg);
    } elsif ($type eq 'max_checked') {
        return (ref $value eq 'ARRAY' && @$value > $arg, $error_msg);
    } elsif ($type eq 'x_checked') {
        return (ref $value eq 'ARRAY' && @$value != $arg, $error_msg);
    } elsif ($type eq 'min_length') {
        return (defined $value && $value ne "" && length($value) < $arg, $error_msg);
    } elsif ($type eq 'max_length') {
        return (defined $value && $value ne "" && length($value) > $arg, $error_msg);
    } elsif ($type eq 'email') {
        return ($value !~ /.+@.+\..+/, 'Ugyldig emailadresse');
    }

    return 0;
}

sub is_included_in {
    my ($lst1, $lst2) = @_;

    $lst1 = [ $lst1 ] if !ref $lst1;
    $lst2 = [ $lst2 ] if !ref $lst2;

    my %hash = map { $_ => 1 } @$lst2;

    for my $elem (@$lst1) {
        return 0 if !$hash{$elem};
    }
    return 1;
}

sub validate_entry {
    my ($fieldspec, $field, $fields, $docid, $obvius) = @_;

    my $valrules = ($fieldspec->{valrules} || {})->{validaterule} || [];
    push @$valrules, { validationtype => 'email' } if $field->{type} eq 'email';

    if ($field->{has_value} || $field->{type} eq 'checkbox' || $field->{type} eq 'selectmultiple') {
        for my $vr (@$valrules) {
            my ($error, $msg) = validate_by_rule($field->{value}, $vr);
            if ($error) {
                $field->{invalid} = $msg;
                last;
            }
        }
    }

    $field->{mandatory_failed} = !validate_mandatory($fieldspec->{mandatory} || 0, 
        $field->{has_value}, 
        $fields);

    $field->{options_failed} = $fieldspec->{options} && $field->{has_value} &&
    !is_included_in($field->{value}, [keys %{$fieldspec->{options}}]);

    $field->{unique_failed} = $fieldspec->{unique} && 
    $fieldspec->{valuetype} eq 'SCALAR' && 
    !is_unique($docid, $field->{name}, $field->{value}, $obvius);
}


sub add_submitted_values  {     
    my ($formdata, $input) = @_;
    
    for my $elem (@$formdata){
        $elem->{_submitted_value} = mixed2perl($input->param($elem->{name}));
    }
}

sub handle_submitted {
    my ($this, $input, $output, $vdoc, $obvius) = @_;

    $obvius->get_version_fields($vdoc, ['entries_for_advert', 'entries_for_close', 'captcha']);
    my $captcha_code = $vdoc->field('captcha');
    my $captcha_checker =  $obvius->config->param('use_recaptcha') ? 
        \&WebObvius::Captcha::check_recaptcha_from_input :  \&WebObvius::Captcha::check_captcha_from_input;

    my $captcha_success = !$captcha_code || $captcha_checker->($input);
    $output->param(captcha_success => $captcha_success);

    return OBVIUS_OK if !$captcha_success;

    my $entries_for_close = $vdoc->field('entries_for_close');
    my $entries_for_advert = $vdoc->field('entries_for_advert');
    my $formdata = get_formdata($vdoc, $obvius);
    my $formspec = convert_formspec($formdata);
    my ($result, @data) = create_new_entry($input, $formspec, $vdoc->Docid, $obvius, 
        $entries_for_close);


    if (!$result) {
        if (ref $data[0]) {
            $output->param(invalid => $data[0]{invalid});
            $output->param(not_unique => $data[0]{non_unique});
            for my $formelem (@$formdata) {
                $formelem->{invalid} = $data[0]{outfields}{$formelem->{name}}{invalid};
                $formelem->{not_unique} = $data[0]{outfields}{$formelem->{name}}{non_unique};
                $formelem->{_submitted_value} = $data[0]{outfields}{$formelem->{name}}{value};
            }
            $output->param(formdata => $formdata);
        } elsif ($data[0] eq 'Full form') {
            $output->param(obvius_full_form => 1);
        }
        return OBVIUS_OK;
    }

    my ($entry_nr, $entry_id, $fields, $count) = @data;
    ### #6601: Saving $entry_nr for use in mason components
    $output->param('form_entry_nr', $entry_nr);

    for my $field (values %$formspec) {
        my $val = $fields->{$field->{name}};
        send_mail($val->{value}, $obvius, $vdoc, $formspec, $fields, $entry_nr) 
        if ($field->{type} eq 'email');
    }

    if ($entries_for_advert && $count == $entries_for_advert) {
        send_advert_mail($vdoc, $count, $obvius);
    } 

    if ($entries_for_close && $count == $entries_for_close) {
        send_close_mail($vdoc, $count, $obvius);
    }

    $output->param(submitted_data_ok => 1);
    return OBVIUS_OK;
}


sub get_formdata {
    my ($vdoc, $obvius) = @_;
    $obvius->get_version_fields($vdoc, ['formdata']);
    my $data = $vdoc->field('formdata');
    return [] if !$data;

    $data = mixed2utf8($data);

    my $formdata = XMLin( $data,
        keyattr=>[],
        forcearray => ['field',
            'option',
            'validaterule'],
        suppressempty => '' );

    return [] if !ref $formdata;

    return $formdata->{field};
}

sub convert_formspec {
    my ($formdata) = @_;

    my $array_or_scalar = sub { 
        $_[0] eq 'checkbox' || $_[0] eq 'selectmultiple' ? 'ARRAY' : 'SCALAR' 
    };

    $formdata = [ $formdata ] if ref $formdata ne 'ARRAY';

    my $prepare_options = sub {
        $_[0] && { map { $_->{optionvalue} => $_->{optiontitle} } @{$_[0]->{option}} };
    };

    for (my $i = 0; $i < @$formdata; $i++) {
        $formdata->[$i]{order} = $i;
    }

    my %formspec = map { 
    $_->{name} => 
    { 
    name => $_->{name},
    title => $_->{title},
    valuetype => $array_or_scalar->($_->{type}),
    type => $_->{type},
    mandatory => $_->{mandatory},
    unique => $_->{unique},
    valrules => $_->{validaterules},
    options => $prepare_options->($_->{options}),
    order => $_->{order}
    }} @$formdata;

    return \%formspec;
}

sub retrieve_file {
    my ($docid, $upload, $obvius) = @_;

    my $upload_location = $obvius->config->{FORM_UPLOAD_DIR};
    die "Form upload dir was not defined" if (!$upload_location);

    die "Form:toobig"
    if ($upload->param('size') > 50_000_000);

    die "Form:exefile" if $upload->param('filename') =~ /\.exe$/i; #"

    my $upload_file_name = $upload->param('filename') || rand;
    $upload_file_name =~ s/[^a-zA-Z\d.]/_/g;

    my $file_name_prefix = '_';
    my $calculate_complete_path = sub {
        my $cand = join '/', ($upload_location, $docid, $file_name_prefix . '_' . $upload_file_name);
        $cand =~ s!/+!/!g;
        return $cand;
    };

    my $dir = $calculate_complete_path->();
    $dir =~ s![^/]*$!!;
    mkpath($dir, 0, 0755);

    open (my $lock, ">", $dir . ".lock");
    eval {
        flock $lock, LOCK_EX or die "Error getting lock";

        while ( -f $calculate_complete_path->()) {
            $file_name_prefix = rand() . "_";
        };

        open (my $fh, '>', $calculate_complete_path->()) or
        die "Couldn't open file: " . $calculate_complete_path->();
        flock $fh, LOCK_EX || (close $fh, die "Couldn't lock file.");
        print $fh $upload->param('data');
        close $fh;
    };
    close $lock;
    die $@ if ($@);

    return ($docid . '/' . $file_name_prefix . '_' . $upload_file_name, 
        $upload->param('mimetype'),
        $upload_file_name
    );
}


sub handle_upload_file {
    my ($docid, $input, $field, $obvius) = @_;

    die "Not an upload file" if ($field->{type} ne 'upload');

    my $upload = $input->param('_incoming_' . $field->{name});
    return undef if !$upload;

    my ($path, $type, $filename) = retrieve_file($docid, $upload, $obvius);
    return to_json({path => $path, type => $type, filename => $filename});
}

sub create_new_entry {
    my ($input, $formspec, $docid, $obvius, $entries_for_close) = @_;

    my @res = validate_full_entry($input, $formspec, $docid, $obvius);
    return @res if !$res[0];

    my %fields = %{$res[1]};

    my ($entry_id, $entry_nr, $count);
    eval {
        ($entry_id, $entry_nr, $count) = 
        insert_entry(\%fields, $docid, $obvius, $entries_for_close);
};

if ($@ eq "Full form") {
    return (undef, "Full form");
} elsif ($@) {
    die $@;
}

return (1, $entry_id, $entry_nr, \%fields, $count);

}

sub validate_full_entry {
    my ($input, $formspec, $docid, $obvius) = @_;

    my @invalid_upload_fields;
    my %input = ref $input ne 'HASH' && $input->UNIVERSAL::can('param') ? 
                map { $_ => mixed2perl($input->param($_)) } keys %$formspec : %$input;  

    for my $val (grep { $_->{type} eq 'upload' } values %$formspec) {
        my $value = eval { handle_upload_file($docid, $input, $val, $obvius) } || undef;
        if ($@) {
            my $error = $@;
            $error =~ s! at /.*!!ms;
            push @invalid_upload_fields, {name => $val->{name}, error => $error}

        }
        $input{$val->{name}} = $value;
    }

    my $outfields = preprocess_fields($formspec, \%input, $obvius->config->param('charset'));
    
    for my $fn (keys %$formspec) {
        validate_entry($formspec->{$fn}, $outfields->{$fn}, $outfields, $docid, $obvius) if ($outfields->{$fn});
    }

    $outfields->{$_->{name}}{invalid}  = $_->{error} for @invalid_upload_fields;
    my @invalid_fields = grep { $_->{invalid} 
    || $_->{mandatory_failed} 
    || $_->{options_failed}} values %$outfields;
    
    my @non_unique_fields = grep { $_->{unique_failed}} values %$outfields;
    
    if (@invalid_fields || @non_unique_fields) {
        return (undef, {invalid => [ map { $_->{name} } @invalid_fields ],
                non_unique => [ map { $_->{name} } @non_unique_fields ],
                outfields => $outfields
            },
        );
    }
    
    return (1,$outfields);
}

sub insert_entry {
    my ($data, $docid, $obvius, $entries_for_close, $nontransactional) = @_;

    my ($entry_id, $entry_nr, $count);
    eval {
        if (!$nontransactional) {
            $obvius->db_begin;
        }
        $obvius->execute_command("lock tables formdata_entry write, formdata_entry_data write");

        $count = count_entries(undef, $docid, $obvius);
        die "Full form" if ($entries_for_close && $count >= $entries_for_close);

        my $res = $obvius->execute_select("select ifnull(max(entry_nr),0) en from 
            formdata_entry where docid=?", $docid);
        $entry_nr = $res->[0]{en};

        $obvius->execute_command("insert into formdata_entry (docid, entry_nr, time) values
            (?, ?, now())", $docid, ++$entry_nr);

        $res = $obvius->execute_select("select last_insert_id() as id");

        $entry_id = $res->[0]{id};
        my @data = map { [ $_->{name}, 
        ref $_->{value} eq 'ARRAY' ? join ",", sort @{$_->{value}} :
        $_->{value},
        $entry_id]} values %$data;
        $obvius->execute_command("insert into formdata_entry_data (name, value, entry_id)
            values (?, ?, ?)", \@data);
        if (!$nontransactional) { $obvius->db_commit;}
    };

    $obvius->execute_command("unlock tables");
    
    if ($@) {
        if (!$nontransactional) { $obvius->db_rollback;}
        die $@;
    };
    
    return ($entry_nr, $entry_id, $count + 1);
}


sub send_advert_mail {
    my ($vdoc, $count, $obvius) = @_;

    my $uri = get_full_uri($vdoc->Docid, $obvius);
    my $subject = "Overvågning af $uri";
    my $msg = "Formularen på $uri har fået $count indtastninger.";

    mail_helper($vdoc, $subject, $msg, $obvius);
}

sub send_close_mail {
    my ($vdoc, $count, $obvius) = @_;

    my $uri = get_full_uri($vdoc->Docid, $obvius);
    my $subject = "Formularen på $uri er nu lukket for indtastninger";
    my $msg = "Formularen $uri har nu modtaget $count indtastninger,
    og er nu lukket for yderligere indtastninger.";

    mail_helper($vdoc, $subject, $msg, $obvius);
}


sub get_full_uri {
    my ($docid, $obvius) = @_;

    my $uri = $obvius->get_doc_uri($docid);
    my $hostmap = Obvius::Hostmap->new_with_obvius($obvius);
    return $hostmap->translate_uri($uri, ':whatever:');
}


my %charset_mail_translation = (
    "utf8" => "UTF-8",
    "utf-8" => "UTF-8",
    "latin1" => "iso-8859-1",
    "iso-8859-1" => "iso-8859-1",
);

sub translate_charset {
    my ($charset) = shift;
    $charset ||= '';
    return $charset_mail_translation{$charset} || $charset;
}

sub mail_helper {
    my ($vdoc, $subject, $msg, $obvius) = @_;

    $obvius->get_version_fields($vdoc, ['mailto']);
    my @mailto = split /;/, $vdoc->field('mailto');

    my $from = $obvius->config->param('mail_from_address') || 'noreply@adm.ku.dk';

    my $charset = $obvius->config->param('charset') || 'ISO-8859-1';
    $charset = translate_charset($charset);

    $subject = encode_base64(encode($charset, $subject));
    $subject =~ s/\n//g;
    $subject = "=?" . uc($charset) . "?B?" . $subject . "?=";

    for my $mt (@mailto) {
        $msg = encode_qp(ensure_correct_encoding($msg, $charset));
        $msg =<<END;
To: <$mt>
From: <$from>
Subject: $subject
MIME-Version: 1.0
Content-Type: text/plain; charset=$charset
Content-Transfer-Encoding: quoted-printable

$msg
END
        $obvius->send_mail($mt, $msg, $from);
    }
 }


sub regret_deletion {
    my ($doc, $obvius) = @_;

    $obvius->execute_command("update formdata_entry set deleted = false where docid=?", $doc->Id);
    return OBVIUS_OK;
}


sub action {
    my ($this, $input, $output, $doc, $vdoc, $obvius) = @_;

    my $formdata = get_formdata($vdoc, $obvius);
    add_submitted_values($formdata, $input) if $input->param('obvius_form_submitted');
    $output->param(formdata => $formdata);

    return regret_deletion($doc, $obvius) if $input->param('obvius_regret_deletion');

    return $this->delete_entries($doc, $obvius) 
    if $input->param('flush_xml') && $input->param('is_admin');

    return $this->handle_submitted($input, $output, $vdoc, $obvius) 
    if $input->param('obvius_form_submitted');

    return OBVIUS_OK;
}


sub retrieve_data {
    my ($obvius, $docid, $entry_nr, $fieldname) = @_;

    my (@vars, @where);
    if ($entry_nr) {
        push @where, "fe.entry_nr = ?";
        push @vars, $entry_nr;
    }

    if ($fieldname) {
        push @where, "fd.name = ?";
        push @vars, $fieldname;
    }

    my $where = join ' and ', @where;
    $where .= ' and ' if $where;

    my $res = $obvius->execute_select("select fe.time time, fe.entry_nr id, 
        fd.name name, fd.value value from
        formdata_entry fe join formdata_entry_data fd using (entry_id) where
        fe.docid = ? and $where not fe.deleted order by fe.entry_nr", $docid, @vars);

    my %output;
    for my $entry (@$res) {
        $output{$entry->{id}} ||= { time => $entry->{time},
            id => $entry->{id},
            fields => {}};
        $output{$entry->{id}}{fields}{$entry->{name}} = $entry->{value};
    }

    return \%output;
}

sub raw_document_data {
    my ($this, $doc, $vdoc, $obvius, $input) = @_;

    $input->no_cache(1);
    return undef if !$input->pnotes('site') || !$input->pnotes('site')->param('is_admin');
    return undef if !$obvius->can_view_document($doc);

    return generate_excel(@_) if ($input->param('get_file'));
    return get_upload_file(@_) if $input->param('get_upload_file'); 
}

sub get_upload_file {
    my ($this, $doc, $vdoc, $obvius, $input) = @_;

    my $entry_nr = $input->param('entry_nr');
    return undef if !$entry_nr;

    my $fieldname = $input->param('fieldname');
    return undef if !$fieldname;

    my $field = retrieve_data($obvius, $vdoc->Docid, $entry_nr, $fieldname);
    return undef if !$field;

    ($field) = values %$field;
    my $field_data = from_json($field->{fields}{$fieldname});
    return undef if !$field_data;

    my $upload_location = $obvius->config->{FORM_UPLOAD_DIR};
    die "Form upload dir was not defined" if (!$upload_location);

    my $path = $upload_location . '/' . $field_data->{path};
    $path =~ s!/+!/!g;

    my $data;
    do {
        local $/ = undef;
        open my $fh, "<", $path or die "Can't open file: $path";
        $data = <$fh>;
        close $fh;
    };
    my $extra_headers;

    return ($field_data->{type}, \$data, $field_data->{filename}, 'attachment', undef, $extra_headers);
}

sub generate_excel {
    my ($this, $doc, $vdoc, $obvius, $input) = @_;

    $obvius->get_version_fields($vdoc, ['title', 'formdata']);

    my $formdata = get_formdata($vdoc, $obvius);
    my $formspec = convert_formspec($formdata);

    my @keys = sort { $formspec->{$a}{order} <=> $formspec->{$b}{order} } keys %$formspec;

    if($input->param('get_all_versions')) {
        my %seen_fields = map { $_ => 1 } @keys;

        my $versions = $obvius->get_versions($doc) || [];
        @$versions = sort { $b->Version cmp $a->Version } grep { $_->Version ne $vdoc->Version } @$versions;

        for my $v (@$versions) {
            my $formdata = get_formdata($v, $obvius);
            my $fs = convert_formspec($formdata);
            my @new_keys = sort { $fs->{$a}{order} <=> $fs->{$b}{order} } grep {!$seen_fields{$_}} keys %$fs;
            for(@new_keys) {
                push(@keys, $_);
                $seen_fields{$_} = 1;
                $formspec->{$_} = $fs->{$_};

            }
        }
    }

    my @headers = map { mixed2perl($_) } @keys;
    unshift @headers, "Dato";
    unshift @headers, "Id";

    my $name = $doc->Name;
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
    $data_format->set_locked(0);
    
    my $entered_data = retrieve_data($obvius, $vdoc->Docid);
    
    my $uri = $obvius->get_doc_uri($doc);
    
    $uri = "http://" . $obvius->config->{ROOTHOST} . $input->notes('prefix') . $uri;
    $uri =~ s!/+$!!;
    $uri .= "?get_upload_file=1&";
    
    my $show_fields = sub {
        my ($fieldname, $entry, $entry_nr) = @_;
    
        return "" if !defined $entry;
    
        if ($formspec->{$fieldname}{type} eq 'upload') {
            my $field = eval { from_json($entry); };
            return "" if !$field;
            return $uri ."entry_nr=" . uri_escape($entry_nr) . "&fieldname=" . $fieldname;
        }
        
        return mixed2perl($entry);
    };
    
    my $i=1;
    for my $entry_nr (sort { $a <=> $b } keys %$entered_data) {
        my $entry = $entered_data->{$entry_nr};
        my @row = map { $show_fields->($_, $entry->{fields}{$_}, $entry_nr) } @keys;
        unshift @row, $entry->{time};
        unshift @row, $entry_nr;
    
        $worksheet->write_row($i++, 0, [ map { /^\s*=/ ? '"' . $_ . '"' : $_ } @row], $data_format);
    }
    $workbook->close();
    
    my ($data, $fh);
    eval {
        open $fh, $tempfile or die "Couldn't open $tempfile, stopping";
        do { local $/; $data = <$fh> };
        close $fh;
    };
    unlink $tempfile;
    
    die $@ if $@;
    return ("application/vnd.ms-excel", $data, $name . ".xls", "attachment");
}

sub delete_entries {
    my ($this, $doc, $obvius) = @_;
    return OBVIUS_OK if 
    !$obvius->can_delete_single_version($doc);
    $obvius->execute_command("update formdata_entry set deleted = true where docid=?", $doc->Id);
    return OBVIUS_OK;
}

our $translation_table = 
{ Dear => {
        en => 'Dear',
        da => 'Kære'
    },
    id => { 
        en => 'ID',
        da => 'Løbenr'
    },
    tastede => {
        da => "Indtastede oplysninger",
        en => "Registered information" 
    },
    formular => {
        da => "Formular",
        en => "Form"
    }
};


sub translate {
    my ($word, $vdoc) = @_;
    my $lang = $vdoc->Lang;
    if (my $word = $translation_table->{$word}) {
        return $word->{$lang} || $word->{en};
    } 
    return $word;
}

sub show_field {
    my ($field) = @_;
    if ($field->{type} eq 'upload') {
        my $val = eval { from_json($field->{value}); };
        if ($@) {
            warn $@;
            return "";
        }
        return $val->{filename};
    } elsif (ref $field->{value} eq 'ARRAY') {
        return join ", ", @{$field->{value}};
    }

    return $field->{value};
}

sub generate_result_view {
    my ($formspec, $fields, $entry_nr, $vdoc) = @_;

    my @entries;
    for my $field (sort { $a->{order} <=> $b->{order} } values %$formspec) {
        push @entries, [$field->{title}, show_field($fields->{$field->{name}})];
    }

    push @entries, ("", [gettext('FormDoctype:id'), $entry_nr]);

    return join "\n", map { ref $_ ? $_->[0] . ": " . $_->[1] : $_} @entries;

}

sub send_mail {
    my ($to, $obvius, $vdoc, $formspec, $fields, $entry_nr) = @_;
    $obvius->get_version_fields($vdoc, [qw (email_subject email_text) ]);

    my $charset = $obvius->config->param('charset') || 'ISO-8859-1';
    $charset = translate_charset($charset);

    my $subject = $vdoc->field('email_subject');
    my ($namefield) = grep { $_->{type} eq 'name' } values %$fields;
    my $prepend = $namefield ? gettext('FormDoctype:Dear') . " " . $namefield->{value}: '';
    
    my $result_view = generate_result_view($formspec,$fields, $entry_nr, $vdoc);
    
    $subject = ensure_correct_encoding($subject, $charset);
    $subject = encode_base64($subject);
    $subject =~ s/\n//g;
    $subject = "=?" . uc($charset) . "?B?" . $subject . "?=";

    my $text = mixed2perl($vdoc->field('email_text'));
    
    my $result_prefix = gettext("FormDoctype:tastede");
    
    my $uri = get_full_uri($vdoc->Docid, $obvius);
    my $form = gettext("FormDoctype:formular");

    my $from = $obvius->config->param('mail_from_address') || 'noreply@adm.ku.dk';

    my $inner = encode_qp(ensure_correct_encoding(<<END, $charset));
$prepend

$text

----

$result_prefix:

$result_view
$form: $uri
END

    my $mailmsg = <<END;
To:      $to
From:    $from
Subject: $subject
MIME-Version: 1.0
Content-Type: text/plain; charset=$charset
Content-Transfer-Encoding: quoted-printable

$inner
END

    $obvius->send_mail($to, $mailmsg, $from);
}

sub ensure_correct_encoding {
    my ($input, $charset) = @_;

    return mixed2charset($input, $charset);
}

sub count_entries {
    my ($this, $id, $obvius) = @_;

    my $res = $obvius->execute_select("select count(*) c from formdata_entry 
        where docid=? and not deleted", $id);

    return $res->[0]{c};
}

sub count_deleted {
    my ($this, $id, $obvius) = @_;
    my $res = $obvius->execute_select("select count(*) c from formdata_entry 
        where docid=? and deleted", $id);

    return $res->[0]{c};
}

1;
