#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use Test::Exception;

use Obvius::Data;

my $store_table = "_test_store_table_$$";
my $ref_table = "_test_store_ref_table_$$";
my $expire_time = 3600;

my %values = (
    string_value => "Testvalue 1",
    multiline_value => "Testvalue 2:\nMultiline value\n",
    binary_value => "Testvalue 3: With binary data " .
                    "\x52\xee\x9c\xfe\xbf\xf7\xc8\x73".
                    "\xd1\xb7\x2d\x6b\x07\x27",
    integer_value => 666,
    complex_object => Obvius::Data->new(
        some => "data",
        key => "value",
    ),
);
# Total number of values
my $nr_values = scalar(keys %values);
# The number of docids we want to fetch into the map
my $docid_limit = 10;
# map of docids, to be filled out later
my %docid_map;

# Whether to clean up tables if the script crashes
my $need_cleanup = 0;

if(!$ENV{OBVIUS_CONFNAME}) {
    plan skip_all => "No OBVIUS_CONFNAME set in environment";
    exit(0)
}

# Make sure module loads
require_ok("Obvius");
require_ok("Obvius::Config");
require_ok('WebObvius::Cache::DocumentbasedKeyValueCache');

my $config = Obvius::Config->new($ENV{OBVIUS_CONFNAME});
ok($config, "Create config instance OK");
my $obvius = Obvius->new($config);
ok($obvius, "Create obvius instance OK");

lives_ok {
    %docid_map = get_docid_map()
} 'Fetching real docids ok';

is(scalar(keys %docid_map), $docid_limit, 'Got correct number of docids');

# Eval implementation of a subclass that uses the main module but
# does not implement the required methods. This is done by eval'ing
# a string with the package declarion inside a { ... } block so
# we do not pollute the current namespace. Eval is neccessary to make
# the creation of the package happen at runtime so it is possible to
# check whether the subclassing succeeds or not.
eval qq|{
    package UnimplementedTestDbKvCache;

    use base 'WebObvius::Cache::DocumentbasedKeyValueCache';

    1;
}|;
is($@, '', "Create an unimplemented cache subclass");

my $unimp_instance = UnimplementedTestDbKvCache->new($obvius);
ok($unimp_instance, "Unimplemented instance created OK");

# List of methods that should be implemented and must fail
# if not implemented.
my @implemented_methods = qw(
    store_tablename
    ref_tablename
    expire_time_in_seconds
    get_migration_statements
    get_reverse_migration_statements
);

foreach my $method (@implemented_methods) {
    dies_ok {
        $unimp_instance->$method
    } "Uninplemented method ${method} dies"
}

# Eval another subclass definition, this time with the correct
# methods implemented via some string interpolation. Again eval
# is used to make it possible to check if the declaration of the
# package went ok.
eval qq|{
    package TestDbKvCache;

    use base 'WebObvius::Cache::DocumentbasedKeyValueCache';

    sub store_tablename { '${store_table}' }
    sub ref_tablename { '${ref_table}' }
    sub expire_time_in_seconds { ${expire_time} }

    1;
}|;
is($@, '', "Create a fully implemented cache subclass");

my $instance = TestDbKvCache->new($obvius);
ok($instance, "Create implemented instance");

foreach my $method (@implemented_methods) {
    lives_ok {
        $instance->$method
    } "Method ${method} ok in implemented instance"
}

lives_ok {
    foreach my $statement ($instance->get_migration_statements) {
        $obvius->dbh->do($statement);
    }
} 'Forward migration ok';

# Flag that we should clean up if something goes wrong
$need_cleanup = 1;

foreach my $key (sort keys %values) {
    my $value = $values{$key};
    lives_ok {
        $instance->set_value($key, $value);
    } "Insert $key ok";
}

is(count_entries(), $nr_values, "Row count is $nr_values after inserting entries");

foreach my $key (sort keys %values) {
    my $value = $values{$key};
    my $stored_value = $instance->get_value($key);
    is_deeply($stored_value, $value, "Stored value for $key matches original");
}

foreach my $key (sort keys %values) {
    my $new_value = "Updated value for $key";
    lives_ok {
        $instance->set_value($key, $new_value);
    } "Update value for $key ok";
    is_deeply($instance->get_value($key), $new_value, "New value for $key is ok");
}

