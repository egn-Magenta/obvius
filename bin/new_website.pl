#!/usr/bin/perl

# new_website.pl - create the necessary directories, permissions and
#                  stuff for a new Obvius website.
#
# TODO: * Perhaps move symlinks to the skeleton directory instead?
#       * When stuff exists, the script should check permissions anyway.
#
# Copyright (C) 2002-2005 aparte A/S, Magenta ApS. By Jørgen Ulrik
#                         B. Krag, Adam Sjøgren. Under the GPL.
#
# $Id$

use strict;
use warnings;
use String::Random qw (random_string);

use Getopt::Long;
my @OPTV=@ARGV;

my $obvius_conf_dir='/etc/obvius/';

my $bsd = ( $^O =~ /bsd/);

my %options = (
	website		=> undef,
	dbhost		=> undef,
	dbname		=> undef,
	dbtype		=> 'mysql',
	dbuser		=> undef, # For this script to access the database
	dbpasswd	=> '',
	dbusername	=> undef,  # For the website to access the database
	perlname	=> undef,
	domain		=> undef,
	wwwroot		=> ($bsd ? '/usr/local/www/data' : '/var/www'),
	httpd_group	=> ($bsd ? 'www' : 'www-data'),
	staff_group	=> 'staff',
	prefix		=> '/usr/local/obvius',
	fromconf	=> undef,
	new_admin	=> 0,
	hostname	=> 'localhost',
	force		=> 0,
	apache_version	=> 0,
);
# Remember to update sub usage below, when updating options.

GetOptions(
	\%options,
	'website=s',
	'dbhost=s',
	'dbname=s',
	'dbuser=s',
	'dbtype=s',
	'dbpasswd=s',
	'dbusername=s',
	'perlname=s',
	'domain=s',
	'wwwroot=s',
	'httpd_group=s'	,
	'staff_group=s'	,
	'prefix=s',
	'fromconf=s',
	'new_admin',
	'hostname=s',
	'apache_version=s',
	'force',
) or usage("Couldn't understand options, stopping");

usage("Please supply --website, stopping") unless ($options{website});
usage("--dbtype must be one of [mysql,pgsql]") unless $options{dbtype} =~ /^(mysql|pgsql)$/;

unless ( defined $options{dbuser}) {
	if ( $options{dbtype} eq 'mysql') {
		$options{dbuser} = 'root';
	} elsif ( $options{dbtype} eq 'pgsql') {
		$options{dbuser} = ( $^O =~ /bsd/) ? 'pgsql' : 'postgres';
	}
}


read_conf(\%options) if (defined $options{fromconf});

usage("Please supply dbname, stopping") unless $options{dbname};
$options{perlname} = ucfirst( $options{dbname}) unless $options{perlname};
($options{domain})=($options{website}=~/^[^.]*[.](.*)$/) unless $options{domain};
$options{domain} = $options{website} unless $options{domain};
$options{dbusername}=substr($options{dbname}, 0, 4) unless ($options{dbusername}); # Must not be too long
$options{dbpassword}=random_string("sssssssssss");
$options{hostname}=`hostname -f` if ((defined $options{dbhost}) and ($options{hostname} eq 'localhost'));

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

push @dirs, (
	{ dir=>'docs/grafik', },
	{ dir=>'docs/grafik/pager', },
	{ dir=>'docs/grafik/news', },
	{ dir=>'docs/grafik/menu', },
	{ dir=>'docs/css', },
) if (!$options{new_admin}); # Legacy dirs

my @files=(
	{ dir=>'var', file=>'document_cache.txt', perms=>'0664', group=>$options{httpd_group} },
	{ dir=>'var', file=>'document_cache.txt-off', perms=>'0664', group=>$options{httpd_group} },
);

my @symlinks=(
	{ dir=>'docs', link=>'cache', to=>'var/document_cache', },
	{ dir=>'docs', link=>'stats', to=>'stats', },
	{ dir=>'docs', link=>'scripts', to=>"$options{prefix}/docs/scripts", },
	{ dir=>'docs/pics', link=>'icons', to=>"$options{prefix}/docs/pics/icons", },
	{ dir=>'docs/style', link=>'admin.css', to=>"$options{prefix}/docs/style/admin.css", },
	{ dir=>'docs/style', link=>'common.css', to=>"$options{prefix}/docs/style/common.css", },
	{ dir=>'docs/style', link=>'editor.css', to=>"$options{prefix}/docs/style/editor.css", },
	{ dir=>'docs/style', link=>'public.css', to=>"$options{prefix}/docs/style/public.css", },
	{ dir=>'docs/style', link=>'validation.xsl', to=>"$options{prefix}/docs/style/validation.xsl", },
);
push @symlinks, (
	{ dir=>'docs', link=>'admin_js', to=>"$options{prefix}/docs/js", },
	{ dir=>'docs/grafik', link=>'admin', to=>"$options{prefix}/docs/grafik/admin", },
	{ dir=>'docs/grafik', link=>'navigator', to=>"$options{prefix}/docs/grafik/admin/navigator", },
) if (!$options{new_admin}); # Legacy symlinks

