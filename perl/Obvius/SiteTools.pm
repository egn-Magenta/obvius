package Obvius::SiteTools;

use strict;
use warnings;

use Obvius::Config;
use Carp;
use Data::Dumper;
use DBI;
use DateTime::Format::Strptime;

my $date_parser = DateTime::Format::Strptime->new(pattern => '%Y-%m-%d %H:%M:%S');
my $date_format = DateTime::Format::Strptime->new(pattern => '%d-%m-%Y');

sub update_doctypes {
    my($confname) = @_;

    my $config = Obvius::Config->new($confname);
    die "Couldn't load Obvius::Config for $confname" unless($config);

    my $sitebase = $config->param('sitebase');
    die "No sitebase defined for config '$confname'" unless($sitebase);
    $sitebase =~ s!/$!!;
    my $db_dir = $sitebase . '/db';
    my $fieldtypes_txt = $db_dir . '/fieldtypes.txt';
    die "$fieldtypes_txt doesn't exist" unless(-f $fieldtypes_txt);

    my $doctypes_txt = $db_dir . '/doctypes.txt';
    die "$doctypes_txt doesn't exist" unless(-f $doctypes_txt);

    my $editpages_txt = $db_dir . '/editpages.txt';
    die "$editpages_txt doesn't exist" unless(-f $editpages_txt);

    my $dbh = DBI->connect(
	$config->param('dsn'),
	$config->param('normal_db_login'),
	$config->param('normal_db_passwd'),
	{
	    RaiseError => 1
	}
    );

    $dbh->begin_work;
    eval {
	my $fieldtypemap = add_fieldtypes($fieldtypes_txt, $dbh);
	my ($doctypemap, $fieldspecmap) = add_doctypes(
	    $doctypes_txt, $dbh, $fieldtypemap
	);
	add_editpages($editpages_txt, $dbh, $doctypemap, $fieldspecmap);
    };
    if ( $@ ) {
	print STDERR "\n\nERROR:\n$@\n";
	$dbh->rollback;
	exit 1;
    } else {
	print "Do you want to commit these changes (y/N)? ";
	my $resp = <STDIN>;
	if($resp =~ m!^y!) {
	    $dbh->commit;
	    print "Doctype data updated successfully\n";
            print "\n";
	} else {
	    $dbh->rollback;
	    print "Changes rolled back\n";
	}
    }
    1;
}

sub add_fieldtypes {
    my($filename, $dbh) = @_;

    my %fieldtypemap;
    my $sth = $dbh->prepare('select * from fieldtypes');
    $sth->execute;
    while(my $rec = $sth->fetchrow_hashref) {
        $fieldtypemap{$rec->{name}} = $rec;
        $fieldtypemap{$rec->{id}} = $rec;
    }

    my @fields = qw(
        name
        edit
        edit_args
        validate
        validate_args
        search
        search_args
        bin
        value_field
    );

    my %defaults = (
	search_args => '',
	bin => 0,
	edit_args => '',
	validate_args => ''
    );

    my $updater = $dbh->prepare(
        'update fieldtypes set ' .
        join(", ", map { "${_} = ?" } @fields) .
        ' where id = ?'
    );

    my $inserter = $dbh->prepare(
        'insert into fieldtypes (' .
        join(", ", @fields) .
        ') values (' .
        join(", ", map { "?" } @fields) .
        ')'
    );

    open FH, $filename or die "Couldn't read $filename\n";
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
	$fieldtype{value_field} = $line[$i++];
	$fieldtype{edit}=$line[$i++];
	if (substr($line[$i], 0, 1) eq '(') {
	    $fieldtype{edit_args}=substr($line[$i++], 1, -1);
	}
	$fieldtype{validate}=$line[$i++];
	if ($line[$i] and substr($line[$i], 0, 1) eq '(') {
	    $fieldtype{validate_args}=substr($line[$i++], 1, -1);
	}
   	$fieldtype{search}=$line[$i++];
   	if ($line[$i] and substr($line[$i], 0, 1) eq '(') {
	    $fieldtype{search_args}=substr($line[$i++], 1, -1);
   	}

        if(my $existing = $fieldtypemap{ $fieldtype{name} }) {
            die "Multiple specifications for field $fieldtype{name}"
                if($existing->{_seen});
	    $existing->{_seen} = 1;

	    my %data = map {
		$_ => ($fieldtype{$_} || $defaults{$_})
	    } @fields;
	    my $changed = hash_diff($existing, \%data, \@fields);
	    if($changed) {
		print "Updating fieldtype $data{name}: $changed\n";
		$updater->execute(
		    (map { $data{$_} } @fields),
		    $existing->{id}
		);
	    }
        } else {
            $inserter->execute(
                map { $fieldtype{$_} || $defaults{$_} } @fields,
            );
	    $fieldtype{id} = $inserter->{mysql_insertid};
	    print "Inserting fieldtype $fieldtype{name}: $fieldtype{id}\n";
	    $fieldtype{_seen} = 1;
	    $fieldtypemap{$fieldtype{id}} = \%fieldtype;
	    $fieldtypemap{$fieldtype{name}} = \%fieldtype;
        }
    }

    # Delete any fieldtypes that was not processed above
    my @unseen = grep { !$_->{_seen} } values %fieldtypemap;
    foreach my $ftype (@unseen) {
	warn "Fieldtype '" . $ftype->{name} . "' not seen in $filename\n";
	delete $fieldtypemap{ $ftype->{id} };
	delete $fieldtypemap{ $ftype->{name} };
    }

    return \%fieldtypemap;
}

