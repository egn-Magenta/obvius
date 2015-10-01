package Obvius::Translations::Extract;

use strict;
use warnings;
use utf8;

use Locale::Maketext::Extract;
use Obvius::Translations::ExtractPlugins::Mason;
use POSIX qw(strftime);
use File::Find ();

our $DEBUG = 0;
our $WARNINGS = 0;

sub fix_header {
    my ($header) = @_;

    my $timestamp = strftime("\%Y-\%m-\%d \%H:\%M\%z", localtime(time));

    $header =~ s/\bCHARSET\b/UTF-8/s;
    $header =~ s/(Language-Team|Last-Translator):[^\\]+/$1: none/s;
    #$header =~ s/(POT-Creation-Date):[^\\]+/$1: $timestamp/s;
    #$header = join("\n", grep {
    #    !/(Project-Id-Version|-Date|Last-Translator):/
    #} split(/\n/, $header)) . "\n";

    return $header;
}

sub extract_mason {
    my ($dir) = @_;

    die "No directory specified" unless($dir);
    $dir =~ s{/$}{};
    die "$dir is not a directory" unless(-d $dir);

    my $i18n_dir = $dir . '/i18n';
    die "No i18n under site $dir" unless(-d $i18n_dir);

    # Process mason files
    my $extractor = Locale::Maketext::Extract->new(
        plugins => {
            'Obvius::Translations::ExtractPlugins::Mason' => ['*'],
            'mason' => ['*'],
            'perl' => ['*']
        },
        warnings => $WARNINGS,
        verbose => $DEBUG
    );

    $extractor->set_header(fix_header($extractor->header));

    print STDERR "Extracting translations from mason\n";

    File::Find::find(sub {
        return if(m{.xml});
        return unless(-f $File::Find::name);
        $extractor->extract_file($File::Find::name);
    }, $dir . '/mason');

    $extractor->compile(1);
    $extractor->write_po($i18n_dir . '/extracted_from_mason.pot');
}

sub extract_perl {
    my ($dir) = @_;

    die "No directory specified" unless($dir);
    $dir =~ s{/$}{};
    die "$dir is not a directory" unless(-d $dir);

    my $i18n_dir = $dir . '/i18n';
    die "No i18n under site $dir" unless(-d $i18n_dir);

    my $extractor = Locale::Maketext::Extract->new(
        plugins => { 'perl' => ['*'] },
        warnings => $WARNINGS,
        verbose => $DEBUG
    );

    $extractor->set_header(fix_header($extractor->header));

    print STDERR "Extracting translations from perl\n";

    File::Find::find(
        sub {
            return unless(-f $File::Find::name);
            # TODO: Do we need to catch scripts without .pl extension?
            return unless(/\.(pm|pl)$/);
            $extractor->extract_file($File::Find::name);
        },
        grep { -d $_ } (
            $dir . '/perl',
            $dir . '/bin',
        )
    );

    $extractor->compile(1);
    $extractor->write_po($i18n_dir . '/extracted_from_perl.pot');
}

sub extract_doctypes {
    my ($dir) = @_;

    die "No directory specified" unless($dir);
    $dir =~ s{/$}{};
    die "$dir is not a directory" unless(-d $dir);

    return unless(-d $dir . '/db');

    my $i18n_dir = $dir . '/i18n';
    die "No i18n under site $dir" unless(-d $i18n_dir);

    my $extractor = Locale::Maketext::Extract->new(
        plugins => {
            'Obvius::Translations::ExtractPlugins::Doctypes' => ['*'],
        },
        warnings => $WARNINGS,
        verbose => $DEBUG
    );

    $extractor->set_header(fix_header($extractor->header));

    print STDERR "Extracting translations from doctypes\n";

    $extractor->extract_file($dir . '/db/editpages.txt');
    $extractor->compile(1);
    $extractor->write_po($i18n_dir . '/extracted_from_doctypes.pot');
    
}

sub extract_all {
    my ($dir) = @_;

    die "No directory specified" unless($dir);
    $dir =~ s{/$}{};
    die "$dir is not a directory" unless(-d $dir);

    my $msgcat_executeable = qx{which msgcat};
    die "Could not find msgcat executeable" unless($msgcat_executeable);
    $msgcat_executeable =~ s{\s+$}{}s;

    extract_mason($dir);
    extract_perl($dir);
    extract_doctypes($dir);

    print STDERR "Combining translation templates\n";

    system(
        $msgcat_executeable,
        '-t', 'UTF-8',
        '--no-location',
        '--sort-output',
        '-o', $dir . '/i18n/combined.pot',
        grep { -f $_ } (
            $dir . '/i18n/extracted_from_doctypes.pot',
            $dir . '/i18n/extracted_from_mason.pot',
            $dir . '/i18n/extracted_from_perl.pot',
            $dir . '/i18n/extra.pot',
        )
    ) && die "msgcat command failed";

    print STDERR "Done\n";
}

