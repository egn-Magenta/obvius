#!/usr/bin/perl

# new_website.pl - create the necessary directories, permissions and
#                  stuff for a new Obvius website.
#
# TODO: * Perhaps move symlinks to the skeleton directory instead?
#       * When stuff exists, check permissions anyway.
#
# Copyright (C) 2002-2005 aparte A/S, Magenta ApS. By Jørgen Ulrik
#                         B. Krag, Adam Sjøgren. Under the GPL.
#
# $Id$

use strict;
use warnings;

use Getopt::Long;
my @OPTV=@ARGV;

# Set env for scripts 
$ENV{'PERL5LIB'} = $ENV{'PERL5LIB'} . ":/home/httpd/obvius/perl_blib";

my $obvius_conf_dir='/etc/obvius/';

my %options=(
    website=>undef,
    dbname=>undef,
    dbuser=>'root', # For this script to access the database
    dbpasswd=>'',
    dbusername=>undef, # For the website to access the database
    perlname=>undef,
    domain=>undef,
    wwwroot=>'/var/www',
    httpd_group=>'www-data',
    staff_group=>'staff',
    skeleton_dir=>'/var/www/obvius/skeleton',
    fromconf=>undef,
   );
# Remember to update sub usage below, when updating options.

GetOptions(
	   'website=s'    =>\$options{website},
	   'dbname=s'     =>\$options{dbname},
	   'dbuser=s'     =>\$options{dbuser},
	   'dbpasswd=s'   =>\$options{dbpasswd},
           'dbusername=s' =>\$options{dbusername},
	   'perlname=s'   =>\$options{perlname},
	   'domain=s'     =>\$options{domain},
	   'wwwroot=s'    =>\$options{wwwroot},
	   'httpd_group=s'=>\$options{httpd_group},
	   'staff_group=s'=>\$options{staff_group},
	   'skeleton_dir=s'=>\$options{skeleton_dir},
           'fromconf:s'   =>\$options{fromconf},
	  ) or usage("Couldn't understand options, stopping");

usage("Please supply website, stopping") unless ($options{website});

read_conf(\%options) if (defined $options{fromconf});

usage("Please supply dbname, stopping") unless ($options{dbname});
$options{perlname}=ucfirst($options{dbname}) unless ($options{perlname});
($options{domain})=($options{website}=~/^[^.]*[.](.*)$/) unless ($options{domain});
$options{dbusername}=substr($options{dbname}, 0, 4) unless ($options{dbusername}); # Must not be too long

my @dirs=(
	  { dir=>'backup', },
	  { dir=>'bin', },
	  { dir=>'conf', },
	  { dir=>'db', },
	  { dir=>'docs', },
          { dir=>'docs/style', },
          { dir=>'docs/pics', },
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
	   { dir=>'var', file=>'document_cache.txt-off', perms=>'0664', group=>$options{httpd_group} },
	  );

my @symlinks=(
	      { dir=>'docs', link=>'cache', to=>'var/document_cache', },
	      { dir=>'docs', link=>'stats', to=>'stats', },
              { dir=>'docs', link=>'scripts', to=>"$options{wwwroot}/obvius/docs/scripts", },
              { dir=>'docs/pics', link=>'icons', to=>"$options{wwwroot}/obvius/docs/pics/icons", },
              { dir=>'docs/style', link=>'admin.css', to=>"$options{wwwroot}/obvius/docs/style/admin.css", },
              { dir=>'docs/style', link=>'common.css', to=>"$options{wwwroot}/obvius/docs/style/common.css", },
              { dir=>'docs/style', link=>'editor.css', to=>"$options{wwwroot}/obvius/docs/style/editor.css", },
              { dir=>'docs/style', link=>'public.css', to=>"$options{wwwroot}/obvius/docs/style/public.css", },
              { dir=>'docs/style', link=>'validation.xsl', to=>"$options{wwwroot}/obvius/docs/style/validation.xsl", },
	     );

my @db_files=qw(structure.sql perms.sql);

# Fix directories:
print "Directories ...\n";
die "wwwroot ($options{wwwroot}) doesn't exists, stopping" unless (-d $options{wwwroot});
make_dir("$options{wwwroot}/$options{website}", $options{staff_group});
store_cmdline("$options{wwwroot}/$options{website}/.new_website.pl");

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
unless (-d $obvius_conf_dir) {
    print "creating $obvius_conf_dir ...\n";
    make_dir($obvius_conf_dir, $options{staff_group});
}

# Create Obvius conf-file:
print "Configuration and database ...\n";

make_conf("$obvius_conf_dir$options{dbname}.conf");

# Create database:
make_db($options{dbname});

