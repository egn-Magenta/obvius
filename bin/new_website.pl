#!/usr/bin/perl

# new_website.pl - create the necessary directories, permissions and
#                  stuff for a new Obvius website.
#
# TODO: * Perhaps move symlinks to the skeleton directory instead?
#       * When stuff exists, check permissions anyway.
#
# Copyright (C) 2002-2003, by Adam Sjøgren. Under the GPL.
#
# $Id$

use strict;
use warnings;

use Getopt::Long;

# Set env for scripts 
$ENV{'PERL5LIB'} = $ENV{'PERL5LIB'} . ":/home/httpd/obvius/perl_blib";

my %options=(
    website=>undef,
    dbname=>undef,
    dbuser=>'root',
    dbpasswd=>'',
    perlname=>undef,
    domain=>undef,
    wwwroot=>'/var/www',
    httpd_group=>'www-data',
    staff_group=>'staff',
    skeleton_dir=>'/var/www/obvius/skeleton',
   );
# Remember to update sub usage below, when updating options.

GetOptions(
	   'website=s'    =>\$options{website},
	   'dbname=s'     =>\$options{dbname},
	   'dbuser=s'     =>\$options{dbuser},
	   'dbpasswd=s'   =>\$options{dbpasswd},
	   'perlname=s'   =>\$options{perlname},
	   'domain=s'     =>\$options{domain},
	   'wwwroot=s'    =>\$options{wwwroot},
	   'httpd_group=s'=>\$options{httpd_group},
	   'staff_group=s'=>\$options{staff_group},
	   'skeleton_dir=s'=>\$options{skeleton_dir},
	  ) or usage("Couldn't understand options, stopping");

usage("Please supply website and dbname, stopping") unless ($options{website} and $options{dbname});
$options{perlname}=ucfirst($options{dbname}) unless ($options{perlname});
($options{domain})=($options{website}=~/^[^.]*[.](.*)$/) unless ($options{domain});

my @dirs=(
	  { dir=>'backup', },
	  { dir=>'bin', },
	  { dir=>'conf', },
	  { dir=>'db', },
	  { dir=>'docs', },
	  { dir=>'docs/grafik', },
	  { dir=>'docs/grafik/pager', },
	  { dir=>'docs/css', },
	  { dir=>'htdig', },
	  { dir=>'htdig/db', group=>$options{httpd_group}, },
	  { dir=>'htdig/common', group=>$options{httpd_group}, },
	  { dir=>'htdig/log', group=>$options{httpd_group}, },
	  { dir=>'logs', group=>$options{httpd_group}, },
	  { dir=>'mason', },
	  { dir=>'mason/admin', },
	  { dir=>'mason/common', },
	  { dir=>'mason/public', },
	  { dir=>'mason/mail', },
	  { dir=>'stats', group=>$options{httpd_group}, },
	  { dir=>'var', group=>$options{httpd_group}, },
	  { dir=>'var/document_cache', group=>$options{httpd_group}, },
	  { dir=>'var/edit_sessions', group=>$options{httpd_group}, },
	  { dir=>'var/edit_sessions/LOCKS', group=>$options{httpd_group}, },
	  { dir=>'var/user_sessions', group=>$options{httpd_group}, },
	  { dir=>'var/user_sessions/LOCKS', group=>$options{httpd_group}, },
	 );

my @files=(
	   { dir=>'var', file=>'document_cache.txt', perms=>'0664', group=>$options{httpd_group} },
	  );

my @symlinks=(
	      { dir=>'docs', link=>'cache', to=>'var/document_cache', },
	      { dir=>'docs', link=>'stats', to=>'stats', },
	      { dir=>'docs', link=>'admin_js', to=>"$options{wwwroot}/obvius/docs/js", },
	      { dir=>'docs/grafik', link=>'admin', to=>"$options{wwwroot}/obvius/docs/grafik/admin", },
	      { dir=>'docs/grafik', link=>'navigator', to=>"$options{wwwroot}/obvius/docs/grafik/admin/navigator", },
	     );

my @db_files=qw(structure.sql perms.sql);

# Fix directories:
print "Directories ...\n";
die "wwwroot ($options{wwwroot}) doesn't exists, stopping" unless (-d $options{wwwroot});
make_dir("$options{wwwroot}/$options{website}", $options{staff_group});

foreach my $dir (@dirs) {
    my $absdir="$options{wwwroot}/$options{website}/$dir->{dir}";
    my $group=$dir->{group} || $options{staff_group};
    make_dir($absdir, $group);
}

# Fix files
print "Files ...\n";
foreach my $file (@files) {
    my $dest="$options{wwwroot}/$options{website}/$file->{dir}/$file->{file}";
    if (-e $dest) {
	print " File $file->{dir}/$file->{file} already exists\n";
    }
    else {
	system "(cd $options{wwwroot}/$options{website}/$file->{dir}; touch $file->{file}; chmod $file->{perms} $file->{file}; sudo chgrp $file->{group} $file->{file})";
    }
}

# Fix symlinks:
print "Symlinks ...\n";
foreach my $symlink (@symlinks) {
    make_symlink($symlink->{to}, $symlink->{dir}, $symlink->{link});
}