sub merge_and_update {
    my ($base_dir, $domain, $obvius_dir) = @_;

    die "No domain specified" unless($domain);

    # Process all translation dirs, forcing da_DK and en_US to be included
    my %dirs = map { $_ => 1 } (
        $base_dir . '/i18n/da_DK',
        $base_dir . '/i18n/en_US',
        grep { -d $_ } glob($base_dir . '/i18n/*'),
    );

    my $is_obvius = (-f $base_dir . '/perl/Obvius.pm');
    my $src = $is_obvius ? '' : '_src';

    my $msgmerge_exe = qx{which msgmerge};
    die "Could not find msgmerge executable" unless($msgmerge_exe);
    $msgmerge_exe =~ s{\s+}{}s;

    my $msginit_exe = qx{which msginit};
    die "Could not find msginit executable" unless($msginit_exe);
    $msginit_exe =~ s{\s+}{}s;

    my $msgcat_exe = qx{which msgcat};
    die "Could not find msgcat executable" unless($msgcat_exe);
    $msgcat_exe =~ s{\s+}{}s;

    foreach my $dname (sort keys %dirs) {
        my ($lang) = ($dname =~ m{/(\w\w|\w\w_\w\w)$});
        next unless($lang);
        my $fname = $dname . '/LC_MESSAGES/' . $domain . $src . '.po';
        if(-f $fname) {

            print STDERR "Updating translation file $fname\n";

            system(
                $msgmerge_exe,
                '--no-location',
                "--no-fuzzy-matching",
                "--backup=simple",
                "--update",
                "--sort-output",
                $fname,
                $base_dir . '/i18n/combined.pot'
            ) && die "msgmerge command failed";
        } else {

            print STDERR "Creating new translation file $fname\n";

            File::Path::make_path(File::Basename::dirname($fname));

            system(
                $msginit_exe,
                "--no-translator",
                "-i", $base_dir . '/i18n/combined.pot',
                "-o", $fname,
                # Woraround for initial values being copied to english .po
                # files
                "-l", 'xx_XX'
            ) && die "msginit command failed";
            # Fixup character set in header
            open(FH, $fname);
            my $content = Obvius::CharsetTools::mixed2utf8(join("", <FH>));
            close(FH);
            $content =~ s{("Language: )xx_XX}{$1$lang}gs;
            open(FH, ">$fname");
            print FH $content;
            close(FH);
        }
    }
    sort_translations($base_dir, $domain);
    build($base_dir, $domain, $obvius_dir);
}

sub build {
    my ($base_dir, $domain, $obvius_dir) = @_;

    die "No domain specified" unless($domain);

    my $msgcat_exe = qx{which msgcat};
    die "Could not find msgcat executable" unless($msgcat_exe);
    $msgcat_exe =~ s{\s+}{}s;

    my $msgfmt_exe = qx{which msgfmt};
    die "Could not find msgfmt executable" unless($msgfmt_exe);
    $msgfmt_exe =~ s{\s+}{}s;

    my %dirs = map { $_ => 1 } (
        $base_dir . '/i18n/da_DK',
        $base_dir . '/i18n/en_US',
        grep { -d $_ } glob($base_dir . '/i18n/*'),
    );

    foreach my $dname (sort keys %dirs) {
        my ($lang) = ($dname =~ m{/(\w\w|\w\w_\w\w)$});
        next unless($lang);
        my $fname = $dname . '/LC_MESSAGES/' . $domain . '_src.po';

        my $final_file;
        my @files = ($fname);
        if($obvius_dir) {
            push(@files,
                "${obvius_dir}/i18n/${lang}/LC_MESSAGES/dk.obvius.po"
            );
        }
        @files = grep { -f $_ } @files;

        next unless(@files);

        $final_file = $dname . '/LC_MESSAGES/' . $domain . '.po';

        print STDERR "\nMerging files\n" .
            "  " . join("\n  ", @files) . "\n" .
            "into file\n" .
            "  $final_file\n\n";

        system(
            $msgcat_exe,
            '-t', 'UTF-8',
            '-o', $final_file,
            '--no-location',
            '--use-first',
            '--sort-output',
            @files
        );

        my $mo_file = $final_file;
        $mo_file =~ s{\.po$}{.mo};
        print STDERR "Creating $mo_file from $final_file\n";
        system($msgfmt_exe, '-o', $mo_file, $final_file);
    }
}

sub sort_translations {
    my ($base_dir, $domain) = @_;

    die "No domain specified" unless($domain);

    my $msgcat_exe = qx{which msgcat};
    die "Could not find msgcat executable" unless($msgcat_exe);
    $msgcat_exe =~ s{\s+}{}s;

    my %dirs = map { $_ => 1 } (
        $base_dir . '/i18n/da_DK',
        $base_dir . '/i18n/en_US',
        grep { -d $_ } glob($base_dir . '/i18n/*'),
    );

    my $postfix = $domain eq 'dk.obvius' ? '.po' : '_src.po';
    
    foreach my $dname (sort keys %dirs) {
        my $fname = $dname . '/LC_MESSAGES/' . $domain . $postfix;
        next unless(-f $fname);
        my $sorted_fname = $fname . ".sorted";
        my ($lang) = ($dname =~ m{/(\w\w|\w\w_\w\w)$});
        next unless($lang);
        system(
            $msgcat_exe,
            '-t', 'UTF-8',
            '-o', $sorted_fname,
            '--no-location',
            '--use-first',
            '--sort-output',
            $fname
        ) && die "msgcat command failed";
        system("mv", $sorted_fname, $fname) && die "mv command failed";
    }
}

1;
