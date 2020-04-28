use strict;
use warnings;

use Test::More;

use Obvius::DocType::Image;
use Image::Magick;
use File::Basename;
use File::Path;
use File::Copy;

### To run this test properly, copy images from t/testimages/input to t/testimages
### Otherwise, this test is a no-op
### See image-test job in gitlab-ci for example usage

# Setup folders
my @input_files = glob 't/testimages/*';
@input_files = grep { -f } @input_files; # Filter out directories

my $output_folder = 't/testimages/output';

# Setup tests; fall back to one smoke test if no images are given
my $tests_per_image = 5;
plan tests => scalar @input_files * $tests_per_image + 1;

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
my $geometry = '755x412';

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
    # We re-read input file repeatedly but ignore the error value in subsequent reads
    my ($image, $error) = get_image_object($input_filename);
    ok($error eq '', "Read $input_filename ok");

    # Resize, no compress, no convert
    my $new_image = Obvius::DocType::Image->resize_image($image, $geometry);
    $error = $new_image->Write(filename => $output_resized);
    ok($error eq '', "Write $output_resized ok");
    undef $image;

    # Resize, compress, no convert
    ($image, $error) = get_image_object($input_filename);
    my $new_compressed_image = Obvius::DocType::Image->resize_image($image, $geometry, $quality);
    $error = $new_compressed_image->Write(filename => $output_resized_compressed);
    ok($error eq '', "Write $output_resized_compressed ok");
    undef $image;

    # Resize, compress, convert to gif
    ($image, $error) = get_image_object($input_filename);
    my $new_gif_image = Obvius::DocType::Image->convert_to_gif($image, $geometry);
    $new_gif_image->Set('GIF');
    $error = $new_gif_image->Write(filename => $output_gif);
    ok($error eq '', "Write $output_gif ok");

    return 1;
}

# Convenience method for (re-)reading image from file
sub get_image_object {
    my ($input_filename) = @_;

    my $image = Image::Magick->new();
    my $error = $image->Read($input_filename);
    return ($image, $error);
}

1;