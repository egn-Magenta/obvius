#!/usr/bin/perl

#
# add_doctypes.pl
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

die "Usage: add_doctypes.pl <db name> <doctype file>\n" unless ($db{db} and $db{file});

##

my $new_doctype = DBIx::Recordset -> SetupObject ({'!DataSource' => "dbi:mysql:$db{db}",
						   '!Username'   => $db{user},
						   '!Password'   => $db{password},
						   '!Table'      => 'doctypes',
						   '!Debug'      => $dbi_debug,
						   '!TieRow'     => 0,
						  });

my $new_fieldspec = DBIx::Recordset -> SetupObject ({'!DataSource' => "dbi:mysql:$db{db}",
						     '!Username'   => $db{user},
						     '!Password'   => $db{password},
						     '!Table'      => 'fieldspecs',
						     '!Debug'      => $dbi_debug,
						     '!TieRow'     => 0,
						    });

##

my(%doctype, %options);
open FH, $db{file} or die "Couldn't read $db{file}\n";
while( <FH> ) {
    next if /^\#/;
    next if /^\s*$/;

    my @line=split /\s+/;

    if( lc($line[0]) eq "doctype:" ) {
	shift @line;
	%doctype=();
	%options=();
	$doctype{name}=shift @line;
	while( my $opt=shift @line ) {
	    my($k, $v)=split /=/, $opt;
	    $v=1 unless $v;
	    $v=~s/([^\\])_/$1 /g;
	    $v=~s/\\_/_/g;
	    $doctype{$k}=$v;
	    $options{$k}=$v;
	}
	add_doctype($new_doctype, \%db, \%doctype);
    }
    else {
	shift @line if $line[0]=~/\s*/;
	my %fieldspec = (
			 name=>shift @line,
			 type=>shift @line,
			);
	while( my $opt=shift @line ) {
	    my($k, $v)=split /=/, $opt;
	    $v=1 unless (defined $v); # and $v ne ''); # XXX The empty string is different from undef/NULL, right?
	    $v=~s/([^\\])_/$1 /g;
	    $v=~s/\\_/_/g;
	    $fieldspec{$k}=$v;
	}
	add_fieldspec($new_fieldspec, \%db, \%doctype, \%fieldspec);
	if ($options{add_comment_fields}) {
	    $fieldspec{name}=$fieldspec{name} . '_comment';
	    $fieldspec{type}='text';
	    add_fieldspec($new_fieldspec, \%db, \%doctype, \%fieldspec);
	}
    }
}


exit 0;

##

sub read_table {
    my($table, $key, $db)=@_;

    my $set = DBIx::Recordset -> SetupObject ({'!DataSource' => "dbi:mysql:$db->{db}",
					       '!Username'   => $db->{user},
					       '!Password'   => $db->{password},
					       '!Table'      => $table,
					       '!Debug'      => $dbi_debug,
					       '!TieRow'     => 0,
					      });
    my %entries;
    $set->Search();
    while( my $rec=$set->Next ) {
	my %fields=( %$rec );
	$entries{$rec->{$key}}=\%fields;
    }
    $set->Disconnect;

    return \%entries;
}

##

sub add_doctype {
    my($new_doctype, $db, $doctype)=@_;

    print "$doctype->{name}";
    print " ($doctype->{parent})" if $doctype->{parent};
    print "\n";

    my $doctypes=read_table('doctypes', 'name', $db);

    if( $doctype->{parent} ) {
	$doctype->{parent}=$doctypes->{$doctype->{parent}}->{id};
    }
    else {
	$doctype->{parent}=0; # If no parent is given, use 0
    }

    $new_doctype->Insert($doctype);
}

##

sub add_fieldspec {
    my($new_fieldspec, $db, $doctype, $fieldspec)=@_;

    #print " $fieldspec->{name}\n";

    my $doctypes=read_table('doctypes', 'name', $db);
    $fieldspec->{doctypeid}=$doctypes->{$doctype->{name}}->{id};

    my $type=$fieldspec->{type};
    my $fieldtypes=read_table('fieldtypes', 'name', \%db);
    $fieldspec->{type}=$fieldtypes->{$fieldspec->{type}}->{id};
    print STDERR "Waah, no such fieldtype $type for $fieldspec->{name}\n" unless $fieldspec->{type};

    # Check if there's any existing entries with the same name and different type
    # (the database should be normalized instead!)
    $new_fieldspec->Search({name=>$fieldspec->{name}});
    while (my $rec=$new_fieldspec->Next)
    {
	if ($rec->{type} != $fieldspec->{type}) {
	    print STDERR " !!! Yikes, conflicting types for \"$fieldspec->{name}\" in doctypes no. $rec->{doctypeid} and $fieldspec->{doctypeid} - fix it!\n";
	}
    }

    $new_fieldspec->Insert($fieldspec);
}
