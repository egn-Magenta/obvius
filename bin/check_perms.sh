#!/bin/sh
# $Id$	

hostname="$(hostname)"
debug=0

FORCE=
while getopts ft c; do
    case $c in
    f)        FORCE=1;;
    ?)        echo "Usage $0 [-f] file ..." 2>&1; exit 1;;
    esac
done
shift `expr $OPTIND - 1`

function make_dir () {
    echo "Creating diretory $@" 1>&1
    mkdir "$@"
}

for dir; do
    cd $dir || cd /home/httpd/$dir || continue
    test -e "SERVER_IS_$hostname" -o "$FORCE" || continue

    echo "Checking permissions in $dir"
    
    chgrp -R aparte . 2>/dev/null

    # Mail dir cannot be group writable
    test -d mail || make_dir mail
    chown -R httpd.httpd mail
    chmod -R 755 mail

    # Docs area should exist:
    test -d docs || make_dir docs
    # gid?
    chown -R httpd.aparte docs
    chmod -R 775 docs

    # Upload area writable by httpd
    test -d docs/upload || make_dir docs/upload
    chown -R httpd.httpd docs/upload
    chmod -R 775 docs/upload

    # Ht:/Dig database area writable by httpd
    if [ -d htdig/db ]; then
	chown -R httpd.httpd htdig/db
	chmod -R 775 htdig/db
    fi

    # Logs dir
    test -d logs || make_dir logs
    chown -R httpd.httpd logs
    chmod -R 755 logs

    test -d var || make_dir var
    chown -R httpd.aparte var
    chmod -R 775 var

    for d in var/edit_sessions var/user_sessions; do
        test -d $d || make_dir $d
        test -d $d/LOCKS || make_dir $d/LOCKS
    done

    chown -R httpd.httpd var/*_sessions var/*_sessions/LOCKS
    chmod -R 775 var/*_sessions var/*_sessions/LOCKS

    test -d var/document_cache || make_dir var/document_cache

    chown -R httpd.httpd var/document_cache var/document_cache/*
    chmod -R 775 var/document_cache var/document_cache/*

    chown -R httpd.aparte var/document_cache.time
    chmod -R 664 var/document_cache.time


    dirs=.
    find $dirs -group aparte ! -perm -0020 |
    while read f; do
	chmod g+w "$f"
    done

done
