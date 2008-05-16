#!/usr/bin/perl

use strict;
use warnings;

use Obvius;
use Obvius::Config;
use Obvius::Data;
use Getopt::Long;
use POSIX qw(strftime);
use WebObvius::Tooltip qw(get_tooltip_path);


my ($doctypes_file, $extra_helpers, $login, $passwd);
GetOptions("doctypes=s" => \$doctypes_file,
           "extrahelpers=s" => \$extra_helpers,
	   "login=s" => \$login,
	   "password=s" => \$passwd
    );

$login = 'admin';
$passwd = 'OCms4KU!test';

(scalar @ARGV) == 1 or usage();

my $site = $ARGV[0];
my $log = Obvius::Log->new('notice');
my $conf = new Obvius::Config($site);

$doctypes_file ||= '/var/www/' . $conf->{SITENAME} . '/db/doctypes.txt';
print STDERR $doctypes_file;
(-f $doctypes_file and (! defined $extra_helpers or -f $extra_helpers)) or usage();

my %doctypes = read_docfile($doctypes_file);
my %extra_doctypes = read_docfile($extra_helpers) if (defined $extra_helpers);

%doctypes = (%doctypes, %extra_doctypes);

my $obvius = new Obvius($conf, $login, $passwd, undef, undef, undef, log => $log);
die "Cannot create Obvius connection" unless ($obvius);

use Data::Dumper;

while (my ($doctype, $field) = each %doctypes) {
    my $status;
    my $parent = $field->{parent};
    my $root = get_tooltip_path(doctype => $doctype);
    my $parent_root = get_tooltip_path(doctype => $parent);

    if (defined $parent && $obvius->lookup_document($parent_root)) {
	$status = make_path($obvius, $root, $parent_root);
    } else {
	$status = make_path($obvius, $root);
    }
    print STDERR "Could not create root: $root\n" if $status == -1;

    for (@{$field->{fields}}) {
	my $path = get_tooltip_path(doctype => $doctype, field => $_);
	my $parent_path = get_tooltip_path(doctype => $parent, field => $_);

	if (defined $parent && $obvius->lookup_document($parent_path)) {
	    $status = make_path($obvius, $path, $parent_path);
	} else {
	    $status = make_path($obvius, $path);
	}
	print STDERR "Could not create $path\n" if $status == -1;
    }
}

sub make_path {
    my ($obvius, $path, $parent_path) = @_;
    my @path = split m|/|, $path;
    shift @path;
    my $doctype = $obvius->get_doctype_by_name('Tooltip');
    if (!defined $doctype) {
	print STDERR "Doctype Tooltip is not defined\n";
	return -1;
    }
    my $doc = $obvius->get_root_document;
    my $parent; 
    for my $comp (@path) {
    	print STDERR "Comp: $comp\n";
	$parent = $doc;
	$doc = $obvius->get_doc_by_name_parent($comp, $parent->{ID});
	my $now = strftime('%Y-%m-%d %H:%M:%S', localtime);
 	if (! defined $doc) {
	    my ($docid, $version) = $obvius->create_new_document($parent, 
								 $comp,
 								 $doctype->{ID},
 								 'en', 
 								 new Obvius::Data (title => $comp,
										   content => "", parent => $parent_path), 
 								 1, 
 								 1);
	    return -1 unless defined ($docid);
	    print STDERR "Created $parent, $comp\n";
	    $doc = $obvius->get_doc_by_id($docid);
	}
	print STDERR "Continuing\n";
    }
    return 0;
}
	    
	    
    
sub usage {
    die "Usage: $0 <-doctype doctypefile> <-extrahelpers extrahelpfile> site\n";
}

sub read_docfile {
    my $file = shift;
    open DOCFILE, "<$file";
    my $current_doctype;
    my %doctypes;

    while ($_ = <DOCFILE>) {
	if (/DocType: (\w+)/i) {
	    $current_doctype = $1;
	    if (/parent=(\w+)/) {
		my $parent = $1;
		@{$doctypes{$current_doctype}->{fields}} = @{$doctypes{$parent}->{fields}};
		$doctypes{$current_doctype}->{parent} = $parent;
	    }
	} elsif (/\s*(\w+)/) {
	    push @{$doctypes{$current_doctype}->{fields}}, $1 if (defined $current_doctype);
	} elsif (!/^\s+$/) {
	    die "Error in $file\nLine: $_\n";
	    
	}
    }
    close DOCFILE;
    return wantarray ? %doctypes : \%doctypes;
}

