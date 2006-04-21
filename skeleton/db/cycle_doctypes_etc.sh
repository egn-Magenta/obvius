#!/bin/sh
# $Id$

#include <conf/config.h>

#if not length("DBHOST")
#undef DBHOST
#define DBHOST localhost
#endif


#if "DBTYPE" eq "mysql"

#define DBI mysql
#define COMMAND  mysql
#define USERFLAG -u
#define PASSWORD --password=DBPASSWD

#elif "DBTYPE" eq "pgsql"

#define DBI Pg
#define COMMAND  psql
#define USERFLAG -U
#define PASSWORD --password

#else
#error DBTYPE is invalid or not specified, must be one of: [mysql, pgsql]
#endif

#define DSN "DBI:database=DBNAME;host=DBHOST"

#if length("DBPASSWD")
#define DBFLAGS USERFLAG DBUSER PASSWORD
#elif length("DBUSER")
#define DBFLAGS USERFLAG DBUSER
#else
#define DBFLAGS
#endif

COMMAND -h DBHOST DBFLAGS DBNAME < cycle_doctypes.sql
PREFIX/otto/add_fieldtypes.pl DSN fieldtypes.txt DBUSER DBPASSWD
PREFIX/otto/add_doctypes.pl DSN doctypes.txt DBUSER DBPASSWD
PREFIX/otto/add_editpages.pl DSN editpages.txt DBUSER DBPASSWD