lives_ok { expire_all_entries() } 'Expired all entries ok';

foreach my $key (sort keys %values) {
    my $stored_value = $instance->get_value($key);
    is($stored_value, undef, "Stored value for $key is undef after expiration");
}

is(count_entries(), 0, 'Row count is zero after expiring entries');

insert_all_entries();

is($instance->cleanup, 0, 'Zero rows to clean up when nothing is expired');

expire_all_entries();

is($instance->cleanup, $nr_values, "$nr_values rows to clean up after expiring everything");

my $docid_index = 0;
my $docid;
foreach my $key (sort keys %values) {
    my $value = $values{$key};
    $docid = $docid_map{$docid_index};
    $docid_index++;
    lives_ok {
        $instance->set_value($key, $value, $docid);
    } "Inserting $key with docid ref $docid ok";
}

is(
    count_refs(),
    $nr_values,
    "Ref count is $nr_values after inserting with refs"
);

my $first_key = (sort keys %values)[0];

lives_ok {
    my $value = $values{$first_key};
    $instance->set_value($first_key, $value, $docid);
} "Adding extra docid $docid to $first_key ok";

# We should now have $nr_values + 1 references in the database:
# First and last docid pointing to the value for the first key
# and one docid pointing to the rest of the values.
is(
    count_refs(),
    $nr_values + 1,
    "Ref count is " . ($nr_values + 1) . ' after adding an extra'
);

# Second docid points to the value for the second key and only
# to the second key.
my $second_docid = $docid_map{1};
lives_ok {
    $instance->flush_by_docids($second_docid);
} "Flushing for docid $second_docid ok";

is(
    count_refs(),
    $nr_values,
    "Ref count is $nr_values after flushing docid $second_docid"
);
is(
    count_entries(),
    $nr_values - 1,
    'Entry count is ' . ($nr_values - 1) . " after flushing docid $second_docid"
);

# Flush for current docid, which should be referencing both the first and the
# last key.
lives_ok {
    $instance->flush_by_docids($docid);
} "Flushing docid $docid ok";

# Check that we have flushed three references: One for the last key
# and two for the first key, which is reference both by its own
# docid and the current docid in $docid.
is(
    count_refs(),
    $nr_values - 3,
    'Ref count is ' . ($nr_values - 3) . " after flushing docid $docid"
);
is(
    count_entries(),
    $nr_values - 3,
    'Entry count is ' . ($nr_values - 3) . " after flushing docid $docid"
);

lives_ok {
    $instance->flush_all
} 'Flush everything ok';

is(
    count_refs(),
    0,
    'Ref count is 0 after flushing everything'
);
is(
    count_entries(),
    0,
    'Entry count is 0 after flushing everything'
);

my @path_docids = get_deep_path_docids();
my $outside_tree_docid = get_docid_outside_tree($path_docids[0]);

# Insert one value and make sure it is referenced by all docids
# in the path
foreach my $docid (@path_docids) {
    $instance->set_value("Key for path", "Some value", $docid);
}
# Set one other key with a reference from outside the three under
# the first document in the path.
$instance->set_value("Key outside path", "Value outside path", $outside_tree_docid);

my $total_refs = scalar(@path_docids) + 1;

is(
    count_refs(),
    $total_refs,
    "Ref count is $total_refs after preparing recursive flush"
);
is(
    count_entries(),
    2,
    'Entry count is 2 after preparing recursive flush'
);

lives_ok {
    $instance->flush_by_docids_recursive($path_docids[0]);
} "Flushing recursive for docid $path_docids[0] ok";

is(
    count_refs(),
    1,
    'Ref count is 1 after recursive flush'
);
is(
    count_entries(),
    1,
    'Entry count is 1 after recursive flush'
);

is($instance->get_value('Key for path'),
   undef,
   "No value for path after flush");

is($instance->get_value('Key outside path'),
   "Value outside path",
   "Value outside path ok after flush");

$instance->flush_all;

# Insert values using a callback and the get_or_insert_value method,
# counting the number of times the callback is called.
my $callback_count = 0;
foreach my $key (sort keys %values) {
    my $value = $values{$key};
    my $callback = sub {
        $callback_count++;
        return $value;
    };
    my $result = $instance->get_or_insert_value($key, $callback);
    is_deeply($result, $value, "get_or_insert_value for $key ok");
}
is(count_entries(), $nr_values, 'Correct number of entries after callback insert');
is($callback_count, $nr_values, 'Callback method called correct number of times');

