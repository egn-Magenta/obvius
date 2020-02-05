package Obvius::Test::MockModule::Obvius;

use strict;
use warnings;
use utf8;

use Data::Dumper;
use Obvius::Test::MockModule::Obvius::Hostmap;

# Load the module we're mocking to make sure we have all
# its dependencies.
use Obvius;

use base 'Obvius::Test::MockModule';

our $ADMIN_USER_ID = 1;
our $ADMIN_GROUP_ID = 1;

sub mockclass { "Obvius" }

# Enable mocking for Obvius and its dependencies
sub mock {
    my ($self) = @_;

    Obvius::Test::MockModule::Obvius::Hostmap->mock;
    $self->SUPER::mock();
}

# Disable mocking for Obvius and its dependencies
sub unmock {
    my ($self) = @_;

    Obvius::Test::MockModule::Obvius::Hostmap->unmock;
    $self->SUPER::unmock();
}

# Get a single item from a list using filter criteria
sub _get_by {
    my ($list, %filters) = @_;

    my @items = _filter_by($list, '$max' => 1, %filters);

    return $items[0];
}

=pod
=begin text
Get multiple items from a list using filter criteria.
Criteria can be:

  A simple key value pair:

    title => "My title"

    Will match items where $item->{title} equals "My title"

  A list of values:

    title => ["My title", "My other title"]

    Will match items where $item->{title} is in the list
    specified.

  A reference to a method:

    title => sub {
        my $value = shift;
        return $value eq "My title";
    }

    Matches items where the method returns true.
=end
=cut
sub _filter_by {
    my ($list, %filters) = @_;

    my @result;
    my %meta;

    # Fish meta values out of filter
    foreach my $key (keys %filters) {
        if($key =~ m{^\$}) {
            $meta{$key} = $filters{$key};
            delete $filters{$key};
        }
    }

    my @items = @$list;
    if ($meta{'$order'}) {
        my ($field, $direction) = split(/\s+/, $meta{'$order'});
        $direction ||= 'ASC';

        my $has_lexical_values = 0;
        for my $i (@items) {
            if(defined($i->{$field}) && $i->{$field} =~ m{\D+}) {
                $has_lexical_values = 1;
                last;
            }
        }

        # Try to figure out whether to use lexical or
        my $cmp = $has_lexical_values ?
            sub { return $_[0] cmp $_[1] } :
            sub { return $_[0] <=> $_[1] };

        @items = sort { $cmp->($a->{$field}, $b->{$field}) } @items;

        if ($direction eq 'DESC') {
            @items = reverse(@items);
        }
    }

    # Convert fitlers to a list of coderefs we can call
    foreach my $filter_key (keys %filters) {
        my $filter_value = $filters{$filter_key};
        if(ref($filter_value) eq "CODE") {
            # do nothing
        } elsif(ref($filter_value) eq 'ARRAY') {
            # Match any value in the listed array
            $filters{$filter_key} = sub {
                my $value = shift;
                grep { $value eq $_ } @$filter_value;
            };
        } elsif(!ref($filter_value)) {
            if(!defined($filter_value)) {
                $filters{$filter_key} = sub { !defined(shift) }
            } else {
                $filters{$filter_key} = sub { shift eq $filter_value };
            }
        }
    }

    ITEMS: foreach my $item (@items) {
        # Test all filters and skip to next item if something does not match
        foreach my $key (keys %filters) {
            my $filter_method = $filters{$key};
            if(!$filter_method->($item->{$key})) {
                next ITEMS;
            }
        }
        # All filters matched this item, return it.
        push(@result, $item);
        if ($meta{'$max'} && scalar(@result) >= $meta{'$max'}) {
            last;
        }
    }

    return @result;
}

# Default list of users for the in-memory database
my @users = (
    {
        'deactivated' => undef,
        'notes' => '',
        'id' => $ADMIN_USER_ID,
        'is_admin' => 1,
        'can_manage_users' => 2,
        'created' => '2015-03-10 15:19:19',
        'name' => 'Admin',
        'admin' => 1,
        'phoneno' => undef,
        'login' => 'admin',
        'faculty_id' => undef,
        'email' => 'jubk@magenta-aps.dk',
        'can_manage_groups' => 1,
        'faculty' => '',
        'webteam_id' => undef,
        'ku_username' => '',
        'surveillance' => '',
        'created_by' => undef,
        'passwd' => 'Passw0rd!'
    }
);
# Default list of groups for the in-memory database
my @groups = (
    {
        'id' => $ADMIN_GROUP_ID,
        'name' => 'Admin'
    },
    {
        'id' => 2,
        'name' => 'Group2'
    }
);
# Default user/group relations for the in-memory database
my @user_groups = (
    {
        'grp' => _get_by(\@groups, id => 1),
        'user' => _get_by(\@users, id => 1),
    },
    {
        'grp' => _get_by(\@groups, id => 2),
        'user' => _get_by(\@users, id => 1),
    }
);

