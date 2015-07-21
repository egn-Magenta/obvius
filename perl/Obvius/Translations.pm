package Obvius::Translations;

use strict;
use warnings;
use utf8;

use base qw(Exporter);

use POSIX ();
use Locale::Messages ();
use Obvius::CharsetTools;

our @EXPORT_OK = qw(
    __
    gettext
    register_domain
    set_domain
    set_translation_lang
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
    return Encode::decode('utf8', $translation);
}

*__ = \&gettext;

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

1;