#!/bin/sh

URI=`echo $3 | sed -e 's/http:\/\/[^\/]*//'`;

echo "<html><head><title>MS Word Document: $URI</title></head><body>"
/usr/bin/antiword $1
echo "</body></html>"


