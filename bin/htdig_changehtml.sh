#!/bin/sh
sed -e 's|<!--htdig_noindex_follow-->|<noindex follow>|g' \
    -e 's|<!--/htdig_noindex_follow-->|</noindex>|g' $1