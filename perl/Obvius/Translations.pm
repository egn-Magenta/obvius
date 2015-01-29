package Obvius::Translations;

use strict;
use warnings;
use utf8;

use base qw(Exporter);

use POSIX ();
use Locale::Messages ();
use Obvius::CharsetTools;

my %lang_fallbacks = (
    en => "en_US",
    da => "da_DK",
    en_DK => "en_US",
    C => "en_US"
);

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

    $domain = get_translation_domain($domain);
    Locale::Messages::bindtextdomain($domain, $dir);
    Locale::Messages::bind_textdomain_codeset($domain, "utf8");

    return $domain;
}

sub set_domain {
    Locale::Messages::textdomain($_[0]);
}

sub set_translation_lang {
    my $lang = shift;

    $lang = $lang_fallbacks{$lang} || $lang;
    Locale::Messages::nl_putenv("LANGUAGE=${lang}");
    POSIX::setlocale(POSIX::LC_MESSAGES, '');
}

1;