sub add_doctypes {
    my($filename, $dbh, $fieldtypemap) = @_;

    my %doctypemap;
    my $sth = $dbh->prepare('select * from doctypes');
    $sth->execute;
    while(my $rec = $sth->fetchrow_hashref) {
        $doctypemap{$rec->{name}} = $rec;
        $doctypemap{$rec->{id}} = $rec;
    }
    $sth->finish;

    my @dt_fieldnames = qw(
        name
        parent
        basis
        searchable
        sortorder_field_is
    );

    my %dt_defaults = (
        basis => 0,
        searchable => 1,
        parent => 0,
	threshold => 0,
    );

    my $inserter = $dbh->prepare(
        'insert into doctypes (' .
        join(",", @dt_fieldnames) .
        ') values (' .
        join(",", map {"?"} @dt_fieldnames) .
        ')'
    );

    my $updater = $dbh->prepare(
	'update doctypes set ' .
	join(",", map { "$_ = ?" } @dt_fieldnames) .
	' where id = ?'
    );

    my $dt_deleter = $dbh->prepare(
	'delete from doctypes where id = ?'
    );
    my @fieldspecs;

    open(FH, $filename) or die "Couldn't open $filename";
    my %doctype;
    while(my $line = <FH>) {
        chomp($line);
	next if $line =~ /^\#/;
	next if $line =~ /^\s*$/;

        if($line =~ m!^doctype:\s+(\S+)\s*(.*)!i) {
            %doctype = (name => $1);
            for my $opt (split(/\s+/, $2)) {
                if($opt =~ m!^([^=]+)\s*=\s*(.*)!) {
                    $doctype{$1} = $2;
                } else {
                    $doctype{$opt} = 1
                }
            }
	    if($doctype{parent}) {
		my $parent = $doctypemap{$doctype{parent}};
		die "Parent $doctype{parent} not found for doctype $doctype{name}"
		    unless($parent);
		$doctype{parent} = $parent->{id};
	    } else {
		$doctype{parent} = 0;
	    }

	    my %data = map {
		$_ => ($doctype{$_} || $dt_defaults{$_})
	    } @dt_fieldnames;

	    my @args = map {
		$data{$_}
	    } @dt_fieldnames;

	    if(my $existing = $doctypemap{ $doctype{name} }) {
		die "Duplicate doctype with name '$doctype{name}'"
		    if($existing->{_seen});
		$existing->{_seen} = 1;
		
		if(my $c = hash_diff($existing, \%data, \@dt_fieldnames)) {
		    print "Updating doctype '$doctype{name}': $c\n";
		    $updater->execute(@args,$existing->{id});
		}
		$doctype{id} = $existing->{id};
	    } else {
		$inserter->execute(@args);
		$doctype{id} = $inserter->{mysql_insertid};
		print "Inserting doctype '$doctype{name}': $doctype{id}\n";
		$doctype{_seen} = 1;
		my %new_dt = %doctype;
		$doctypemap{$doctype{id}} = \%new_dt;
		$doctypemap{$doctype{name}} = \%new_dt;
	    }
        } else {
            my @parts = split(/[\s]+/, $line);
            shift(@parts) unless($parts[0] && $parts[0] =~ m!\S+!);
            my %fieldspec = (doctypeid => $doctype{id});
            $fieldspec{name} = shift(@parts);
            $fieldspec{type} = shift(@parts);
	    while(my $opt=shift @parts) {
		my($k, $v)=split /=/, $opt;
		$v=1 unless (defined $v);# and $v ne '');
                # XXX The empty string is different from undef/NULL, right?
		$v=~s/([^\\])_/$1 /g;
		$v=~s/\\_/_/g;
		$fieldspec{$k}=$v;
	    }

            my $ftype = $fieldtypemap->{ $fieldspec{type} };
            die "No such fieldtype '$fieldspec{name}'" unless($ftype);

	    $fieldspec{type} = $ftype->{id};
	    push(@fieldspecs, \%fieldspec);
        }
    }

    my %warned;
    my @unseen = grep {
	!$_->{_seen} &&
	!$warned{$_->{id}}++
    } values %doctypemap;
    foreach my $doctype (@unseen) {
	warn "Doctype '" . $doctype->{name} . "' from database is not " .
	"in $filename\n";
	delete $doctypemap{ $doctype->{id} };
	delete $doctypemap{ $doctype->{name} };
    }
    
    my $fieldspecmap = add_fieldspecs(
	$dbh, \@fieldspecs, $fieldtypemap, \%doctypemap
    );

    return (\%doctypemap, $fieldspecmap)
}


