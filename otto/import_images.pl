#!/usr/bin/perl

# import_images.pl - import images from old MCMS db into new.
#
# Copyright 2001 (C) by Magenta ApS. Under the GNU GPL.
#
# $Id$

use strict;
use warnings;

use locale;

use Carp;

use Benchmark;
use Data::Dumper;

use Obvius;
use Obvius::Config;

use Image::Size;
use POSIX qw(strftime);

use DBI;
use DBIx::Recordset;
my $dbi_debug=2;

$Data::Dumper::Indent = 1;

my $t0 = new Benchmark;
END {
    print STDERR "Time taken: ", timestr(timediff(new Benchmark, $t0)),"\n";
}

my ($old_db_name, $new_db_name, $doc_path) = @ARGV;

die "Usage: import_images.pl <old db name> <new Obvius name> <doc path>\n"
    unless ($old_db_name and $new_db_name and $doc_path and -d $doc_path);

my $obvius = new Obvius(new Obvius::Config($new_db_name));
die "Open obvius new failed" unless ($obvius);

my $doctype = $obvius->get_doctype_by_name('Image');
die "Document type 'Image' not found" unless ($doctype);
#print Dumper($doctype);

for ($doctype->field) {
    printf STDERR "Field %s: type %s, default %s\n", $_, $doctype->field($_)->FieldType->Name, $doctype->field($_)->Default_Value || 'NULL';
}

sub slurp {
    my $file = shift;

    my $fh;
    open($fh, "<$file") or return undef;
    local $/ = undef;
    return <$fh>;
}

sub mimetype {
    my $file = shift;

    my $mimetype = qx{file -b -i $file};
    chomp $mimetype;
    return $mimetype or undef;
}

my $old_images = DBIx::Recordset->SetupObject({'!DataSource' => "dbi:mysql:$old_db_name",
					       '!Username'   => 'rene',
					       '!Password'   => 'myindal',
					       '!Fields'     => '*',
					       '!Table'      => 'images',
					       '!Debug'      => $dbi_debug,
					       '!TieRow'     => 0,
					      }) ;
$old_images->Search();
while (my $rec = $old_images->Next) {
    print "Image data: ", Dumper($rec);

    my $parent = $obvius->get_doc_by_id($rec->{docid});
    unless (defined $parent) { warn "No parent document $rec->{docid}"; next }
    my $name = $rec->{link};

    my $lang = 'da';
    my $type = $doctype->ID;
    my $fields = $doctype->default_fields;

    my $data = slurp("$doc_path/$rec->{file}");
    unless (defined $data) { warn "No image file $doc_path/$rec->{file}"; next }
    $fields->param(data => $data);

    my ($w, $h) = imgsize(\$data);
    $fields->param(width => $w);
    $fields->param(height => $h);

    $fields->param(mimetype => mimetype("$doc_path/$rec->{file}"));

    $fields->param(title => $rec->{name});
    $fields->param(scale => $rec->{scale});
    $fields->param(align => $rec->{align});

    $fields->param(lang => $lang);

    $fields->param(docdate => strftime('%Y-%m-%d', localtime));
    $fields->param(expires => '9999-01-01 00:00:00');

    #print Dumper($fields);

    if ($doctype->validate_fields($fields, $obvius)) {
	warn "New document validates";
    } else {
	warn "New document does not validate";
    }

    my $doc = $obvius->get_doc_by_name_parent($name, $parent->param('id'));
    my $vdoc;
    unless ($doc) {
	my ($docid, $version) = $obvius->create_new_document($parent, $name, $type, $lang, $fields);
	unless (defined $docid) {
	    warn $obvius->db_error;
	    next;
	}

	$doc = $obvius->get_doc_by_id($docid);
	$vdoc = $obvius->get_version($doc, $version);
    } else {
	$vdoc = $obvius->get_latest_version($doc);
    }

    $obvius->get_version_fields($vdoc, 255);
    $vdoc->publish_field(published => strftime('%Y-%m-%d %H:%M:%S', localtime));

    if ($obvius->publish_version($vdoc)) {
	print STDERR "New image published\n";
    } else {
	print STDERR "Error publishing image: ", $obvius->db_error, "\n";
    }
}
