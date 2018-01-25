package Obvius::Translations;

use strict;
use warnings;
use utf8;

use base qw(Exporter);

use POSIX ();
use Locale::Messages ();
use Locale::Maketext;
use Obvius::CharsetTools;

our @EXPORT_OK = qw(
    __
    gettext
    register_domain
    set_domain
    set_translation_lang
    translate_with_prefix
    translate_doctypename
    translate_editpagelabel
    translate_editpagetitle
    translate_editpagesubtitle
);

our @EXPORT = qw(
    __
    gettext
    set_translation_lang
);

my %lang_fallbacks = (
    en => "en_US",
    da => "da_DK",
    en_DK => "en_US",
    C => "en_US"
);

my %initialized;
my $current_lang = '';
my $active_domain = '';

sub gettext {
    my $key = shift;
    $key = Obvius::CharsetTools::mixed2utf8($key);
    my $translation = Locale::Messages::gettext($key);

    # If more arguments were specifed, assume we're dealing with a maketext
    # encoded string.
    $translation = maketext_compile($translation, @_) if (@_);

    return Encode::decode('utf8', $translation);
}

*__ = \&gettext;

sub translate_with_prefix {
    my $prefix = shift;
    my $key = shift;
    
    my $translated = gettext("$prefix:$key", @_) || '';
    if (substr($translated, 0, length($prefix) + 1) eq "$prefix:") {
        $translated = gettext($key, @_);
    }
    return $translated;
}

sub translate_doctypename {
    return translate_with_prefix("doctypename", @_);
}

sub translate_editpagelabel {
    return translate_with_prefix("editpagelabel", @_);
}

sub translate_editpagetitle {
    return translate_with_prefix("editpagetitle", @_);
}

sub translate_editpagesubtitle {
    return translate_with_prefix("editpagesubtitle", @_);
}

sub build_domain_name {
    my $obj = shift;

    if(my $ref = ref($obj)) {
        if($ref eq 'Obvius') {
            $obj = $obj->config->param('perlname');
        } elsif($ref eq 'Obvius::Config') {
            $obj = $obj->param('perlname')
        } else {
            die "Can not turn object of type $ref into a translation domain";
        }
    }
    $obj = lc($obj);
    
    $obj = "dk.obvius." . $obj unless($obj =~ m{^dk\.obvius\.});

    return lc($obj);
}

sub register_domain {
    my ($domain, $dir) = @_;

    $domain = build_domain_name($domain);
    Locale::Messages::bindtextdomain($domain, $dir);
    Locale::Messages::bind_textdomain_codeset($domain, "utf8");

    return $domain;
}

sub set_domain {
    my $domain = shift;
    if($domain ne $active_domain) {
        Locale::Messages::textdomain($domain);
        $active_domain = $domain;
    }
}

sub set_translation_lang {
    my $lang = shift;

    return if($current_lang eq $lang);

    $lang = $lang_fallbacks{$lang} || $lang;
    Locale::Messages::nl_putenv("LANGUAGE=${lang}");

    # The POSIX implementation under mod_perl want a specific name for a
    # locale that exists on the host machince before it allows the change,
    # so we have to try the most likely candidates until one succeeds.
    my $result;
    foreach my $try ($lang, "${lang}.UTF8", "${lang}.ISO-8859-1") {
        $result = Locale::Messages::setlocale(
            Locale::Messages::LC_MESSAGES, $try
        );
        last if($result and $result ne "C");
    }

    unless($result && $result ne "C") {
        die "Could not set language $lang. Is it available on the system?";
    }

    $current_lang = $lang;
}


sub initialize_for_obvius {
    my ($obvius) = @_;

    my $config = $obvius->config;
    my $perlname = $config->param('perlname');

    my $domain = $initialized{$perlname};

    unless(defined($domain)) {
        # The gettext_xs module does not respect changes in language under
        # mod_perl, so use gettext_pp instead.
        Locale::Messages->select_package("gettext_pp");

        # Old translations system should not initialize anything
        if($obvius->config->param('use_old_translation_system')) {
            $initialized{$perlname} = '';
            return;
        }

        my $dir = $config->param('sitebase');
        unless($dir) {
            die "No sitebase defined for Obvius config with perlname $perlname"
        }
        $dir =~ s{/$}{};
        $dir .= '/i18n';

        if(-d $dir) {
            $domain = register_domain($perlname, $dir);
        } else {
            $domain = build_domain_name($perlname);
        }
        $initialized{$perlname} = $domain;
    }

    set_domain($domain) if($domain);
}

sub maketext_compile {
    my ($input) = $_[0];

    my $group_open = -1;
    my @chunks;
    my $output = '';
    my $pos = 0;
    my @args;

    while($input =~  m/\G(
        # Patterns taken from Locale::Maketext::Guts
        [^\~\[\],]+  # non-~[] stuff
        |
        ~.       # ~[, ~], ~~, ~other
        |
        \[          # [ presumably opening a group
        |
        \]          # ] presumably closing a group
        |
        ~           # terminal ~ ?
        |
        $
        # Not from Locale::Maketext::Guts:
        |
        ,           # unescaped ",", used to delimit args
    )/xgs) {
        if ($1 eq "[") {
            if ($group_open >= 0) {
                die sprintf(
                    "Trying to open nested group at position %s " .
                    "inside group starting at position %s.",
                    $pos, $group_open
                )
            } else {
                $group_open = $pos
            }
            push(@chunks, $output);
            $output = '';
        } elsif($1 eq '') {
            if ($group_open >= 0) {
                die sprintf(
                    "Untermintaed group starting at position %s.",
                    $group_open
                )
            }
            push(@chunks, $output);
            $output = '';
        } elsif($1 eq ']') {
            if ($group_open < 0) {
                die sprintf("Unmatched closing bracket at position %s", $pos);
            }

            # Add what was parsed so far to args
            push(@args, $output);
            $output = '';
            my $method = shift(@args);
            unless($method) {
                die sprintf("No args for group starting at %s", $group_open)
            }
            unless(grep { $method eq $_ } qw(quant numerate numf)) {
                die "Unknown maketext method $method";
            }
            $output .= Locale::Maketext->$method(
                map { $_ =~ m{^_(\d+)$} ? $_[$1] : $_ } @args
            );
            @args = ();
            $group_open = -1;
        } elsif($1 eq '~') {
            # Single ~, only at string end?
            $output .= $1;
        } elsif(substr($1, 0, 1) eq '~') {
            $output .= substr($1, 1, 1)
        } elsif($1 eq ',') {
            if ($group_open >= 0) {
                push(@args, $output);
                $output = ''
            } else {
                $output .= $1
            }
        } else {
            $output .= $1
        }

        $pos += length($1);
    }

    return join("", @chunks);
}

1;