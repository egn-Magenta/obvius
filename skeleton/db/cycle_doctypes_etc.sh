#!/bin/sh

DBNAME=${dbname}
WWWROOT=${wwwroot}
DBHOST=${dbhost}
DBHOST=${DBHOST:-localhost}
DSN="database=$DBNAME;host=$DBHOST"
DBUSER=$1
DBPASSWD=$2
if [ "$1" != "" ]; then
    perl -ne '$cycle=(!$cycle) if /^### CYCLE$/; print if $cycle' structure.sql | mysql -h $DBHOST -u $DBUSER --password=$DBPASSWD $DBNAME
else
    perl -ne '$cycle=(!$cycle) if /^### CYCLE$/; print if $cycle' structure.sql | mysql $DBNAME
fi


$WWWROOT/obvius/otto/add_fieldtypes.pl $DSN fieldtypes.txt $DBUSER $DBPASSWD
$WWWROOT/obvius/otto/add_doctypes.pl $DSN doctypes.txt $DBUSER $DBPASSWD
$WWWROOT/obvius/otto/add_editpages.pl $DSN editpages.txt $DBUSER $DBPASSWD
