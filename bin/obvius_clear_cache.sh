#!/bin/sh
# $Id$

hostname="$(hostname)"
debug=0

FORCE=
while getopts f c; do
    case $c in
    f)        FORCE=1;;
    ?)        echo "Usage $0 [-f] file ..." 2>&1; exit 1;;
    esac
done
shift `expr $OPTIND - 1`

for dir; do
    cd $dir || cd /home/httpd/$dir || continue
    test -e "SERVER_IS_$hostname" -o "$FORCE" || continue
    cd var 2>/dev/null || continue

    if [ -e document_cache.time ]; then
	(   find document_cache -type f -a ! -newer ./document_cache.time
	    find user_sessions/LOCKS -type f -mtime +1
	    find edit_sessions/LOCKS -type f -mtime +1
	    find edit_sessions -type f -mtime +7
	) | xargs rm -f
    fi
done
