package Obvius::Test::MockModule::Obvius;

use strict;
use warnings;
use utf8;

use base 'Obvius::Test::MockModule';
use Data::Dumper;
use Obvius::Test::MockModule::Obvius::Hostmap;

use constant {
    ADMIN_USER_ID => 1,
    ADMIN_GROUP_ID => 1
};

sub mockclass { "Obvius" }

sub mock {
    my ($self) = @_;

    Obvius::Test::MockModule::Obvius::Hostmap->mock;
    $self->SUPER::mock();
}

sub unmock {
    my ($self) = @_;

    Obvius::Test::MockModule::Obvius::Hostmap->unmock;
    $self->SUPER::unmock();
}

sub _get_by {
    my ($list, %filters) = @_;

    ITEMS: foreach my $item (@$list) {
        foreach my $key (keys %filters) {
            # Test all filters and skip to next item if something does not match
            my $value = $filters{$key};
            if (defined($value)) {
                if (!$item->{$key} || $item->{$key} ne $value) {
                    next ITEMS;
                }
            } else {
                if (!defined($item->{$key})) {
                    next ITEMS;
                }
            }
        }
        # All filters matched this item, return it.
        return $item;
    }
}

sub _filter_by {
    my ($list, %filters) = @_;

    my @result;
    my %meta;

    foreach my $key (keys %filters) {
        $meta{$key} = $filters{$key};
    }

    my @items = @$list;
    if ($meta{'$order'}) {
        my ($field, $direction) = split(/ /, $meta{'$order'});
        @items = sort {$a->{$field} <=> $b->{$field}} @items;
        if ($direction eq 'DESC') {
            @items = reverse(@items);
        }
    }

    ITEMS: foreach my $item (@items) {
        foreach my $key (keys %filters) {
            if (!($key =~ /^\$/)) {
                # Test all filters and skip to next item if something does not match
                my $value = $filters{$key};
                if (!$item->{$key} || $item->{$key} ne $value) {
                    next ITEMS;
                }
            }
        }
        # All filters matched this item, return it.
        push(@result, $item);
        if ($meta{'$max'} && $meta{'$max'} <= scalar(@result)) {
            last;
        }
    }

    return @result;
}

my @users = (
    {
        'deactivated' => undef,
        'notes' => '',
        'id' => ADMIN_USER_ID,
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
my @groups = (
    {
        'id' => ADMIN_GROUP_ID,
        'name' => 'Admin'
    },
    {
        'id' => 2,
        'name' => 'Group2'
    }
);
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

my @documents = (
    {
        id => 1,
        parent => 0,
        name => "dummy",
        owner => ADMIN_USER_ID,
        grp => ADMIN_GROUP_ID,
        accessrules => q|admin=create,edit,delete,publish,modes
OWNER=create,edit,delete,publish,modes
GROUP+create,edit,delete,publish
ALL+view|,
        path => "/",
    }
);
my $documents_seq = 1;

sub _lookup_document {
    my ($path) = @_;

    if(!$path) {
        return;
    }

    my $current = _get_by(\@documents, id => 1);
    my @path = grep { $_ } split(m{/}, $path);
    foreach my $path_part (@path) {
        $current = _get_by(\@documents, PARENT => $current->{id} || $current->{ID}, NAME => $path_part);
        if(!$current) {
            return;
        }
    }

    return $current;
}

sub _add_document {
    my ($path, $owner_id, $group_id, $accessrules) = @_;

    my $name;
    my $parent_path = $path || '';
    $parent_path =~ s{/([^/]+)/$}{/};
    $name = $1;

    my $parent = _lookup_document($parent_path);
    die "No parent" unless($parent);

    my $doc = Obvius::Document->new({
        id => ++$documents_seq,
        parent => $parent->{"id"} || $parent->{"ID"},
        name => $name,
        owner => $owner_id,
        grp => $group_id,
        accessrules => $accessrules,
    });

    push(@documents, $doc);

    my $p = _get_path_by_docid($doc->Id);
    $doc->param('path', $p);

    return $doc;
}

_add_document('/subsite/', ADMIN_USER_ID, ADMIN_GROUP_ID, '');
_add_document('/subsite/standard/', ADMIN_USER_ID, ADMIN_GROUP_ID, '');
_add_document('/subsite-without-domain/', ADMIN_USER_ID, ADMIN_GROUP_ID, '');
_add_document('/subsite-without-domain/standard/', ADMIN_USER_ID, ADMIN_GROUP_ID, '');
_add_document('/subsite/subsite-without-domain-under-subsite/', ADMIN_USER_ID, ADMIN_GROUP_ID, '');
_add_document('/subsite/subsite-without-domain-under-subsite/standard/', ADMIN_USER_ID, ADMIN_GROUP_ID, '');

sub _get_path_by_docid {
    my ($docid) = @_;

    my $current = _get_by(\@documents, ID => $docid);
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

my @subsites = (
    {
        'id' => 1,
        'responsive' => 0,
        'user_id' => ADMIN_USER_ID,
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
        'user_id' => ADMIN_USER_ID,
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
        'user_id' => ADMIN_USER_ID,
        'title' => 'Subsite 3 (/subsite/subsite-without-domain-under-subsite/)',
        'lang' => 'da',
        'own_leftmenu' => 1,
        'use_bootstrap' => 0,
        'domain' => undef,
        'root_docid' => _lookup_document("/subsite/subsite-without-domain-under-subsite/")->{id},
    },
);

sub get_all_subsites { return @subsites }

### Actual mocked methods starts here ###

sub new { return bless({obvius_mockup_object => 1}, "Obvius") }

sub get_doc_by_id {
    my ($self, $docid) = @_;
    my $res = _get_by(\@documents, id => $docid);

    if($res) {
        return Obvius::Document->new($res);
    }
}

sub get_doc_uri {
    my ($self, $doc) = @_;

    return _get_path_by_docid($doc->Id);
}

my $config;

sub config {
    my ($self) = @_;
    return $config if($config);

    $config = bless({
        ROOTHOST => 'obvius.test',
        ROOTHOST => 'obvius.test',
        https_roothost => 'ssl.obvius.test',
        ALWAYS_HTTPS => 1,
    }, "Obvius::Config");

    $config->param(hostmap => Obvius::Hostmap->new_with_obvius($self));

    return $config;
}

sub lookup_document {
    my ($self, $path) = @_;
    return _lookup_document($path);
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

    my @versions = values(%{$doc->versions});

    if (scalar(@versions)) {
        @versions = _filter_by(\@versions, %options);
        return \@versions;
    }
}

sub get_version_fields {
    my ($this, $version, $threshold, $type) = @_;
    return $version->fields($type);
}

1;