# Copy from the skeleton-dir, interpolating:
print "Skeleton files ...\n";
my @skeleton_files=map { s|^[.]/||; $_; } split /\n/, `(cd $options{skeleton_dir}; find ./ -type f)`;
foreach my $skeleton_file (@skeleton_files) {
    next if ($skeleton_file =~ /CVS/);
    copy_interpolate($options{skeleton_dir}, $skeleton_file, "$options{wwwroot}/$options{website}");
}

# Create Obvius dir:
unless (-d "/etc/obvius/") {
    print "creating /etc/obvius/ ...\n";
    make_dir("/etc/obvius/", $options{staff_group});
}

# Create Obvius conf-file:
print "Configuration and database ...\n";

make_conf("/etc/obvius/$options{dbname}.conf");

# Create database:
make_db($options{dbname});

print "Do you want to import some basic documents (Y/n)? ";
my $test = <STDIN>;
unless($test and $test =~ /^n/i) {
    system("cat $options{wwwroot}/obvius/otto/basic_structures.sql | mysql $options{dbname} -u $options{dbuser} --password=$options{dbpasswd}")
}

exit 0;

# copy_interpolate - read the skeleton_dir/skeleton_file and copy it
#                    to $dest/$skeleton_file while interpolating any
#                    variables found.
sub copy_interpolate {
    my ($skeleton_dir, $skeleton_file, $dest_dir)=@_;

    my $from="$skeleton_dir/$skeleton_file";
    my $dest="$dest_dir/$skeleton_file";
    if (-e $dest) {
	print " $dest already exists\n";
    }
    else {
	my $infh;
	open $infh, $from or die "Couldn't read $from, stopping";
	my @slurp=<$infh>;
	close $infh;

	my @out=map { 
	    foreach my $k (keys %options) {
		s/[\$][\{]$k[\}]/$options{$k}/ge;
	    }
	    $_;
	} @slurp;

	my $outfh;
	open $outfh, ">$dest" or die "Couldn't write $dest, stopping";
	print $outfh @out;
	close $outfh;
    }
}

# make_symlink - if the symlink doesn't exist, make it.
sub make_symlink {
    my ($to, $dir, $link)=@_;

    if (-e "$options{wwwroot}/$options{website}/$dir/$link") {
	print " Symlink $dir/$link already exists\n";
    }
    else {
	$to="../$to" unless ($to=~m!^/!);
	system "(cd $options{wwwroot}/$options{website}/$dir; ln -s $to $link)";
    }
}

# make_dir - if the directory doesn't exists, make it. Doesn't go
#           path-creation. Change group and make writeable to group.
sub make_dir {
    my ($dir, $group)=@_;

    if (-d $dir)  {
	print " $dir already exists\n";
    }
    else {
	mkdir $dir or warn "Couldn't make directory $dir";
    }
    system "sudo chgrp $group $dir";
    system "sudo chmod g+w $dir";
}

# make_conf - create a default Obvius configuration file if it doesn't exist
sub make_conf {
    my ($file)=@_;

    if (-e $file) {
	print " Configuration file $file already exists\n";
    }
    else {
	my $fh;
	open $fh, ">$file" or die "Couldn't write $file, stopping";
	print $fh <<EOT;
DSN = DBI:mysql:$options{dbname}

normal_db_login=$options{dbname}_normal
normal_db_passwd=default_normal

privileged_db_login= $options{dbname}_priv
privileged_db_passwd=default_priv

administrator = admin

htdig_config = $options{domain}
htdig_title = $options{domain} - 

debug = 0
benchmark = 1

sitename=$options{website}
perlname=$options{perlname}
EOT
    }
}

sub make_db {
    my ($dbname)=@_;

    if (db_exists($dbname)) {
	print " The database $dbname already exists\n";
    }
    else {
	system "mysqladmin create $dbname -u $options{dbuser} --password=$options{dbpasswd}";
	system "cat $options{wwwroot}/$options{website}/db/structure.sql | mysql $dbname -u $options{dbuser} --password=$options{dbpasswd}";
	system "cat $options{wwwroot}/$options{website}/db/perms.sql | mysql $dbname -u $options{dbuser} --password=$options{dbpasswd}";
	# Put doctypes, editpages, fieldspecs and fieldtypes in the database:
	system "(cd $options{wwwroot}/$options{website}/db; sh ./cycle_doctypes_etc.sh $options{dbuser} $options{dbpasswd})";
	# Make root document:
	system "$options{wwwroot}/obvius/otto/create_root ${dbname} Forside";
    }
}

sub db_exists {
    my ($dbname)=@_;

    my $command = "mysql $dbname -u $options{dbuser} --password=$options{dbpasswd} -e 'show tables;' 2> /dev/null";
    
    my $o=`$command`;
    if ($o eq "") {
	return 0;
    }
    else {
	return 1;
    }
}

sub usage {
    print <<EOT;

Usage: new_website.pl --website <website> --dbname <dbname>

Further options:
                        default:

 --perlname <perlname>  <Dbname>
 --domain <domain>      <website> after the first dot to the end
 --wwwroot <wwwroot>    /var/www
 --httpd_group <group>  www-data
 --staff_group <group>  staff
 --skeleton_dir <dir>   /var/www/obvius/skeleton
EOT
    exit(1);
}
