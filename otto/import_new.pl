#!/usr/bin/perl

# import_new.pl - import, roughly, and old MCMS-db into the new Obvius model.
#
# Copyright 2001 (C) by Adam Sjøgren. Under the GNU GPL.
#
# $Id$

#
# TODO:
#
#  * image - fra nummer til sti
#  * konvertér image-tabellen til dokumenter - separat script, opret via Obvius
#  * category, keyword, template Xref
#  * overfør kun felter der rent faktisk er i doctype'ns fieldspec, brok hvis
#    data derved smides bort (ikke-tomme felter).
#  * konverter quiz-dokumenter til Quiz og QuizQuestion
#

use strict;
use warnings;

use locale;

use Carp;

use Benchmark;
use Data::Dumper;

use DBI;
use DBIx::Recordset;
my $dbi_debug=0;

my $old_db_name=shift @ARGV;
my $new_db_name=shift @ARGV;
my $doc_path=shift @ARGV;
die "Usage: import_new.pl <old db name> <new db name> <doc path>\n" unless ($old_db_name and $new_db_name and $doc_path);

my $t0 = new Benchmark;

END {
    my $t1=new Benchmark;
    my $td = timediff($t1, $t0);
    print timestr($td),"\n";
}

my %old=(
	 db      =>$old_db_name,
	 dbh     =>undef,
	 user    =>$ENV{USER},
	 password=>$ENV{PASSWD},
	);

my %new=(
	 db      =>$new_db_name,
	 dbh     =>undef,
	 user    =>'rene',
	 password=>'myindal',
	);


my $doctypes = read_doctypes(\%new);
my $field_name_type_map = read_fieldspec_typemap(\%new);

my %defoptodoctype = (
		      # userlist=>?,
		      # grouplist=>?,
		      # 'subscriber_search'=>?
		      'mail_data'      =>$doctypes->{CreateDocument}->{id},
		      'advanced_search'=>$doctypes->{Search}->{id},
		      'keywords'       =>$doctypes->{KeywordSearch}->{id},
		      'mail_order'     =>$doctypes->{OrderForm}->{id},
		     );
my $fieldtypes = read_fieldtypes(\%new);

my $fields="author, content, contributors, default_op, vdocs.docdate as docdate, docref, doctype, vdocs.expires as expires, gduration, gperms, gprio, grp, helptext, docs.id as id, image, lang, lduration, lprio, lsection, mini_icon, docs.name as name, operms, owner, pagesize, parent, public, published, vdocs.seq as seq, short_title, sortorder, source, subname, subscribeable, teaser, vdocs.template, template_filter, vdocs.title as title, url, vdocs.version as version, docs.version as public_version";

my $old_set = DBIx::Recordset -> SetupObject ({'!DataSource' => "dbi:mysql:$old{db}",
					       '!Username'   => $old{user},
					       '!Password'   => $old{password},
					       '!Fields'     => $fields,
					       '!Table'      => 'docs, vdocs, templates',
					       '!Debug'      => $dbi_debug,
					      });

my $new_documents = DBIx::Recordset -> SetupObject ({'!DataSource' => "dbi:mysql:$new{db}",
						     '!Username'   => $new{user},
						     '!Password'   => $new{password},
						     '!Table'      => 'documents',
#						     '!Debug'      => $dbi_debug,
						    });

my $new_versions = DBIx::Recordset -> SetupObject ({'!DataSource' => "dbi:mysql:$new{db}",
						    '!Username'   => $new{user},
						    '!Password'   => $new{password},
						    '!Table'      => 'versions',
#						    '!Debug'      => $dbi_debug,
						   });

my $new_vfields = DBIx::Recordset -> SetupObject ({'!DataSource' => "dbi:mysql:$new{db}",
						   '!Username'   => $new{user},
						   '!Password'   => $new{password},
						   '!Table'      => 'vfields',
#						   '!Debug'      => $dbi_debug,
						  });