# Default documents for the in-memory database
my @documents = (
    {
        id => 1,
        parent => 0,
        name => "dummy",
        owner => $ADMIN_USER_ID,
        grp => $ADMIN_GROUP_ID,
        accessrules => q|admin=create,edit,delete,publish,modes
OWNER=create,edit,delete,publish,modes
GROUP+create,edit,delete,publish
ALL+view|,
        path => "/",
    }
);
my $documents_seq = 1;

# Looks up a document data-item, given a path
sub _lookup_document {
    my ($path) = @_;

    if(!$path) {
        return;
    }

    my $current = _get_by(\@documents, id => 1);
    my @path = grep { $_ } split(m{/}, $path);
    foreach my $path_part (@path) {
        $current = _get_by(\@documents, parent => $current->{id}, name => $path_part);
        if(!$current) {
            return;
        }
    }

    return $current;
}

# Adds a new documen to the in-memory database
# Arguments are:
#  path - the path for the created document
#  owner_id - userid of the owner of the document
#  group_id - groupid for the group for the document
#  accessrules - a list of accessrules.
sub _add_document {
    my ($path, $owner_id, $group_id, $accessrules) = @_;

    my $name;
    my $parent_path = $path || '';
    $parent_path =~ s{/([^/]+)/$}{/};
    $name = $1;

    my $parent = _lookup_document($parent_path);
    die "No parent" unless($parent);

    my $doc = {
        id => ++$documents_seq,
        parent => $parent->{"id"} || $parent->{"ID"},
        name => $name,
        owner => $owner_id,
        grp => $group_id,
        accessrules => $accessrules,
    };

    push(@documents, $doc);

    return $doc;
}

# Default versions for the in-memory database
my @versions = (
    {
        id => 1,
        docid => 1,
        version => "2007-02-16 16:45:13",
        type => 2,
        public => 1,
        valid => 1,
        lang => "da",
        user => $ADMIN_USER_ID,
    }
);
my $versions_seq = 1;

# Adds a new version to the in-memory database.
# Arguments are:
#   docid - docid for the version
#   version - version timestamp in "YYYY-MM-DD HH:mm:ss" format
#   doctype_id - doctypeid for the version
#   %options:
#     $option{public} - whether the version should be public.
#                       Default: 0
#     $options{valid} - whether the version is valid
#                       Default: 1
#     $options{lang}  - version language
#                       Default: "da"
#     $options{user}  - userid of the user who created the version
#                       Default: $ADMIN_USER_ID
sub _add_version {
    my ($docid, $version, $doctype_id, %options) = @_;

    my $doc = _get_by(\@documents, id => $docid);
    if(!$doc) {
        die "Trying to add version to non-existent document with id $docid";
    }

    my $version_rec = {
        id => ++$versions_seq,
        docid => $docid,
        version => $version,
        type => $doctype_id,
        public => $options{public} || 0,
        valid => $options{valid} || 1,
        lang => $options{lang} || "da",
        user => $options{user} || $ADMIN_USER_ID,
    };

    push(@versions, $version_rec);

    return $version_rec;
}

# Default vfields for the in-memory database
my @vfields = (
    {
        id => 1,
        docid => $versions[0]->{docid},
        version => $versions[0]->{version},
        name => "title",
        value => "Frontpage"
    },
);
my $vfields_seq = 1;

# Adds a vfield to the in-memory database
# Arguments are:
#  $docid - docid for the vfield
#  $version - version for the vfield
#  $name - name of the vfield
#  $value - value of the vfield
#           Note that this can be specified as an arrayref to
#           support multiple values.
sub _add_vfield {
    my ($docid, $version, $name, $value) = @_;

    my $vfield = {
        id => ++$vfields_seq,
        docid => $docid,
        version => $version,
        name => lc($name),
        value => $value,
    };

    push(@vfields, $vfield);

    return $vfield;
}

# Adds multiple vfields to the in-memory database
# Arguments are:
#  $docid - docid for the vfield
#  $version - version for the vfield
#  vfields, which can be specified in two ways:
#    A list of key-value pairs:
#       field1 => "val1", field2 => "val2" ...
#    A single hashref:
#       { field1 => "val1", field2 => "val2" }
sub _add_vfields {
    my ($docid, $version, @fields) = @_;

    my $fields_count = scalar(@fields);

    if(!$fields_count) {
        return;
    }

    my $fields;

    if($fields_count == 1 && ref($fields[0]) eq "HASH") {
        $fields = $fields[0];
    } elsif($fields_count >= 2 && ($fields_count %2) == 0) {
        $fields = { @fields };
    } else {
        die "Wrong arguments to _add_vfields";
    }

    foreach my $name (keys %$fields) {
        _add_vfield($docid, $version, $name, $fields->{$name});
    }
}

