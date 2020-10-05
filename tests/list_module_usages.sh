#!/bin/bash
FOLDERS_TO_CHECK="$1"
# Apache2::SizeLimit & compat require live mod_perl environments
# Apache2::FakeRequest causes weird errors due to dynamic loading in mod perl
# Apache::File & Text::Format are still included in mason/admin/action/send
# Text::Aspell & XML::DOM live in most likely deprecated cgi spellcheck script
# WebObvius::Cache::Flushing is referenced in old SOAP functionality
# Formengine dynamically loads classes
# WebObvius::Site loads Apache2::SizeLimit
# use mysql; comes from sql script
EXCLUDE_MODULES="Apache2::FakeRequest|Apache2::SizeLimit|Apache2::compat|Apache::File|Module::Install|Text::Format|Text::Aspell|XML::DOM|WebObvius::Cache::Flushing|WebObvius::FormEngine::Fields::MultipleBase|WebObvius::Site|use mysql;|use strict;|use warnings;|use utf8;"

if [ -z "$FOLDERS_TO_CHECK" ]; then
    echo "Please specify target folders"
    exit 1
fi

cat <<EOT
#!/usr/bin/perl

use strict;
use warnings;

use Test;
BEGIN { plan tests => 1 };
EOT

egrep -Iohr "^\s*?use (base )?'?(qw\()?[A-Za-z0-9:]+'?\)?;" "$FOLDERS_TO_CHECK" | egrep -v "Magenta|$EXCLUDE_MODULES" | sed 's/^ *//g' | sort -u

cat <<EOT

ok(1);
EOT
