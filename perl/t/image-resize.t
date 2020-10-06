use strict;
use warnings;
use POSIX qw/floor/;

use Test::More;

use Obvius::DocType::Image;
use Obvius::Test::MockModule::Obvius;
use Obvius::Data;
use Image::Magick;
use Image::Size;
use File::Basename;
use File::Path;
use File::Copy;
use File::Compare;

use Data::Dumper;

### To run this test properly, copy images from t/testimages/input to t/testimages
### Otherwise, this test is a no-op
### See image-test job in gitlab-ci for example usage

# Setup folders
my @input_files = glob 't/testimages/*';
@input_files = grep { -f } @input_files; # Filter out directories

# Setup tests; fall back to one smoke test if no images are given
my $tests_per_image = 42;
plan tests => scalar @input_files * $tests_per_image + 3;


Obvius::Test::MockModule::Obvius->mock;
ok(Obvius::Test::MockModule::Obvius->is_mocked, "Mocking of Obvius module enabled");
my $obvius = Obvius->new;
ok($obvius, "Obvius object created");

File::Path::make_path($obvius->config->param('DOCS_DIR'));

my $output_folder = 't/testimages/output';

if (! scalar @input_files) {
    ok(1, 'No input files given; no actual tests have run');
} else {
    # Create or clean-up output folder
    my $errors;
    if (! -d $output_folder) {
        mkpath($output_folder);
    } else {
        while ($_ = glob "$output_folder/*") {
            next if -d;
            unlink or ++$errors;
        }
    }
    ok (!$errors, 'Output folder ready');
}

# Define constants for image quality and size
my $quality = 60;
my $width = 755;
my $height = 412;

foreach (@input_files) {
    ok(test_convert_image($_), "Done converting $_");
}

sub test_convert_image {
    my ($input_filename) = @_;
    my ($file, $dir, $ext) = fileparse($input_filename, '\..*');

    # Backup original file to output
    copy($input_filename, "$output_folder/${file}${ext}");

    # Setup filenames
    my $output_resized = "${output_folder}/${file}_755px${ext}";
    my $output_resized_compressed = "${output_folder}/${file}_755px_q60${ext}";
    my $output_gif = "${output_folder}/${file}_755px.gif";

    # Read input file and test ok
    my ($image, $error) = get_image_object($input_filename);
    ok($error eq '', "Read $input_filename ok");

    # Resize, no compress, no convert
    my $new_image = $image->Clone();
    $new_image = Obvius::DocType::Image->resize_image($image, $width, $height);
    $error = $new_image->Write(filename => $output_resized);
    ok($error eq '', "Write $output_resized ok");

    # Resize, compress, no convert
    my $new_compressed_image = $image->Clone();
    $new_compressed_image = Obvius::DocType::Image->resize_image($image, $width, $height, $quality);
    $error = $new_compressed_image->Write(filename => $output_resized_compressed);
    ok($error eq '', "Write $output_resized_compressed ok");

    # Do a binary comparison of output images (compare returns 0 if equal)
    my $exists_diff_compressed_nocompressed = compare($output_resized, $output_resized_compressed) != 0;
    my $mimetype = $image->Get('mime');
    if ($mimetype ne 'image/jpeg') {
        ok(!$exists_diff_compressed_nocompressed, "$mimetype skipped compression");
    } else {
        ok($exists_diff_compressed_nocompressed, 'Jpg file did compression');
    }


    # Resize, compress, convert to gif
    my $new_gif_image = $image->Clone();
    $new_gif_image = Obvius::DocType::Image->convert_to_gif($image, $width, $height);
    $new_gif_image->Set('GIF');
    $error = $new_gif_image->Write(filename => $output_gif);
    ok($error eq '', "Write $output_gif ok");




    # Resizing with the Image doctype, which whitelists possible sizes
    my $docs_folder = $obvius->config->param('DOCS_DIR');
    File::Path::make_path("$docs_folder/upload/test/");
    my $doc_filename = "/upload/test/${file}${ext}";
    copy($input_filename, "$docs_folder$doc_filename");
    my ($documentdata, $versiondata, $vfields) = Obvius::Test::MockModule::Obvius::_add_full_document_with_defaults(
        "/subsite/standard/imagetest/",
        undef,
        18,
        {
            'ALIGN'=>'center',
            'DOCDATE'=>undef,
            'EXPIRES'=>undef,
            'HEIGHT'=>undef,
            'MIMETYPE'=>$mimetype,
            'SEQ'=>undef,
            'SIZE'=>undef,
            'TITLE'=>"$file.$ext",
            'UPLOADFILE'=>$doc_filename,
            'WIDTH'=>undef,
        }
    );

    my %documenthash = map { uc($_) => $documentdata->{$_} } keys %$documentdata;
    my %versionhash = map { uc($_) => $versiondata->{$_} } keys %$versiondata;
    my $document = bless(\%documenthash, 'Obvius::DocType::Image');
    my $version = bless(\%versionhash, 'Obvius::Version');
    my ($orig_x, $orig_y) = Image::Size::imgsize($input_filename);

    # These conversions are whitelisted - we expect them to carry through
    my %expected_conversions = (
        'navigator'     => [50, 62],
        '50x62'         => [50, 62],
        'icon'          => [55, 55],
        '55x55'         => [55, 55],
        'bootstrapform' => [100, floor($orig_y * (100 / $orig_x))],
        '100x'          => [100, floor($orig_y * (100 / $orig_x))],
        'globalmenu'    => [115, floor($orig_y * (115 / $orig_x))],
        '115x'          => [115, floor($orig_y * (115 / $orig_x))],
        'rightbox'      => [235, floor($orig_y * (235 / $orig_x))],
        '235x'          => [235, floor($orig_y * (235 / $orig_x))],
        'listlayout'    => [755, floor($orig_y * (755 / $orig_x))],
        '755x'          => [755, floor($orig_y * (755 / $orig_x))]
    );

    # These conversions are not whiteslisted - we expect them to fail (ie. return original image)
    for my $other ('20x20', '100x200', '300x', 'x300', '5', 'n') {
        $expected_conversions{$other} = [$orig_x, $orig_y];
    }

    for my $size (keys(%expected_conversions)) {
        my ($exp_x, $exp_y) = @{$expected_conversions{$size}};
        my $input = Obvius::Data->new();
        $input->param(resize => $size);
        my ($m, $data) = $document->raw_document_data($document, $version, $obvius, $input);
        ok($m eq $mimetype, "Document returned correct mime type $mimetype");
        my ($x, $y) = Image::Size::imgsize(\$data);
        ok($x == $exp_x && $y == $exp_y, "Document resized to ${exp_x}x${exp_y} as expected");
    }
    unlink("$docs_folder$doc_filename");

    rmtree("$docs_folder/upload/test");

    return 1;
}


# Convenience method for reading image from file
sub get_image_object {
    my ($input_filename) = @_;
    my $image = Image::Magick->new();
    my $error = $image->Read($input_filename);
    return ($image, $error);
}

1;
