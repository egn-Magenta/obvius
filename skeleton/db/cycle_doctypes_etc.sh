#!/bin/sh

DBNAME=${dbname}
WWWROOT=${wwwroot}

perl -ne '$cycle=(!$cycle) if /^### CYCLE$/; print if $cycle' structure.sql | mysql $DBNAME

$WWWROOT/obvius/otto/add_fieldtypes.pl $DBNAME fieldtypes.txt
$WWWROOT/obvius/otto/add_doctypes.pl $DBNAME doctypes.txt
$WWWROOT/obvius/otto/add_editpages.pl $DBNAME editpages.txt
