#!/bin/sh

DBNAME=${dbname}
WWWROOT=${wwwroot}
DBUSER=$1
DBPASSWD=$2
if [ "$1" != "" ]; then
    perl -ne '$cycle=(!$cycle) if /^### CYCLE$/; print if $cycle' structure.sql | mysql -u $DBUSER --password=$DBPASSWD $DBNAME
else
    perl -ne '$cycle=(!$cycle) if /^### CYCLE$/; print if $cycle' structure.sql | mysql $DBNAME
fi


$WWWROOT/obvius/otto/add_fieldtypes.pl $DBNAME fieldtypes.txt $DBUSER $DBPASSWD
$WWWROOT/obvius/otto/add_doctypes.pl $DBNAME doctypes.txt $DBUSER $DBPASSWD
$WWWROOT/obvius/otto/add_editpages.pl $DBNAME editpages.txt $DBUSER $DBPASSWD