sub add_fieldspecs {
    my ($dbh, $fspeclist, $fieldtypemap, $doctypemap) = @_;

    my %fieldspecmap;
    my $sth = $dbh->prepare('select * from fieldspecs');
    $sth->execute;
    while(my $rec = $sth->fetchrow_hashref) {
	my $k = $rec->{doctypeid} . ":" . $rec->{name};
	$fieldspecmap{$k} = $rec;
    }
    $sth->finish;

    my @fs_fieldnames = qw(
        doctypeid
        name
        type
        repeatable
        optional
        searchable
        sortable
        publish
        threshold
        default_value
        extra
    );

    my %defaults = (
	repeatable => 0,
	optional => 0,
	publish => 0,
	threshold => 128,
	searchable => 0,
	sortable => 0
    );

    my $fspec_inserter = $dbh->prepare(
        'insert into fieldspecs (' .
	join(", ", @fs_fieldnames) .
        ') values (' .
	join(", ", map { "?" } @fs_fieldnames) .
        ')'
    );

    my $fspec_updater = $dbh->prepare(
	'update fieldspecs set ' .
	join(", ", map { "$_ = ?" } @fs_fieldnames) .
	' where doctypeid = ? and name = ?'
    );

    my $fspec_deleter = $dbh->prepare(
	'delete from fieldspecs where doctypeid = ? and name = ?'
    );

    my %fieldspec_type_map;

    foreach my $fieldspec (@$fspeclist) {
	my $doctype = $doctypemap->{ $fieldspec->{doctypeid} };
	die "No doctype with id " . $fieldspec->{doctypeid} unless($doctype);

	my $fspecname = $doctype->{name} . ":" . $fieldspec->{name};

	# Check for existing registered type
	if(my $existing = $fieldspec_type_map{$fieldspec->{name}}) {
	    if($fieldspec->{type} != $existing->{type}) {
		my $edoctype = $doctypemap->{ $existing->{doctypeid} };
		my $typename = $fieldtypemap->{ $fieldspec->{type} };
		my $etypename = $fieldtypemap->{ $existing->{type} };
		die sprintf(
		    "Type '%s' for fieldspec '%s' does not match " .
		    "existing type '%s' registered for '%s'.",
		    $typename, $fspecname, $etypename,
		    $edoctype->{name} . ":" . $existing->{name}
		);
	    }
	} else {
	    $fieldspec_type_map{$fieldspec->{type}} = $fieldspec;
	}

	# Add or update fieldspec
	my $k = $doctype->{id} . ":" . $fieldspec->{name};
	my %data = map {
	    $_ => (defined $fieldspec->{$_} ? $fieldspec->{$_} : $defaults{$_})
	} @fs_fieldnames;
	my @args = map { $data{$_} } @fs_fieldnames;
	if(my $existing = $fieldspecmap{$k}) {
	    if(my $c = hash_diff($existing, \%data, \@fs_fieldnames)) {
		print "Updating fieldspec '$fspecname': $c\n";
		$fspec_updater->execute(
		    @args,
		    $existing->{doctypeid},
		    $existing->{name}
		);
	    }
	} else {
	    print "Inserting fieldspec $fspecname\n";
	    $fspec_inserter->execute(@args);
	}
	$fieldspec->{_seen} = 1;
	$fieldspecmap{$k} = $fieldspec;
    }

    # Delete unhandled fieldspecs
    foreach my $key (keys %fieldspecmap) {
	my $fspec = $fieldspecmap{$key};
	unless($fspec->{_seen}) {
	    my $doctype = $doctypemap->{$fspec->{doctypeid}} || {};
	    my $doctypename = $doctype->{name} || $fspec->{doctypeid};
	    print "Deleting fieldspec " .
		  $doctypename . ":" . $fspec->{name} . "\n";
	    $fspec_deleter->execute(
		$fspec->{doctypeid},
		$fspec->{name}
	    );
	    delete $fieldspecmap{$key};
	}
    }

    return \%fieldspecmap;
}

