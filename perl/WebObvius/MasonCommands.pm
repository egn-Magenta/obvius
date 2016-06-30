package WebObvius::MasonCommands;

use strict;
use warnings;

use vars qw($m $doc $mcms $prefix $uri $vdoc $obvius $doctype $r);

use Data::Dumper;

use Obvius::Translations ();

# Global translation methods
*__ = \&Obvius::Translations::gettext;
*gettext = \&Obvius::Translations::gettext;

# Return the package name used for site-specific commands.
sub sitecommands {
    if($r) {
        my $classname = $r->notes('site_packagename');
        if(!defined($classname)) {
            $classname = 'WebObvius::MasonCommands';
            if($obvius) {
                $classname = $obvius->config->param('site_packagename') || '';
            }
            if($classname) {
                $classname->initialize(
                    m => \$HTML::Mason::Commands::m,
                    doc => \$doc,
                    mcms => \$mcms,
                    prefix => \$prefix,
                    uri => \$uri,
                    vdoc => \$vdoc,
                    obvius => \$obvius,
                    doctype => \$doctype,
                    r => \$r,
                );
            }
            $r->notes('site_packagename' => $classname);
        }
        return $classname;
    }

    return 'WebObvius::MasonCommands';
}

1;