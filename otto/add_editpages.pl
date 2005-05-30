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

        if ($key eq 'fields') {
            my $fieldname=(split /\s+/, $value)[0];

            if (!exists $doctypes->{$doctype}->{fields}->{$fieldname}) {
                die "Doctype $doctype, Editpage $editpage{page}: field '$fieldname' does not exist on '$doctype', stopping add_editpages.pl";
            }

            if ($options{add_comment_fields} and !($value =~ /no_comment_field/ )) {
                $value.="\n" . $fieldname . "_comment Comment;same_line=1";
            }
        }
        $value="\n" . $value if defined $editpage{$key};
        $editpage{$key}.=$value;

    }
    elsif( /^End/ ) {
        # Check for copy
        if(my $copypage = $editpage{copy}) {
            copy_editpage($copypage, $editpage{doctypeid}, $editpage{page});
            my $doctypeid=$editpage{doctypeid}; # Preserve doctypeid from page to page
            undef %editpage;
            %editpage=(doctypeid=>$doctypeid);
        } else {
            add_editpage($new_editpage, \%editpage, $doctype);
            my $doctypeid=$editpage{doctypeid}; # Preserve doctypeid from page to page
            undef %editpage;
            %editpage=(doctypeid=>$doctypeid);
        }
    }
}


exit 0;

##

sub copy_editpage {
    my ($copypage, $doctypeid, $pagenr) = @_;

    die "No copypage in copy_editpage" unless($copypage);
    die "No doctypeid in copy_editpage" unless($doctypeid);
    die "No pagenr in copy_editpage" unless($pagenr);

    my ($source_doctype, $source_page) = split(/\s*[\(\)]\s*/, $copypage);

    my $sourceid = $doctypes->{$source_doctype}->{id};

    die "DocType $source_doctype have no id" unless($sourceid);

    $new_editpage->Search( { doctypeid => $sourceid, page => $source_page } );
    if(my $rec = $new_editpage->Next) {
        $rec->{doctypeid} = $doctypeid;
        $rec->{page} = $pagenr;

        print " $doctype ($rec->{page}) - Copy of $source_doctype ($source_page)\n";

        $new_editpage->Insert($rec);
    } else {
        die "Couldn't find the page you wanted to copy: $copypage\n";
    }
}

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

    my $doctypes=read_table('doctypes', 'name', $new, {});

    # Get fieldspecs too:

    foreach my $doctypename (keys %$doctypes) {
        $doctypes->{$doctypename}->{fields}=read_fields($doctypename, $doctypes, $new);
    }

    return $doctypes;
}

sub read_fields {
    my ($doctypename, $doctypes, $db)=@_;

    # Find pearl of parents:
    my @parentids=get_parentids($doctypename, $doctypes);

    my $fields=read_table('fieldspecs', 'name', $db, 'doctypeid IN (' . (join ', ', (@parentids, $doctypes->{$doctypename}->{id})) . ')' );

    return $fields;
}


sub get_parentids {
    my ($parentdoctypename, $doctypes)=@_;

    my @ids;

    while ($parentdoctypename) {
        my $parent=$doctypes->{$parentdoctypename}->{parent};
        push @ids, $parent if ($parent);

        ($parentdoctypename)=grep { $doctypes->{$_}->{id} eq $parent } keys %$doctypes;
    }

    return @ids;
}

sub read_table {
    my($table, $key, $db, $searchoptions)=@_;

    my $set = DBIx::Recordset -> SetupObject ({'!DataSource' => "dbi:mysql:$db->{db}",
					       '!Username'   => $db->{user},
					       '!Password'   => $db->{password},
					       '!Table'      => $table,
                                               '!TieRow'     => 0,
					       '!Debug'      => $dbi_debug,
					      });
    my %entries;
    $set->Search($searchoptions);
    while( my $rec=$set->Next ) {
	my %fields=( %$rec );
	$entries{$rec->{$key}}=\%fields;
    }

    return \%entries;
}