my %heavy_interpolate_needed = map { $_ => 1 } qw(
	db/structure.sql
	db/cycle_doctypes.sql
	db/cycle_doctypes_etc.sh
	db/perms.sql
	conf/site.conf
);

# check for apache version
unless ( $options{apache_version}) {
	my $v = `apachectl -v`;
	die "Cannot detect apache version\n" if $? < 0;	
	$options{apache_version} = ( $v =~ /Server version: Apache\/(\d)/) ? $1 : 1;
}


# Fix directories:
print "Directories ...\n";
die "wwwroot ($options{wwwroot}) doesn't exist, stopping" unless (-d $options{wwwroot});
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
	if (not $options{force} and -e $dest) {
		print " File $file->{dir}/$file->{file} already exists\n";
	} else {
		run_system_command ("(cd $options{wwwroot}/$options{website}/$file->{dir}; touch $file->{file}; chmod $file->{perms} $file->{file}; chgrp $file->{group} $file->{file})");
	}
}

# Fix symlinks:
print "Symlinks ...\n";
foreach my $symlink (@symlinks) {
    make_symlink($symlink->{to}, $symlink->{dir}, $symlink->{link});
}

# Create site-wide config for heavy interpolation using sqlpp
my $config = "$options{wwwroot}/$options{website}/conf/config.h";
open F, "> $config" or die "Cannot write $config:$!";
while ( my ( $key, $value) = each %options) {
	print F "#define ", uc($key), " ", (defined($value) ? $value : ''), "\n";
}
close F;

# Copy from the skeleton-dir, interpolating:
print "Skeleton files ...\n";
my @skeleton_files=map { s|^[.]/||; $_; } split /\n/, `(cd $options{prefix}/skeleton; find ./ -type f)`;
# db/structure.sql is special, move it forward
@skeleton_files = (
	(grep { m/structure.sql/} @skeleton_files),
	(grep {!m/structure.sql/} @skeleton_files)
);

