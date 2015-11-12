package WebObvius::MasonCommands;

use strict;
use warnings;

use Obvius::Translations ();

# Global translation methods
*__ = \&Obvius::Translations::gettext;
*gettext = \&Obvius::Translations::gettext;

1;