# print "Do you want to import some basic documents (Y/n)? ";
# my $test = <STDIN>;
# unless($test and $test =~ /^n/i) {
#     system("cat $options{wwwroot}/$options{website}/db/basic_structures.sql | mysql $options{dbname} -u $options{dbuser} --password=$options{dbpasswd}")
# }

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

normal_db_login=$options{dbusername}_normal
normal_db_passwd=default_normal

privileged_db_login= $options{dbusername}_priv
privileged_db_passwd=default_priv

administrator = admin

htdig_config = $options{dbname}
htdig_title = $options{domain} - 

debug = 0
benchmark = 0

sitename=$options{website}
perlname=$options{perlname}

help_server = help.obvius.org

design=3columns

english_frontpage=frontpage_en

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
	# Make root document, and publish it:
	system "$options{wwwroot}/obvius/otto/create_root ${dbname} Forside --publish";
        # Import initial documents (XXX httpd_user here:):
        system "sudo -u www-data $options{wwwroot}/obvius/bin/create --site ${dbname} $options{wwwroot}/$options{website}/db/initial_documents.xml"
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

sub read_conf {
    my ($options)=@_;

    my $confname;

    if ($options->{fromconf}) {
        $confname=$options->{fromconf};
    }
    else {
        $confname=$options->{website};
        $confname=~s/^[^.]+[.]//;
        $confname=~s/[.][^.]+$//;
        $confname.='.conf';
    }

    my $conffile="$obvius_conf_dir$confname";
    my %conf;
    my $conffh;
    open $conffh, $conffile or die "Couldn't read $conffile, stopping";
    while (my $line=<$conffh>) {
        next if ($line=~/^\s*\#/);
        chomp $line;
        my ($key, $value)=split /\s*=\s*/, $line, 2;
        next unless (defined $key);
        $conf{$key}=$value;
    }
    close $conffh;

    print "Options gathered from $conffile:\n";

    # Options that are given (required):
    #  website
    #  fromconf (takes us here)

    # Options we can't deduce from the .conf:
    #  httpd_group
    #  skeleton_dir
    #  dbuser
    #  dbpasswd
    #  staff_group
    #  wwwroot

    # Options we can get from the .conf:
    #  dbusername
    #  domain
    #  dbname
    #  perlname

    my @convertions=(
                     {
                      optionkey=>'dbusername',
                      confkey=>'normal_db_login',
                      pattern=>'^([^_]+)_',
                     },
                     {
                      optionkey=>'domain',
                      confkey=>'sitename',
                      pattern=>'^[^.]*[.](.*)',
                     },
                     {
                      optionkey=>'dbname',
                      confkey=>'DSN',
                      pattern=>'^DBI:\w+:(?:database=|)(\w+)', # '(?:' means do not put this in $N
                     },                                        # So I can keep '$1' in the loop below
                     {
                      optionkey=>'perlname',
                      confkey=>'perlname',
                      pattern=>"^(.*)\$",
                     },
                    );

    foreach my $convertion (@convertions) {
        if (!defined $options{$convertion->{optionkey}}) {
            my $regexp=$convertion->{pattern};
            if ($conf{$convertion->{confkey}}=~/$regexp/) {
                $options{$convertion->{optionkey}}=$1;
                print " ", $convertion->{optionkey}, ":\t", $options{$convertion->{optionkey}}, "\n";
            }
        }
    }

    print "Does the above look right? [Y/n] ";
    my $yn=<STDIN>;
    if ($yn=~/n/i) {
        print "Please supply additional options then. Sorry I couldn't be of more help.\n";
        exit 0;
    }

    print "Ok, proceeding.\n";
}

sub store_cmdline {
    my ($filename)=@_;

    my $fh;
    open($fh, ">>$filename") or die "Couldn't write $filename, crying, ahem, stopping";
    print $fh "# $ENV{USER} " . localtime() . "\n";
    print $fh "$0 @OPTV\n\n";

    close $fh;
}

sub usage {
    print <<EOT;

Usage: new_website.pl --website <website> --dbname <dbname>

(You probably need to specifiy dbuser and dbpasswd as well)

Further options:
                           default:

 --perlname <perlname>     <Dbname>
 --dbusername <short name> First 4 characters of dbname
 --domain <domain>         <website> after the first dot to the end
 --wwwroot <wwwroot>       /var/www
 --httpd_group <group>     www-data
 --staff_group <group>     staff
 --skeleton_dir <dir>      /var/www/obvius/skeleton

 --dbuser <database user>  root (what user to use when creating the database)
 --dbpasswd <password>

 --fromconf [confname]
EOT
    exit(1);
}