foreach my $skeleton_file (@skeleton_files) {
	next if ($skeleton_file =~ /CVS/);
	copy_interpolate(
		"$options{prefix}/skeleton", 
		$skeleton_file, 
		"$options{wwwroot}/$options{website}"
	);
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
#     run_system_command("cat $options{wwwroot}/$options{website}/db/basic_structures.sql | mysql $options{dbname} -u $options{dbuser} --password=$options{dbpasswd}")
# }

exit 0;

# copy_interpolate - read the $PREFIX/skeleton/skeleton_file and copy it
#                    to $dest/$skeleton_file while interpolating any
#                    variables found.

sub copy_interpolate
{
	my ($skeleton_dir, $skeleton_file, $dest_dir)=@_;

	my $from = "$skeleton_dir/$skeleton_file";
	my $dest = "$dest_dir/$skeleton_file";

	if ( not $options{force} and -e $dest) {
		print " $dest already exists\n";
		return;
	}

	if ( $heavy_interpolate_needed{$skeleton_file}) {
		run_system_command("sqlpp -I $options{wwwroot}/$options{website} -o $dest $from");
		return;
	}

	# lightweight interpolation

	open F, $from or die "Couldn't read $from, stopping";
	local $/;
	my $cont = <F>;
	close F;

	$cont =~ s/\$\{(\w+)\}/
		exists($options{$1}) ?
			( defined($options{$1}) ? $options{$1} : '') :
			do { warn "$from: unknown macro \$\{$1\}\n"; "\$\{$1\}" }
	/gsex;

	open F, "> $dest" or die "Couldn't write $dest, stopping";
	print F $cont;
	close F;
}

# make_symlink - if the symlink doesn't exist, make it.
sub make_symlink {
    my ($to, $dir, $link)=@_;

    if (-l "$options{wwwroot}/$options{website}/$dir/$link") {
	print " Symlink $dir/$link already exists\n";
    } else {
	$to="../$to" unless ($to=~m!^/!);
	run_system_command ("(cd $options{wwwroot}/$options{website}/$dir; ln -s $to $link)");
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
    run_system_command ("chgrp $group $dir");
    run_system_command ("chmod g+w $dir");
}

# make_conf - create a default Obvius configuration file if it doesn't exist
sub make_conf {
	my ($file)=@_;

	if (not $options{force} and -e $file) {
		print " Configuration file $file already exists\n";
	} else {
		my $dsn;
		if ( $options{dbtype} eq 'mysql') { 
			if ($options{dbhost}) {
				$dsn="DBI:mysql:database=$options{dbname};host=$options{dbhost}";
			} else {
				$dsn="DBI:mysql:$options{dbname}"
			}
		} elsif ( $options{dbtype} eq 'pgsql') {
			if ($options{dbhost}) {
				$dsn="DBI:Pg:dbname=$options{dbname};host=$options{dbhost}";
			} else {
				$dsn="DBI:Pg:dbname=$options{dbname}"
			}
		}
		my $fh;
		open $fh, ">$file" or die "Couldn't write $file, stopping";
		print $fh <<EOT;
DSN = $dsn
prefix=$options{prefix}

normal_db_login=$options{dbusername}_normal
normal_db_passwd=$options{dbpassword}

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

sub make_db
{
	my ($dbname)=@_;

        my $host_option = $options{dbhost} ? "-h $options{dbhost}" : "";
	my ( $dbcreate, $dbrun);
	
	if ( $options{dbtype} eq 'mysql') {
		$dbcreate = "mysqladmin create $dbname $host_option -u $options{dbuser} --password=$options{dbpasswd}";
		$dbrun = "mysql $dbname $host_option -u $options{dbuser} --password=$options{dbpasswd}";
	} elsif ( $options{dbtype} eq 'pgsql') {
		my $pass = length($options{dbpasswd}) ? '--password' : '';
		$dbcreate = "createdb $dbname -U $options{dbuser} $pass";
		$dbrun = "psql $dbname $host_option -U $options{dbuser} $pass";
	}

	`echo | $dbrun 2>/dev/null`;
	unless ( $?) {
		print "Database already exists\n";
		return;
	}

	run_system_command( $dbcreate);

	run_system_command( "cat $options{wwwroot}/$options{website}/db/structure.sql | $dbrun");
	run_system_command( "cat $options{wwwroot}/$options{website}/db/perms.sql | $dbrun");
	# Put doctypes, editpages, fieldspecs and fieldtypes in the database:
	run_system_command( "(cd $options{wwwroot}/$options{website}/db; sh ./cycle_doctypes_etc.sh)");
	# Make root document, and publish it:
	run_system_command( "$options{prefix}/otto/create_root ${dbname} Forside --publish");
        # Import initial documents (XXX httpd_user here:):
        run_system_command( "$options{prefix}/bin/create --site ${dbname} $options{wwwroot}/$options{website}/db/initial_documents.xml");
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
    #  obvius
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

#run_system_command: Runs a system command and dies if the command returned non 0 
sub run_system_command {
	my ($command)=@_;
	my ( undef, undef, $line) = caller; 
	print "\$\$ $command\n";
	system($command) == 0 or die "Command \"$command\" had non-zero return value ($?) at line $line\n";
}

sub usage {
    print <<EOT;

** $_[0]

Usage: new_website.pl --website <website> --dbname <dbname>

Further options:
                           default:

 --perlname <perlname>     <Dbname>
 --dbusername <short name> First 4 characters of dbname
 --domain <domain>         <website> after the first dot to the end
 --wwwroot <wwwroot>       $options{wwwroot}
 --website <FQDN>
 --httpd_group <group>     $options{httpd_group}
 --staff_group <group>     staff
 --prefix <dir>            $options{prefix}

 --dbtype [mysql,pgsql]>   database server type
 --dbhost <database host>  database server for website
 --dbuser <database user>  root (what user to use when creating the database)
 --dbpasswd <password>

 --fromconf [confname]

 --new_admin               defaults to false, use if the website uses the new admin
 --hostname [hostname]     hostname to be used in DB accessstatements. Only needed if the name reported by hostname -f can't be resolved 
 --force                   force copy files
 --apache_version <0,1,2>  0 - autodetect
EOT
    exit(1);
}