my $new_docparms = DBIx::Recordset -> SetupObject ({'!DataSource' => "dbi:mysql:$new{db}",
						    '!Username'   => $new{user},
						    '!Password'   => $new{password},
						    '!Table'      => 'docparms',
#						    '!Debug'      => $dbi_debug,
						   });

# Documents, versions:
print "Joining documents and versions...\n";
$old_set->Search({'$where' => 'docs.id=vdocs.id and vdocs.template=templates.id ORDER BY docs.id'});

print "Importing documents and versions...\n";
my $v=0; my $d=0; my $previd='';
while( my $row=$old_set->Next ) {
    my %new = ( %$row );

    # New version:
    my @new_vfields=qw(title teaser docdate seq pagesize sortorder subscribeable expires gprio gduration
		       lprio lduration lsection author short_title content url docref contributors source
		       image published template lang mimetype doctype);

    # Determine rough type:
    my $doctype;
    # print " $new{id} $new{version} default_op: $new{default_op}\n" if $new{default_op};

    $doctype=$doctypes->{doctypeuc($new{default_op})}->{id}; # Straight forward
    $doctype=$defoptodoctype{$new{default_op}} unless $doctype;

    # More detection:
    if( $new{file} and (
			$new{file} eq 'html' or
			$new{file} eq 'upload' or
			$new{file} eq 'html-næsten')) {

	$doctype=$doctypes->{HTML}->{id};
	# Add field for displaying title/teaser
	if( $new{file} eq 'html-næsten' ) {
	    $new{bare}=0;
	}
    }

    if( $new{helptext} =~ /document_class=([^\W]+)/mi ) {
	if( $1 eq "kalender" ) {
	    $doctype=$doctypes->{Event}->{id};
	}
	else {
	    # Statusblad
	    # konventionen
    	    $new{document_class}=$1;
	    push @new_vfields, "document_class";
	}
    }
    if( $new{helptext} =~ /require=([^\W]+)/mi ) {
	$new{require}=$1;
	push @new_vfields, "require";
    }
    if( $new{helptext} =~ /base=([^\s]+)/mi ) {
	$new{base}=$1;
	push @new_vfields, "base";
	if( $new{helptext} =~ /(keyword|category|month|weeks)\s*=\s*(.*)/mi ) {
	    $new{search_type}=$1;
	    $new{search_expression}=$2;
	    push @new_vfields, 'search_type';
	    push @new_vfields, 'search_expression';
	}
    }
    if ($new{helptext} =~ /mailmsg\s*=\s*([^\s]+)/mi) {
	$new{mailmsg}=$1;
	push @new_vfields, "mailmsg";
	if ($new{helptext} =~ /mailto\s*=\s*([^\s]+)/mi) {
	    $new{mailto}=$1;
	    push @new_vfields, "mailto";
	}
	else {
	    warn "$new{id} $new{version} mailmsg without mailto!\n";
	}
	$doctype=$doctypes->{OrderForm}->{id};
    }

    # Image, Upload (url-link)
    if ( $new{url} =~ /^=\/upload\/([^\/]+)\/([^\/]+)\/([^\/]+)$/ ) {
	my($url_type, $url_filename)=($1, $3);
	print " Uploaded document $new{id}, $url_type, $url_filename\n";
	# Set mimetype
	my $tmp = substr($new{url}, 1);
	$new{mimetype}=`file -b -i $doc_path$tmp 2>/dev/tty`;
	chomp $new{mimetype};
	# Find file on disk and put in blob
	if ( open(FH, "$doc_path$tmp") ) {
	    local $/ = undef;
	    $new{data}= <FH>;
	    push @new_vfields, "data";
	} else {
	    warn "Couldn't read $doc_path$new{url}\n";
	}
	$doctype=$doctypes->{Upload}->{id};
    }

    unless ( $doctype ) {
	print " NOTICE: $new{id} $new{version} $new{default_op} defaulted to Standard doctype.\n"
	    unless $new{default_op} eq ""; # do_view anyway
	$doctype=$doctypes->{Standard}->{id};
    }

    # Special fields:
    if( $new{default_op} eq 'combo_search' ) {
	$new{search_expression}=$new{helptext};
	push @new_vfields, 'search_expression';
    }

    # print " default_op: $new{default_op}, doctype: $doctype\n" if( !$doctype or $doctype!=2);

    if( $previd eq $new{id} ) {
	# New version of same document:
	#print "  $new{version}\n";
    }
    else { # New document, insert in documents-table:
	$d++;
	# print "  $d\r" if (($d % 100)==0);
	#print " New document, id, title: $new{id} $new{title}\n";
	#print "  $new{version}\n";
	$new_documents->Insert({
				id    =>$new{id},
				parent=>$new{parent},
				name  =>$new{name},
				type  =>$doctype,
				owner =>$new{owner},
				grp   =>$new{grp},
				operms=>$new{operms},
				gperms=>$new{gperms},
			       });

	# Document-parameters
	insert_docparms(\%new, qw(mini_icon subname));
    }
    $previd=$new{id};

    $v++;
    print "  $d:$v\r";
    my $public_version=0;
    $public_version=1 if (($new{public}) and ($new{version} eq $new{public_version}));
    $new_versions->Insert({
			   docid  =>$new{id},
			   version=>$new{version},
			   type   =>$doctype,
			   public =>$public_version,
			   lang   =>'da',
			   });

    #my $i=1;
    #map { print "$d $v $i $_: [$new{$_}]\n"; $i++ } sort keys %new;
    #print "\n";
    #my $hep=<STDIN>;

    insert_vfields($new_vfields, \%new, @new_vfields);
}