sub add_editpages {
    my($filename, $dbh, $doctypemap, $fieldspecmap) = @_;

    my %editpagemap;
    my $sth = $dbh->prepare('select * from editpages');
    $sth->execute;
    while(my $rec = $sth->fetchrow_hashref) {
	my $key = $rec->{doctypeid} . ":" . $rec->{page};
	$editpagemap{$key} = $rec;
    }
    $sth->finish;

    my %fieldnamemap = ( desc => "description", fields => "fieldlist" );

    my @fields = qw(
	doctypeid
	page
	title
	description
	fieldlist
    );

    my %defaults = (
	description => '',
	fieldlist => ''
    );

    my $inserter = $dbh->prepare(
	'insert into editpages (' .
	join(",", @fields) .
	') values (' .
	join(",", map { "?" } @fields) .
	')'
    );

    my $updater = $dbh->prepare(
	'update editpages set ' .
	join(",", map { "$_ = ?" } @fields) .
	' where doctypeid = ? and page = ?'
    );

    my $deleter = $dbh->prepare(
	'delete from editpages where doctypeid = ? and page = ?'
    );

    open(FH, $filename) or die "Couldn't read $filename\n";
    my (%editpage, $doctypename);
    while( <FH> ) {
	next if /^\#/;
	next if /^\s*$/;
	s/^\s*//;


	if( /^DocType: (\w+)/ ) {
	    $doctypename = $1;
	    my $doctype = $doctypemap->{$doctypename};
	    die "Doctype mismatch $doctype->{name} <=> $doctypename" if($doctype->{name} ne $doctypename);
	    die "No such DocType: $doctypename" unless($doctype);
	    $editpage{doctypeid} = $doctype->{id};
	}
	elsif( /^(\w+): (.*)/ ) {
	    my($key, $value)=(lc($1), $2);

	    # translate key using fieldnamemap
	    $key = $fieldnamemap{$key} || $key;

	    die "$doctypename, $editpage{page}: No End-line for page (syntax check editpages.txt)"
		if $key eq 'page' and defined $editpage{page};

	    if ($key eq 'fields') {
		my $fieldname=(split /\s+/, $value)[0];

		if (!$fieldspecmap->{"$editpage{doctypeid}:$fieldname"}) {
		    die "Doctype $doctypename, Editpage $editpage{page}: " .
		        "field '$fieldname' does not exist on " .
			"'$doctypename'";
		}
	    }
	    $value="\n" . $value if defined $editpage{$key};
	    $editpage{$key}.=$value;
	}
	elsif( /^End/ ) {
	    my %data;
	    # Check for copy
	    if(my $copypage = $editpage{copy}) {
		my (
		    $source_dtname,
		    $source_page
		) = split(/\s*[\(\)]\s*/, $copypage);
		my $source_doctype = $doctypemap->{$source_dtname};
		die "Can not copy from non-existing doctype '$source_dtname'"
		    unless($source_doctype);
		my $key = $source_doctype->{id} . ":" . $source_page;
		my $copy_source = $editpagemap{$key};
		die "Can not find source for copy page '$copypage'"
		    unless($copy_source and $copy_source->{_seen});
		%data = (
		    %$copy_source,
		    doctypeid => $editpage{doctypeid},
		    page => $editpage{page}
		);
	    } else {
		%data = %editpage;
	    }

	    my $key = $editpage{doctypeid} . ":" . $editpage{page};
	    foreach my $f (@fields) {
		$data{$f} ||= $defaults{$f};
	    }
	    my @args = map { $data{$_} } @fields;
	    if(my $existing = $editpagemap{$key}) {
		die "Dublicate editpage $doctypename:$editpage{page}"
		    if($existing->{_seen});
		my $changed = hash_diff($existing, \%data, \@fields);
		if($changed) {
		    print "Updating editpage $doctypename:$editpage{page}: " .
			  "$changed\n";
		    $updater->execute(
			@args,
			$existing->{doctypeid},
			$existing->{page}
		    );
		}
		$editpagemap{$key} = \%data;
	    } else {
		print "Inserting editpage $doctypename:$editpage{page}\n";
		$inserter->execute(@args);
	    }
	    $data{_seen} = 1;
	    $editpagemap{$key} = \%data;

	    my $doctypeid=$editpage{doctypeid}; # Preserve doctypeid from page to page
	    %editpage=(doctypeid=>$doctypeid);
	}
    }

        # Delete unhandled fieldspecs
    foreach my $key (keys %editpagemap) {
	my $page = $editpagemap{$key};
	unless($page->{_seen}) {
	    my $doctype = $doctypemap->{$page->{doctypeid}} || {};
	    my $doctypename = $doctype->{name} || $page->{doctypeid};
	    print "Deleting editpage " .
		  $doctypename . ":" . $page->{page} . "\n";
	    $deleter->execute(
		$page->{doctypeid},
		$page->{page}
	    );
	    delete $editpagemap{$key};
	}
    }

}

