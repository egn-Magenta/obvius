#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use Test::Exception;
use Data::Dumper;

# Load mock module
require_ok("Obvius::Test::MockModule::Obvius");

# Enable mocking
Obvius::Test::MockModule::Obvius->mock;
ok(Obvius::Test::MockModule::Obvius->is_mocked, "Mocking of Obvius module enabled");

# Instantiate
my $obvius = Obvius->new;
ok($obvius, "Obvius object created");

# Check enabling of cache
$obvius->cache(1);
ok($obvius->{CACHE}, "Obvius cache enabled");

# Check fetching obvius by ID
my $doc  = $obvius->get_doc_by_id(2);
ok($doc, "Can fetch document with id");
ok(ref($doc) eq "Obvius::Document", "Document is an Obvius::Document object");

# Check if documents are cached, so same object is returned for the same
# criteria.
$doc->param("has_been_changed_during_test" => 1);
ok($obvius->get_doc_by_id(2)->param("has_been_changed_during_test"),
    "Documents are cached by fetch criteria");

# Lookup document
is($obvius->lookup_document("/subsite/")->Id, 2, '$obvius->lookup_document');

# Get version
my $versions = $obvius->get_versions($obvius->get_doc_by_id(1));
ok($versions && $versions->[0]->param('id') == 1, '$obvius->get_versions');

# public_versions stored on cached document object
my $root_doc = $obvius->get_doc_by_id(1);
$obvius->get_public_versions($root_doc);
my $public_versions = $obvius->get_doc_by_id(1)->param("public_versions");
ok($public_versions &&
   $public_versions->[0] &&
   ref($public_versions->[0]) eq "Obvius::Version",
   "Public versions stored on cached document object"
);

# public_version (singular) stored on cached document object
$obvius->get_public_version($root_doc);
my $public_version = $obvius->get_doc_by_id(1)->param("public_version");
ok($public_version->param("docid") == 1 &&
    $public_version->param("public") == 1,
    "Public version (singular) stored on cached document object"
);

# ordering versions
$versions = $obvius->get_versions($root_doc, '$order' => "version");
my $first_version = ($versions || [])->[0];
ok($first_version, "ASC ordered versions produces result");

is($first_version->Version, "2007-02-16 16:45:13",
    'ASC ordered version correct version');

$versions = $obvius->get_versions($root_doc, '$order' => "version DESC");
$first_version = ($versions || [])->[0];
ok($first_version, "DESC ordered versions produces result");

is($first_version->Version, "2020-01-01 00:00:00",
    'DESC ordered version correct version');

# Check latest version
my $latest_version = $obvius->get_latest_version($root_doc);
ok($latest_version && $latest_version->Version eq "2020-01-01 00:00:00",
    '$obvius->latest_version');

# Check fetching fields
is($obvius->get_version_field($public_version, "title"),
    'Frontpage',
    '$obvius->get_version_field');

# Check that number of fields is correct.
is(scalar(keys %{$obvius->get_version_fields($public_version, 255) || {}}),
    34,
    '$obvius->get_version_fields'
);

# Adding new content
is($obvius->lookup_document("/test-create-document/"),
    undef,
    "Test document does not exist before creation.");

Obvius::Test::MockModule::Obvius::_add_full_document_with_defaults(
    "/test-create-document/", #path
    "2020-01-01 00:00:00", # version, defaulting to "now"
    2, # doctype-id
    # vfields
    {
        title => "Document created during test",
        short_title => "Creation-test-document"
    },
);

# Adding new content
my $created_doc = $obvius->lookup_document("/test-create-document/");
ok($created_doc, "Created document exists after creation");

my $created_vdoc = $obvius->get_public_version($created_doc);
is($created_vdoc && $created_vdoc->Version,
    "2020-01-01 00:00:00",
    "Created version exists after creation");

is($obvius->get_version_field($created_vdoc, 'title'),
    "Document created during test",
    "Vfield exists after creation");

Obvius::Test::MockModule::Obvius::_add_version(
    $created_doc->Id, "2020-01-02 00:00:00", 2
);
my $created_vdoc_2 = $obvius->get_latest_version($created_doc);
is($created_vdoc_2 && $created_vdoc_2->Version,
    "2020-01-02 00:00:00",
    "Obvius::Test::MockModule::Obvius::_add_version"
);

Obvius::Test::MockModule::Obvius::_add_vfield(
    $created_vdoc_2->DocId, $created_vdoc_2->Version,
    title => "Title added during test"
);
is($obvius->get_version_field($created_vdoc_2, "title"),
    "Title added during test",
    "Obvius::Test::MockModule::Obvius::_add_vfield");

Obvius::Test::MockModule::Obvius::_add_vfields(
    $created_vdoc_2->DocId, $created_vdoc_2->Version,
    { short_title => "Short title from test" }
);
is($obvius->get_version_field($created_vdoc_2, "short_title"),
    "Short title from test",
    "Obvius::Test::MockModule::Obvius::_add_vfields");

done_testing();