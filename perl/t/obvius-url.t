#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use Test::Exception;

# Load mock module
require_ok("Obvius::Test::MockModule::Obvius");

# Enable mocking
Obvius::Test::MockModule::Obvius->mock;
ok(Obvius::Test::MockModule::Obvius->is_mocked, "Mocking of Obvius module enabled");

# Instantiate
my $obvius = Obvius->new;
ok($obvius, "Obvius object created");

# Load module
require_ok("Obvius::URL");

# Creating an URL should die if no Obvius object has been set
dies_ok { Obvius::URL->obvius } "Die if Obvius has not been set";

Obvius::URL->set_obvius($obvius);
ok(Obvius::URL->obvius, "Obvius available on Obvius::URL after setting it");

# Make Obvius go out of scope and check that reference gets lost
undef $obvius;
dies_ok { Obvius::URL->obvius } "Obvius object reference removed when out of scope";

# Test setting Obvius object using confname
Obvius::URL->set_obvius("test");
ok(Obvius::URL->obvius, "Obvius set using configname");

# Test docid format translation
my $from_existing_docid = Obvius::URL->new("/7.docid?query=string#fragment");
is(
    $from_existing_docid->obvius_path,
    "/subsite/subsite-without-domain-under-subsite/standard/",
    "Docid-URL: Obvius path OK"
);
is($from_existing_docid->querystring, 'query=string', "Docid-URL: Querystring OK");
is($from_existing_docid->fragment, 'fragment', "Docid-URL: Fragment OK");
is($from_existing_docid->docid, 7, "Docid-URL: Docid OK");
is($from_existing_docid->public_hostname, "subsite.obvius.test", "Docid-URL: Public hostname OK");
is($from_existing_docid->scheme, "https", "Docid-URL: Scheme OK");
is($from_existing_docid->admin_url, "https://obvius.test/admin/subsite/subsite-without-domain-under-subsite/standard/?query=string#fragment", "Docid-URL: Admin URL OK");
is($from_existing_docid->resolved_path, "/subsite/subsite-without-domain-under-subsite/standard/", "Docid-URL: Resolved path");

# Test docid format if no matching doc exists
my $from_nonexisting_docid = Obvius::URL->new("/9999999.docid?query=string#fragment");
is(
    $from_nonexisting_docid->obvius_path,
    undef,
    "Docid-URL (non-match): Obvius path OK"
);
is($from_nonexisting_docid->querystring, 'query=string', "Docid-URL (non-match): Querystring OK");
is($from_nonexisting_docid->fragment, 'fragment', "Docid-URL (non-match): Fragment OK");
is($from_nonexisting_docid->docid, 9999999, "Docid-URL (non-match): Docid OK");
is($from_nonexisting_docid->public_hostname, undef, "Docid-URL (non-match): Public hostname OK");
is($from_nonexisting_docid->scheme, undef, "Docid-URL (non-match): Scheme OK");
is($from_nonexisting_docid->admin_url, "/9999999.docid?query=string#fragment", "Docid-URL (non-match): Admin URL OK");

is(Obvius::URL->new("/subsite/")->docid, 2, "Resolve from public path");
is(Obvius::URL->new("/admin/subsite/")->docid, 2, "Resolve from admin path");
is(Obvius::URL->new("https://subsite.obvius.test/")->docid, 2, "Resolve from hostname and path");
is(Obvius::URL->new("https://subsite.obvius.test/standard/")->docid, 3, "Resolve from hostname and sub-path");

is(Obvius::URL->new("/subsite/")->admin_path, "/admin/subsite/", "Admin path with ending slash");
is(Obvius::URL->new("/subsite/")->admin_path(1), "/admin/subsite", "Admin path without ending slash");

is(Obvius::URL->new("https://obvius.test/subsite/")->admin_path, "/admin/subsite/", "Admin path from full URL with roothost");

done_testing();