# Creates a document, a public version and vfields all in one go.
# Arguments are:
#   $path - the path for the new document.
#   $version - the version timestamp in "YYYY-MM-DD HH:mm:ss" format.
#              If no value is given, "now" will be used for version
#              timestamp.
#   $doctype_id - the doctypeid of the version created.
#   @vfields - list of vfields. Accepts same formats as the _add_vfields method.
sub _add_full_document_with_defaults {
    my ($path, $version, $doctype_id, @vfields) = @_;

    my $docdata = _add_document($path, $ADMIN_USER_ID, $ADMIN_GROUP_ID, "");
    if(!$docdata) {
        die "Could not make document in _add_full_document";
    }
    $version ||= POSIX::strftime('%Y-%m-%d %H:%M:%S', localtime);
    my $versiondata = _add_version($docdata->{id}, $version, $doctype_id, public => 1);
    if(!$versiondata) {
        die "Could not make version in _add_full_document";
    }
    _add_vfields($versiondata->{docid}, $versiondata->{version}, @vfields);
}

# The next section creates additional default test-data

# Add a new non-public version on the root document
_add_version(1, "2020-01-01 00:00:00", 2, public => 0);

# Add more vfields to the public version of the root document.
_add_vfields(
    $versions[0]->{docid}, $versions[0]->{version},
    {
        AUTHOR => q|carn|,
        CONTENT => "<p>Some HTML content</p>",
        CONTRIBUTORS => q||,
        DOCDATE => q|2006-06-27 00:00:00|,
        DOCREF => q||,
        ENABLE_COMMENTS => q|0|,
        ENHED => q|Kommunikationsafdelingen|,
        ENHED_URL => q|http://www.ku.dk/kommunikation|,
        EXPIRES => q|9999-01-01 00:00:00|,
        FARVEVALG => q||,
        FREE_KEYWORDS => q||,
        KONTAKT_ADRESSE => q|Nørregade 10, DK-1017 KÃ¸benhavn K|,
        KONTAKT_EMAIL => q|cms-support@adm.ku.dk|,
        KONTAKT_NAVN => q|CMS support|,
        KONTAKT_TLF => q||,
        MIMETYPE => q||,
        RIGHTBOXES => q|0:/2.docid|,
        ROBOTSMETA => [q|index,follow|],
        SEQ => q|10|,
        SHORT_TITLE => q|CMS support|,
        SHOW_DATE => q|0|,
        SHOW_NEWS => q|1|,
        SHOW_SUBDOCS => q|0|,
        SHOW_SUBDOC_DATE => q|0|,
        SHOW_SUBDOC_TEASER => q|0|,
        SHOW_TEASER => q|1|,
        SHOW_TITLE => q|0|,
        SORTORDER => q|+seq,+title|,
        SOURCE => q|Obvius|,
        SUBSCRIBEABLE => q|none|,
        UPDATEALERTSENT => q|0|,
        UPDATEALERTTIME => q|0000-00-00 00:00:00|,
        UPDATEALERTUSER => q|admin|,
    }
);

# Add a series of documents used for testing subsites
_add_full_document_with_defaults(
    "/subsite/", undef, 2, {title => "Subsite root",}
);
_add_full_document_with_defaults(
    "/subsite/standard/", undef, 2,
    {title => "Standard document under subsite",}
);
_add_full_document_with_defaults(
    "/subsite-without-domain/", undef, 2,
    {title => "Subsite without domain root",}
);
_add_full_document_with_defaults(
    "/subsite-without-domain/standard/", undef, 2,
    {title => "Standard document under subsite without domain",}
);
_add_full_document_with_defaults(
    "/subsite/subsite-without-domain-under-subsite/", undef, 2,
    {title => "Subsite without domain under another subsite root",
});
_add_full_document_with_defaults(
    "/subsite/subsite-without-domain-under-subsite/standard/", undef, 2,
    {title => "Standard document under subsite without domain under another subsite",}
);

# Given a docid returns the path for the matched document
sub _get_path_by_docid {
    my ($docid) = @_;

    my $current = _get_by(\@documents, id => $docid);
    if(!$current) {
        return undef;
    }
    my @path_parts;
    while($current && $current->{parent}) {
        push(@path_parts, $current->{name} . "/");
        $current = _get_by(\@documents, id => $current->{parent});
    }

    return "/" . join("", reverse(@path_parts));
}