print " Documents: $d\n";
print "  Versions: $v\n";

# Category
print "Importing categories...\n";
import_table(\%old, \%new, 'categories');
import_categories(\%old, $new_vfields, $new_versions);

# Keywords
print "Importing keywords...\n";
import_table(\%old, \%new, 'keywords');
import_keywords(\%old, $new_vfields, $new_versions);

# Users, groups:
print "Importing users...\n";
import_table(\%old, \%new, 'users');
print "Importing groups...\n";
import_table(\%old, \%new, 'groups');
print "Importing grp_user...\n";
import_table(\%old, \%new, 'grp_user');

# Templates
print "Importing templates...\n";
import_table(\%old, \%new, 'templates');

# Subscribers, subscriptions:
print "Importing subscribers...\n";
import_table(\%old, \%new, 'subscribers');
print "Importing subscriptions...\n";
import_table(\%old, \%new, 'subscriptions');

print "Done.\n";
exit 0;

sub import_table {
    my($old, $new, $table)=@_;

    my $old_set = DBIx::Recordset -> SetupObject ({'!DataSource' => "dbi:mysql:$old->{db}",
						   '!Username'   => $old->{user},
						   '!Password'   => $old->{password},
						   '!Table'      => $table,
						  }) or die DBIx::Recordset->LastError();

    my $new_set = DBIx::Recordset -> SetupObject ({'!DataSource' => "dbi:mysql:$new->{db}",
						   '!Username'   => $new->{user},
						   '!Password'   => $new->{password},
						   '!Table'      => $table,
						  }) or die DBIx::Recordset->LastError();

    my $c=0;
    $old_set->Search();
    while( my $row=$old_set->Next ) {
	$c++;
	# map { print "$c $_: $row->{$_}\n" } keys %{$row};
	$new_set->Insert($row) or die $new_set->LastError();
    }

    print " $c\n";
}

sub import_categories {
    my($old, $new_vfields, $new_versions)=@_;

    import_m($old, $new_vfields, $new_versions, 'cat_doc, categories', 'catid=id', 'category');
}