# Do the same thing again, this should not increase callback counts.
# Also have the callback return another value than before. It is
# expected to get the old value rather than the one returned by
# the callback.
foreach my $key (sort keys %values) {
    my $value = $values{$key};
    my $callback = sub {
        $callback_count++;
        return "Changed! " . $value;
    };
    my $result = $instance->get_or_insert_value($key, $callback);
    is_deeply($result, $value, "get_or_insert_value for $key (second time) ok");
}
is(count_entries(), $nr_values, 'Correct number of entries after re-insert');
is($callback_count, $nr_values, 'Correct number of callbacks after re-insert');

# Check that there are no docid refs in the recently flushed store
is(count_refs(), 0, 'No refs after get_or_insert_value insertions ok');

# Now check that we can add docid references with get_or_insert_value
$docid_index = 0;
foreach my $key (sort keys %values) {
    my $callback = sub { $values{$key} };
    my $docid = $docid_map{$docid_index};
    my $result = $instance->get_or_insert_value($key, $callback, $docid);
}
is(count_refs(), $nr_values, 'Refs added with get_or_insert_value ok');


lives_ok {
    foreach my $statement ($instance->get_reverse_migration_statements) {
        $obvius->dbh->do($statement);
    }
} 'Reverse migration ok';

# TODO: get_value but add ref


# Cleanup is no longer neccessary
$need_cleanup = 0;

done_testing();


# Finds the deepest path in the database and returns all the docids
# it consists of minus the root document, in docid order.
sub get_deep_path_docids {
    my @result;

    my $sth = $obvius->dbh->prepare(
        "select child from path_tree order by depth desc, id limit 1"
    );
    $sth->execute();
    my ($docid) = $sth->fetchrow_array;

    if(!$docid) {
        return @result;
    }

    my $parent_sth = $obvius->dbh->prepare(
        'select parent from documents where id = ?'
    );

    while($docid && $docid != 1) {
        push(@result, $docid);
        $parent_sth->execute($docid);
        ($docid) = $parent_sth->fetchrow_array;
    }

    return @result;
}

# Returns a document that is outside the paths leading to the specified
# docid.
sub get_docid_outside_tree {
    my ($docid) = @_;

    my $sth = $obvius->dbh->prepare(q|
        select
            documents.id
        from
            documents
            left join
            path_tree on (
                documents.id = path_tree.child
                AND
                path_tree.parent = ?
            )
        where
            path_tree.parent IS NULL
    |);
    $sth->execute($docid);
}

sub count_entries {
    my $sth = $obvius->dbh->prepare(
        "select count(1) from `${store_table}`"
    );
    $sth->execute;
    my ($row_count) = $sth->fetchrow_array;

    return $row_count;
}

sub count_refs {
    my $sth = $obvius->dbh->prepare(
        "select count(1) from `${ref_table}`"
    );
    $sth->execute;
    my ($row_count) = $sth->fetchrow_array;

    return $row_count;
}

# Methods used in the above
sub insert_all_entries {
    foreach my $key (sort keys %values) {
        my $value = $values{$key};
        $instance->set_value($key, $value);
    }
}

sub expire_all_entries {
    my $two_durations_ago = $expire_time * 2;
    $obvius->dbh->do(qq|
        update `${store_table}`
        set expires = DATE_SUB(
            expires,
            INTERVAL $two_durations_ago SECOND
        )
    |);
}

sub get_docid_map {
    my $sth = $obvius->dbh->prepare(
        'select id from documents order by id limit ' . $docid_limit
    );
    $sth->execute;
    my %map;
    my $index = 0;
    while (my ($id) = $sth->fetchrow_array) {
        $map{$index++} = $id;
    }

    return %map;
}

# Perform cleanup at the end to ensure no database tables are left over
# after the test.
END {
    if($need_cleanup && $obvius && $obvius->dbh && $instance) {
        my @statements = eval { $instance->get_reverse_migration_statements };
        if(@statements && $statements[0]) {
            foreach my $statement (@statements) {
                eval { $obvius->dbh->do($statement) };
                warn $@ if($@);
            }
        }
    }
}
