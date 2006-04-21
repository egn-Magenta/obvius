#!/usr/bin/perl

#
# add_fieldtypes.pl
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

die "Usage: add_fieldtypes.pl <db name> <fieldtype file>\n" unless ($db{db} and $db{file});

##

my $new_fieldtype = DBIx::Recordset -> SetupObject ({'!DataSource' => "dbi:$db{db}",
						   '!Username'   => $db{user},
						   '!Password'   => $db{password},
						   '!Table'      => 'fieldtypes',
						   '!Debug'      => $dbi_debug,
						   '!TieRow'     => 0,
						  });
##

open FH, $db{file} or die "Couldn't read $db{file}\n";
while( <FH> ) {
    next if /^\#/;
    next if /^\s*$/;

    my %fieldtype;
    my $j=0;
    my @line = map { tr/_/ / if $j; $j++; $_ } split /\s+/;

    my $i=0;
    $fieldtype{name}=$line[$i++];
    if (substr($fieldtype{name}, -3) eq '[B]') {
	$fieldtype{bin} = 1;
	$fieldtype{name}=substr($fieldtype{name}, 0, -3);
    }
    #print "name: $fieldtype{name}\n";
    $fieldtype{value_field} = $line[$i++];
    #print "value_field: $fieldtype{name}\n";
    $fieldtype{edit}=$line[$i++];
    #print "edit: $fieldtype{edit}\n";
    if (substr($line[$i], 0, 1) eq '(') {
	$fieldtype{edit_args}=substr($line[$i++], 1, -1);
	#print "edit_args: $fieldtype{edit_args}\n";
    }
    $fieldtype{validate}=$line[$i++];
    #print "validate: $fieldtype{validate}\n";
    if ($line[$i] and substr($line[$i], 0, 1) eq '(') {
	$fieldtype{validate_args}=substr($line[$i++], 1, -1);
	#print "validate_args: $fieldtype{validate_args}\n";
    }
   	$fieldtype{search}=$line[$i++];
   	#print "search: $fieldtype{search}\n";
   	if ($line[$i] and substr($line[$i], 0, 1) eq '(') {
	$fieldtype{search_args}=substr($line[$i++], 1, -1);
	#print "search_args: $fieldtype{search_args}\n";
   	}
    #print "\n";

    add_fieldtype($new_fieldtype, \%fieldtype);
}


exit 0;

##

sub add_fieldtype {
    my($new_fieldtype, $fieldtype)=@_;

    print " $fieldtype->{name}\n";

    $new_fieldtype->Insert($fieldtype);
}
