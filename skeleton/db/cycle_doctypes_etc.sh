#!/bin/bash
# $Id$
#
#include <conf/config.h>
#
#if not length("DBHOST")
#undef DBHOST
#define DBHOST localhost
#endif
#
#define DASH -
#
#if "DBTYPE" eq "mysql"
#
#define DBI mysql
#define COMMAND  mysql
#define USERFLAG -u
#define PASSWORDARG DASH-password=$DbPasswd
#
#elif "DBTYPE" eq "pgsql"
#
#define DBI Pg
#define COMMAND  psql
#define USERFLAG -U
#define PASSWORDARG DASH-password
#
#else
#error DBTYPE is invalid or not specified, must be one of: [mysql, pgsql]
#endif
#
#define DBFLAGS_USER USERFLAG $DbUser
#define DBFLAGS_USER_PW DBFLAGS_USER PASSWORDARG
#
#ifdef OLDCOMMAND
COMMAND -h DBHOST DBFLAGS DBNAME < cycle_doctypes.sql
PREFIX/otto/add_fieldtypes.pl DSN fieldtypes.txt DBUSER DBPASSWD
PREFIX/otto/add_doctypes.pl DSN doctypes.txt DBUSER DBPASSWD
PREFIX/otto/add_editpages.pl DSN editpages.txt DBUSER DBPASSWD
#endif
#
ObviusDir=PREFIX
Dbi=DBI
DbName=DBNAME
DbHost=DBHOST

# Use .cycle_conf to overwrite variables locally
ConfFile="`pwd`/.cycle_local.conf"
if [ -f "$ConfFile" ]; then
    . $ConfFile
fi

DbHost=${DbHost:-localhost}
Dsn="$Dbi:database=$DbName;host=$DbHost"
DbUser=${1:-$DbUser}
DbPasswd=${2:-$DbPasswd}

echo \'$DbUser\'
echo \'$DbPasswd\'

if [ "$DbUser" != "" ]; then
    if [ "$DbPasswd" != "" ]; then
        COMMAND -h $DbHost DBFLAGS_USER_PW $DbName < cycle_doctypes.sql
    else
        COMMAND -h $DbHost DBFLAGS_USER $DbName < cycle_doctypes.sql
    fi
else
    COMMAND -h $DbHost $DbName < cycle_doctypes.sql
fi

$ObviusDir/otto/add_fieldtypes.pl $Dsn fieldtypes.txt $DbUser $DbPasswd
$ObviusDir/otto/add_doctypes.pl $Dsn doctypes.txt $DbUser $DbPasswd
$ObviusDir/otto/add_editpages.pl $Dsn editpages.txt $DbUser $DbPasswd