sub import_keywords {
    my($old, $new_vfields, $new_versions)=@_;

    import_m($old, $new_vfields, $new_versions, 'kw_doc, keywords', 'kwid=id', 'keyword');
}

sub import_m {
    my($old, $new_vfields, $new_versions, $table, $where, $name)=@_;

    my $old_set = DBIx::Recordset -> SetupObject ({'!DataSource' => "dbi:mysql:$old->{db}",
						   '!Username'   => $old->{user},
						   '!Password'   => $old->{password},
						   '!Table'      => $table,
						  }) or die "$!";

    $old_set->Search({'$where'=>$where});

    my $c=0;
    while( my $row=$old_set->Next ) {
	$c++;
	my $versions=get_versions($new_versions, $row->{docid});
	my $field = $field_name_type_map->{$name} || 'text';
	map {
	    $new_vfields->Insert({
				  docid  =>$row->{docid},
				  version=>$_,
				  name   =>$name,
				  "${field}_value"  =>$row->{id},
				 });
	} @{$versions};
    }
    print " $c\n";
}

sub get_versions {
    my($new_versions, $id)=@_;

    my @versions;
    $new_versions->Search({'$where'=>"docid=$id"});
    while( my $row=$new_versions->Next )
    {
	push @versions, $row->{version};
    }

    return \@versions;
}

sub insert_vfields
{
    my($new_vfields, $row, @new_fields)=@_;

    my %fieldnamemap = ( ); # helptext=>'search_expression',

    map {
	my $field = $field_name_type_map->{$_} || 'text';
	$field='text' if $_ eq 'base'; # Special case
	# print STDERR " docid: $row->{id}, version: $row->{version}, field: $_ type: $field\n";

	$new_vfields->Insert({
			      docid  =>$row->{id},
			      version=>$row->{version},
			      name=>$fieldnamemap{$_} ? $fieldnamemap{$_} : $_,
			      "${field}_value" =>(defined $row->{$_} ? $row->{$_} : ''),
			     });
    } @new_fields;
}

sub insert_docparms
{
    my($row, @fields)=@_;

    my %fielddefaultvalue = (
			     subname  =>'doc',
			    );

    while( my $field=shift @fields ) {
	if( $row->{$field} and $row->{$field} ne "" and
	    !($fielddefaultvalue{$field} and $fielddefaultvalue{$field} eq $row->{$field}) ) {
	    $new_docparms->Insert({
				   id   =>$row->{id},
				   type =>$fieldtypes->{text},
				   name =>$field,
				   value=>$row->{$field},
				  });
	}
    }
}

sub doctypeuc {
    my($t)=@_;

    $t=~s/_(.)/\U$1\E/g;
    $t=~s/^(.)/\U$1\E/;

    return $t;
}

sub read_doctypes {
    my($new)=@_;

    my $doctypes=read_table('doctypes', 'name', $new);
}

sub read_fieldtypes {
    my($new)=@_;

    return read_table('fieldtypes', 'name', $new);
}

sub read_fieldspec_typemap {
    my($new)=@_;

    my $types = read_table('fieldtypes', 'id', $new);
    my $specs = read_table('fieldspecs', 'name', $new);

    my %map;
    for (keys %$specs) {
	my $name = $specs->{$_}->{name};
	my $type = $specs->{$_}->{type};
	$map{$name} = $types->{$type}->{value_field};
    }

    return \%map;
}

sub read_table {
    my($table, $key, $db)=@_;

    my $set = DBIx::Recordset -> SetupObject ({'!DataSource' => "dbi:mysql:$db->{db}",
					       '!Username'   => $db->{user},
					       '!Password'   => $db->{password},
					       '!Table'      => $table,
					       '!Debug'      => $dbi_debug,
					      });
    my %entries;
    $set->Search();
    while( my $rec=$set->Next ) {
	my %fields=( %$rec );
	$entries{$rec->{$key}}=\%fields;
    }

    return \%entries;
}