# Default subsites for the in-memory database
my @subsites = (
    {
        'id' => 1,
        'responsive' => 0,
        'user_id' => $ADMIN_USER_ID,
        'title' => 'Subsite 1 (/subsite/)',
        'lang' => 'da',
        'own_leftmenu' => 1,
        'use_bootstrap' => 0,
        'domain' => 'subsite.obvius.test',
        'root_docid' => _lookup_document("/subsite/")->{id},
    },
    {
        'id' => 2,
        'responsive' => 0,
        'user_id' => $ADMIN_USER_ID,
        'title' => 'Subsite 2 (/subsite-without-domain/)',
        'lang' => 'da',
        'own_leftmenu' => 1,
        'use_bootstrap' => 0,
        'domain' => undef,
        'root_docid' => _lookup_document("/subsite-without-domain/")->{id},
    },
    {
        'id' => 3,
        'responsive' => 0,
        'user_id' => $ADMIN_USER_ID,
        'title' => 'Subsite 3 (/subsite/subsite-without-domain-under-subsite/)',
        'lang' => 'da',
        'own_leftmenu' => 1,
        'use_bootstrap' => 0,
        'domain' => undef,
        'root_docid' => _lookup_document("/subsite/subsite-without-domain-under-subsite/")->{id},
    },
);

# Returns a list of all subsites - used by the mock module
# for Obvius::Hostmap.
sub get_all_subsites { return @subsites }

### Actual mocked methods starts here ###

sub new { return bless({obvius_mockup_object => 1}, "Obvius") }

sub get_doc_by {
    my ($this, @how) = @_;

    $this->tracer(@how) if ($this->{DEBUG});

    my $doc = $this->cache_find('Obvius::Document', @how);
    return $doc if ($doc);

    my $rec = _get_by(\@documents, @how);
    if($rec) {
        $doc = new Obvius::Document($rec);

        $this->cache_add($doc);
    }

    return $doc;
}

sub get_doc_uri {
    my ($self, $doc) = @_;

    return _get_path_by_docid($doc->Id);
}

my $config;

# Returns an Obvius::Config object with values corresponding to the
# mockup test environment.
# $config->param("hostmap") will be a mocked-up Obvius::Hostmap
# with the subsites specified in the in-memory database.
sub config {
    my ($self) = @_;
    return $config if($config);

    $config = bless({
        ROOTHOST => 'obvius.test',
        https_roothost => 'ssl.obvius.test',
        ALWAYS_HTTPS => 1,
    }, "Obvius::Config");

    $config->param(hostmap => Obvius::Hostmap->new_with_obvius($self));

    return $config;
}

sub lookup_document {
    my ($self, $path) = @_;

    my $rec = _lookup_document($path);
    return $rec ? Obvius::Document->new($rec) : undef;
}

sub add_document {
    my ($self, $path, $owner_id, $group_id, $accessrules) = @_;
    return _add_document($path, $owner_id, $group_id, $accessrules);
}

sub get_versions {
    my ($this, $doc, %options) = @_;

    if (!(ref $doc and $doc->UNIVERSAL::isa('Obvius::Document'))) {
        die("doc not an Obvius::Document\n");
    }

    my @versions = map {
        Obvius::Version->new($_)
    } _filter_by(\@versions, docid => $doc->Id, %options);

    return @versions ? \@versions : undef;
}

sub get_version_fields_by_threshold {
    my ($self, $version, $threshold, $type) = @_;

    # TODO: We cannot handle thresholds yet => any threshold means ALL FIELDS.
    if(ref($threshold) ne "ARRAY") {
        $threshold = [map {
            $_->{name}
        } _filter_by(
            \@vfields,
            docid => $version->Docid,
            version => $version->Version
        )];
    }

    # Fetch existing fields.
    my $existing = $version->fields($type);
    # If no existing fields exist we need everthing, so return the entire list
    if(!$existing) {
        return $threshold;
    }

    my @needed;
    foreach my $fieldname (@$threshold) {
        if(!exists $existing->{uc($fieldname)}) {
            push(@needed, $fieldname);
        }
    }

    return @needed ? \@needed : undef;
}

sub get_version_fields {
    my ($this, $version, $threshold, $type) = @_;

    $type=(defined $type ? $type : 'FIELDS');

    $this->tracer($version, $threshold||'N/A', $type) if ($this->{DEBUG});

    my $needed = $this->get_version_fields_by_threshold($version, $threshold, $type);
    return $version->fields($type) unless ($needed);

    my $fields = new Obvius::Data;

    # TODO: Once we can mock up fieldtypes we need to add default values.

    my @vfields = _filter_by(
        \@vfields,
        docid => $version->Docid,
        version => $version->Version,
        name => $needed
    );

    foreach my $vfield (@vfields) {
        $fields->param($vfield->{name} => $vfield->{value});
        $version->field($vfield->{name} => $vfield->{value}, $type);
    }

    return $version->fields($type);

}

1;
