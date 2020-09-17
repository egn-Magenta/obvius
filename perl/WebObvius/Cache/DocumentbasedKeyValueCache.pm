package WebObvius::Cache::DocumentbasedKeyValueCache;

use strict;
use warnings;
use utf8;

use Storable qw(freeze thaw);

# This type of cache works as key/value store that uses mysql to
# store its values. It also allows docids to be associated with
# stored values, making it possible to clear all values associated
# with a given document. This allows editors in Obvius CMS to 
# use existing cache-clearing methods to entries in this cache
# that are related to the document(s) they are working on.
#
# The cache will also ensure that entries expire after a configurable
# interval. Expired entries in the cache will be automatically
# deleted if something tries to retrieve them. The cache will also
# check whether a full expiration time has passed since last cleanup
# each time an item is inserted or fetched from the cache. If the
# expiration time is exceeded the cache will run a cleanup and delete
# all expired items from the cache.
#

sub new {
    my ($class, $obvius, %options) = @_;

    return bless({
        %options,
        obvius => $obvius,
        next_expire_check => 0,
    }, $class);
}

# Configuration methods that should be overridden in subclasses
sub store_tablename { die "You must specify a store tablename" }
sub ref_tablename { die "You must specify a ref tablename" }
sub expire_time_in_seconds { die "You must specify expire_time_in_seconds" }

# Utility methods
sub obvius { $_[0]->{obvius} }

# Implementation of the `find_and_flush` method from Obvius cache
# system. This will flush cache for any docids mentioned in the
# supplied cacheobjects. If a cacheobject is marked with
# `clear_cache_request` and `clear_cache_recursively` the docid
# for that cacheobject will be flushed recursively.
# This means that recusive flushing will only be done when requested
# by an editor via the admin interface. Otherwise the cache will
# only flush single documents.
sub find_and_flush {
    my ($self, $cacheobjects) = @_;

    if(!$cacheobjects) {
        return;
    }

    my @docids;
    my @recursive_docids;
    my $objects = $cacheobjects->{collection} || [];

    foreach my $obj (@$objects) {
        # We only want documents specified by their docid
        if(!$obj->{docid}) {
            next;
        }
        # If a recursive cache-clear was requested using the admin
        # interface, perform it. Otherwise just clear the single specified
        # document.
        if($obj->{clear_cache_request} && $obj->{clear_recursively}) {
            push(@recursive_docids, $obj->{docid});
        } else {
            push(@docids, $obj->{docid});
        }
    }

    if(@docids) {
        $self->flush_by_docids(@docids);
    }
    if(@recursive_docids) {
        $self->flush_by_docids_recursive(@recursive_docids);
    }
}

sub check_auto_cleanup {
    my ($self) = @_;

    if($self->{next_expire_check} <= time()) {
        $self->{next_expire_check} = time() + $self->expire_time_in_seconds;
        $self->cleanup;
    }
}

# Fetches a value from the store.
sub get_value_row {
    my ($self, $key) = @_;

    # Perform general expiration if needed
    $self->check_auto_cleanup;

    my $table = $self->store_tablename;

    my $sth = $self->obvius->dbh->prepare(qq|
        select
            `store`.*,
            `store`.`expires` < NOW() `expired`
        from
            `${table}` `store`
        where
            `store`.`key` = ?
    |);
    $sth->execute($key);

    if(my $row = $sth->fetchrow_hashref) {
        if($row->{expired}) {
            $self->delete_row($row->{id});
        } else {
            $row->{value} = $row->{value};
            return $row;
        }
    }

    return undef;
}

sub get_value {
    my ($self, $key) = @_;

    my $row = $self->get_value_row($key);

    return $row ? thaw($row->{value})->[0] : undef;
}

sub add_docid_ref {
    my ($self, $store_id, $docid) = @_;

    my $table = $self->ref_tablename;

    my $sth = $self->obvius->dbh->prepare(qq|
        INSERT IGNORE INTO `${table}`
            (`store_id`, `docid`)
        VALUES
            (?, ?)
    |);
    $sth->execute($store_id, $docid);
    $sth->finish;
}

sub get_or_insert_value {
    my ($self, $key, $callback, $ref_docid) = @_;

    my $row = $self->get_value_row($key);

    my $value;

    if($row) {
        $value = thaw($row->{value})->[0];
        if($ref_docid) {
            $self->add_docid_ref($row->{id}, $ref_docid);
        }
    } else {
        my $value = $callback->();
        $self->set_value($key, $value, $ref_docid);
        return $value;
    }

    return $value;
}

sub set_value {
    my ($self, $key, $value, $ref_docid) = @_;

    # Perform general expiration if needed
    $self->check_auto_cleanup;

    my $table = $self->store_tablename;
    my $expire_seconds = $self->expire_time_in_seconds;

    # Serialize value
    $value = freeze([$value]);

    my $sth = $self->obvius->dbh->prepare(qq|
        INSERT INTO `${table}`
            (`key`, `value`, `expires`)
        VALUES
            (?, ?, DATE_ADD(NOW(), INTERVAL ${expire_seconds} SECOND))
        ON DUPLICATE KEY UPDATE
            value = ?,
            expires = DATE_ADD(NOW(), INTERVAL ${expire_seconds} SECOND)
    |);
    $sth->execute(
        $key, $value,
        $value
    );

    my $id = $sth->{mysql_insertid};

    $sth->finish;

    if($ref_docid) {
        # Id might be 0 if no insert or update was done, so might
        # have to look it up.
        if(!$id) {
            my $row = $self->get_value_row($key);
            if($row) {
                $id = $row->{id};
            }
        }
        if($id) {
            $self->add_docid_ref($id, $ref_docid);
        }
    }
}

