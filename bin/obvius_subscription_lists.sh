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

export PATH=/usr/local/mysql/bin/:$PATH

for dir; do
    cd $dir || cd /home/httpd/$dir || continue
    test -e setup.conf || continue
    test -e "SERVER_IS_$hostname" -o "$FORCE" || continue
    test -d mail || continue

    site="$(basename $dir)"

    echo "#obvius_subscription_lists: $site"

    for db in MYSQL:*; do
	test "$db" = "MYSQL:*" && continue
	DB="$(expr "$db" :  '.*:\(.*\)')"

	mysql $DB --batch --skip-column-names -e "select docs.id, docs.name from docs where docs.subscribeable = 1" | awk -v DB="mail/$DB" -F'	' '{ print "nobody" > DB "." $1 "." $2 "+" }'

	mysql $DB --batch --skip-column-names -e "select docs.id, docs.name, subscribers.email from docs left join subscriptions on subscriptions.doc = docs.id left join subscribers on subscriptions.subscriber = subscribers.id where docs.subscribeable = 1 and subscribers.email != '' and subscribers.id is not null" | awk -v DB="mail/$DB" -F'	' '{ print $3 >> DB "." $1 "." $2 "+" }'

    done

    for new in mail/*+; do
	test "$new" = "mail/*+" && break
	file="$(basename $new +)"
	rm -f mail/$file-
	if cmp -s mail/$file mail/$file+; then
	    rm -f mail/$file+
	else
	    ln mail/$file mail/$file- 2>/dev/null
	    mv -f mail/$file+ mail/$file
	fi
    done
done
