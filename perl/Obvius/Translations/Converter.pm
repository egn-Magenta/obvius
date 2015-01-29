package Obvius::Translations::Converter;

use strict;
use warnings;
use utf8;

use XML::Simple;
use Data::Dumper;
use Locale::Maketext::Extract;
use Obvius::CharsetTools;
use Obvius::Translations::Extract;

sub convert {
    my ($dir) = @_;

    my $msgcat_executeable = qx{which msgcat};
    die "Could not find msgcat executeable" unless($msgcat_executeable);
    $msgcat_executeable =~ s{\s+$}{}s;

    my $import_comment = "Imported from old translations";

    # Collect old translations
    my @files = grep { -f $_  } (
        (glob($dir . '/mason/*/translations.xml')),
        (glob($dir . '/mason/*/translations_local.xml')),
    );

    my %translations;
    foreach my $file (@files) {
        print STDERR "Processing old translationfile $file\n";
        my $xml_data = XMLin($file);

        my $entries = $xml_data->{text} || {};
        foreach my $key (sort keys %$entries) {
            my $item = $entries->{$key};
            $key = Obvius::CharsetTools::mixed2utf8($key);
            my $langs = $item->{translation} || [];
            foreach my $langobj (@$langs) {
                my $lang = $langobj->{lang};
                my $content = $langobj->{content};
                next unless($lang and $content);
                $content = Obvius::CharsetTools::mixed2utf8($content);
                my $existing = $translations{$lang}->{$key};
                if($existing && $existing ne $content) {
                    print STDERR "Translation conflict for key $key ($lang):\n";
                    print STDERR $existing, "\n";
                    print STDERR " VS ", "\n";
                    print STDERR $content, "\n\n";
                }
                $translations{$lang}->{$key} = $content;
                $translations{keys}->{$key} = 1;
            }
        }
    }

    my $extra_file = $dir . '/i18n/extra.pot';
    my $extra_tmp_file = $extra_file . '.tmp.pot';

    print STDERR "Adding old translations to templatefile $extra_file\n";

    my $ext = Locale::Maketext::Extract->new;
    my @keys = keys %{$translations{keys}};
    $ext->set_lexicon({ map { $_ => "" } @keys });
    my %comments = map { $_ => $import_comment } @keys;
    $ext->set_comments(\%comments);
    $ext->set_header(
        Obvius::Translations::Extract::fix_header($ext->header)
    );


    $ext->write_po($extra_tmp_file);

    unless(-f $extra_file) {
        system("touch", $extra_file);
    }

    system(
        $msgcat_executeable,
        '-o', $extra_file,
        $extra_tmp_file,
        $extra_file
    );
    unlink($extra_tmp_file);


    my @translation_dirs = grep {
        -d $_ && m{/\w\w(_\w\w)?$}
    } glob ($dir . '/i18n/*');

    my $src = (-f $dir . '/perl/Obvius.pm') ? '' : '_src';

    foreach my $tdir (@translation_dirs) {
        my ($lang) = ($tdir =~ m{/(\w\w)(_\w\w)?$});
        my $lexicon = $translations{$lang};
        next unless($lexicon);


        foreach my $file (glob($tdir . "/LC_MESSAGES/*${src}.po")) {
            my $tmp_file = $file;
            $tmp_file =~ s{\.po}{.import_tmp_translations.po};

            print STDERR "Adding old translations to $file\n";

            # Reset $ext by reading the existing translation file
            $ext->read_po($file);

            # Add translations that were not there before
            my $ext_lexi = $ext->lexicon;
            my $ext_comments = $ext->{comments};
            foreach my $key (keys %$lexicon) {
                unless($ext_lexi->{$key}) {
                    $ext_lexi->{$key} = $lexicon->{$key};
                    $ext_comments->{$key} = $import_comment;
                }
            }
            $ext->write_po($tmp_file);

            system(
                $msgcat_executeable,
                '-o', $file,
                '--use-first',
                $tmp_file,
                $file
            );

            unlink($tmp_file);
        }
    }
}

1;