sub delete_row {
    my ($self, $row_id) = @_;

    my $store_table = $self->store_tablename;

    my $sth = $self->obvius->dbh->prepare(
        "delete from `${store_table}` where `id` = ?"
    );
    $sth->execute($row_id);
}

sub cleanup {
    my ($self) = @_;

    my $store_table = $self->store_tablename;

    my $sth = $self->obvius->dbh->prepare(qq|
        DELETE FROM `${store_table}`
        WHERE `expires` < NOW()
    |);
    $sth->execute;

    return $sth->rows;
}

sub flush_by_docids {
    my ($self,  @docids) = @_;

    if(!@docids) {
        return;
    }

    my $placeholders = join(",", map { "?" } @docids);
    my $store_table = $self->store_tablename;
    my $ref_table = $self->ref_tablename;

    my $sth = $self->obvius->dbh->prepare(qq|
        DELETE `store`
        FROM
            ${store_table} `store`
            JOIN
            ${ref_table} `refs` ON (
                `refs`.`store_id` = `store`.`id`
            )
        WHERE
            `refs`.`docid` IN ($placeholders)
    |);
    $sth->execute(@docids);

    return $sth->rows;
}

sub flush_by_docids_recursive {
    my ($self,  @docids) = @_;

    if(!@docids) {
        return;
    }

    my $placeholders = join(",", map { "?" } @docids);
    my $store_table = $self->store_tablename;
    my $ref_table = $self->ref_tablename;

    my $sth = $self->obvius->dbh->prepare(qq|
        DELETE `store`
        FROM
            ${store_table} `store`
            JOIN
            ${ref_table} `refs` ON (
                `refs`.`store_id` = `store`.`id`
            )
            JOIN `path_tree` ON (
                `path_tree`.`child` = `refs`.`docid`
            )
        WHERE
            `path_tree`.`parent` IN ($placeholders)
    |);
    $sth->execute(@docids);

    return $sth->rows;

}

sub flush_all {
    my ($self) = @_;

    my $store_table = $self->store_tablename;

    my $sth = $self->obvius->dbh->prepare(
        "DELETE FROM `${store_table}`"
    );
    $sth->execute;

    return $sth->rows;
}

sub get_migration_statements {
    my ($self) = @_;

    my $store_table = $self->store_tablename;
    my $ref_table = $self->ref_tablename;

    my @statements = map {s/^ {12}//gm; $_ } (
        qq|CREATE TABLE IF NOT EXISTS `${store_table}` (
                `id` INT(8) unsigned NOT NULL AUTO_INCREMENT,
                `key` VARCHAR(4096) NOT NULL,
                `value` MEDIUMBLOB NULL,
                `expires` datetime NOT NULL,
                PRIMARY KEY (`id`),
                UNIQUE KEY `${store_table}_key_unique` (`key`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8|,

        qq|CREATE TABLE IF NOT EXISTS `${ref_table}` (
                `id` INT(8) unsigned NOT NULL AUTO_INCREMENT,
                `store_id` INT(8) unsigned NOT NULL,
                `docid` int(8) unsigned,
                PRIMARY KEY (`id`),
                UNIQUE KEY `${ref_table}_store_docid` (`store_id`, `docid`),
                FOREIGN KEY `${ref_table}_store_ref` (`store_id`)
                    REFERENCES `${store_table}` (`id`)
                    ON DELETE CASCADE
                    ON UPDATE CASCADE,
                FOREIGN KEY `${ref_table}_doc_ref` (`docid`)
                    REFERENCES `documents` (`id`)
                    ON DELETE CASCADE
                    ON UPDATE CASCADE
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8|
    );

    return @statements;
}

sub get_migration_sql {
    my ($self) = @_;

    my $class = ref($self) || $self;


    my $sql = join("\n\n", map { 
        /;$/ ? $_ : "$_;" 
    } shift->get_migration_statements);

    return join("",
        "-- Created by ${class}->get_migration_sql\n\n",
        $sql, "\n\n",
    );
}

sub get_reverse_migration_statements {
    my ($self) = @_;

    my $store_table = $self->store_tablename;
    my $ref_table = $self->ref_tablename;

    my @statements = (
        "DROP TABLE IF EXISTS `${ref_table}`",
        "DROP TABLE IF EXISTS `${store_table}`",
    );

    return @statements;
}

sub get_reverse_migration_sql {
    my ($self) = @_;

    my $class = ref($self) || $self;

    my $sql = join("\n\n", map { 
        /;$/ ? $_ : "$_;" 
    } shift->get_reverse_migration_statements);

    return join("",
        "-- Created by ${class}->get_reverse_migration_sql\n\n",
        $sql, "\n\n",
    );
}

1;
