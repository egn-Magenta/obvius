#!/usr/bin/perl

#
# add_editpages.pl
#
# $Id$
#

use strict;
use warnings;

use locale;
use Carp;

use DBI;
use DBIx::Recordset;
my $dbi_debug=0;

##
my %db = ();

$db{db}=shift @ARGV;
$db{file}=shift @ARGV;
my $dbuser=shift @ARGV;
my $dbpasswd=shift @ARGV;

$dbuser = 'root' unless ($dbuser);
$dbpasswd = '' unless ($dbpasswd);

$db{user} = $dbuser;
$db{password} = $dbpasswd;

die "Usage: add_editpages.pl <db name> <editpages file>\n" unless ($db{db} and $db{file});

##

my $new_editpage = DBIx::Recordset -> SetupObject ({'!DataSource' => "dbi:mysql:$db{db}",
						    '!Username'   => $db{user},
						    '!Password'   => $db{password},
						    '!Table'      => 'editpages',
						    '!Debug'      => $dbi_debug,
						    '!TieRow'     => 0,
						   });

my %namemap = (
	       fields=>'fieldlist',
	       desc=>'description',
	       );

##

my $doctypes = read_doctypes(\%db);

open FH, $db{file} or die "Couldn't read $db{file}\n";
my (%editpage, %options);
my $doctype;
while( <FH> ) {
    next if /^\#/;
    next if /^\s*$/;
    s/^\s*//;

    if( /^DocType: (\w+)/ ) {
	$doctype=$1;
	%options=();
	my @line=split /\s+/;
	shift @line;
	shift @line;
	while( my $opt=shift @line) {
	    my($k, $v)=split /=/, $opt;
	    $v=1 unless $v;
	    $v=~s/_/ /g;
	    $options{$k}=$v;
	}
	die "No such DocType: $doctype" unless $editpage{doctypeid}=$doctypes->{$doctype}->{id};
    }
    elsif( /^(\w+): (.*)/ ) {
	my($key, $value)=(lc($1), $2);

	die "$doctype, $editpage{page}: No End-line for page" if $key eq 'page' and defined $editpage{page};

	if ($options{add_comment_fields} and $key eq 'fields' and !($value =~ /no_comment_field/ )) {
	    my $fieldname=(split /\s+/, $value)[0];
	    $value.="\n" . $fieldname . "_comment Comment;same_line=1";
	}
	$value="\n" . $value if defined $editpage{$key};
	$editpage{$key}.=$value;
    }
    elsif( /^End/ ) {
	add_editpage($new_editpage, \%editpage, $doctype);
	my $doctypeid=$editpage{doctypeid}; # Preserve doctypeid from page to page
	undef %editpage;
	%editpage=(doctypeid=>$doctypeid);
    }
}


exit 0;

##

sub add_editpage {
    my($new_editpage, $editpage, $doctype)=@_;

    print " $doctype ($editpage->{page})\n";

    map {
	if( defined $editpage->{$_} ) {
	    $editpage->{$namemap{$_}}=$editpage->{$_};
	    delete $editpage->{$_};
	}
    } keys %namemap;

    $new_editpage->Insert($editpage);
}

sub read_doctypes {
    my($new)=@_;

    my $doctypes=read_table('doctypes', 'name', $new);
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