sub hash_diff {
    my ($h1, $h2, $fieldlist) = @_;

    my @changed;
    foreach my $key (@$fieldlist) {
	my $v1 = $h1->{$key};
	my $v2 = $h2->{$key};
	if(defined($v1)) {
	    push(@changed, $key) unless(defined($v2) && ($v1 eq $v2));
	} else {
	    push(@changed, $key) if(defined($v2));
	}
    }

    if(@changed) {
	my %data = map {
	    $_ => {
		(defined ($h1->{$_}) ? $h1->{$_} : '<undef>') =>
		$h2->{$_}
	    }
	} @changed;
	$data{fieldlist} = "<changed>" if($data{fieldlist});
	return Data::Dumper->new(
	    [\%data],
	    ['changed']
	)->Terse(1)->Indent(0)->Useqq(1)->Dump;
    }

    return undef;
}

sub convert_datetime_to_ddmmyyyy {
    my ($datetime) = @_;
    my $date = $date_parser->parse_datetime($datetime);
    return $date_format->format_datetime($date);
}

1;

__END__

=head1 NAME

SiteTools - Perl packaging of miscellaneous Obvius routines.

=head1 SYNOPSIS

use Obvius::SiteTools;

Obvius::SiteTools::CycleDocTypes($db, $user, $passwd, $logfile, 
                                 $doctypes_file, $fieldtypes_file, $editpages_file)

=head1 DESCRIPTION
    
Obvius::SiteTools::CycleDocTypes: Performs the cycling of doctypes
    
=head2 EXPORT

None by default.

=head1 AUTHOR

Lars Eskildsen <lt>lars@magenta-aps.kd<gt>

Jørgen Ulrik B. Krag <lt>jubk@magenta-aps.dk<gt>

=head1 SEE ALSO

=cut
