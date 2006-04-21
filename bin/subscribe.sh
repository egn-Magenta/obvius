#!/bin/sh
# $Id$

hostname="$(hostname)"
hour="$(date '+%H')"

debug=0
FORCE=
while getopts fd: c; do
    case $c in
    f)        FORCE=1;;
    d)        debug=$OPTARG;;  
    ?)        echo "Usage $0 [-f] file ..." 2>&1; exit 1;;
    esac
done
shift `expr $OPTIND - 1`

for dir; do
    cd $dir || cd /home/httpd/$dir || continue
    test -e "SERVER_IS_$hostname" -o "$FORCE" || continue
    test -x bin/subscription -a -s conf/subscription || continue
    fgrep -x "$hour" conf/subscription >/dev/null || continue

    site="$(basename $dir)"

    echo "#subscription: running for $site at $hour:00" 

    nice -5 ./bin/subscription "$debug" 2>&1
done
