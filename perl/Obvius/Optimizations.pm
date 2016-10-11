package Obvius::Optimizations;

use strict;
use warnings;
use utf8;

my %config = (
    'documents' => {
        'public_or_latest_version' =>
            "Automatically updated reference to public or latest version",
        'has_public_path' => q|
            Automatically updated field specifying whether document has
            a fully public path"
        |
    }
);


$config{path_tree}{id} = <<EOT;
A bridge table that represents the ancestor/heir relationship between
documents.
Implemented in www.ku.dk/db/updates/2015_09_18_documents_tree_table.sql.
EOT

$config{documents}{public_or_latest_version} = <<EOT;
Automatically updated reference pointing to the current public or latest
version for the document.
Implemented in www.ku.dk/db/updates/2015_09_18_documents_tree_table.sql.
EOT

$config{documents}{has_public_path} = <<EOT;
Automatically updated field specifying whether document has a fully public
path.
Implemented in www.ku.dk/db/updates/2015_09_18_documents_tree_table.sql.
EOT

$config{documents}{closest_subsite} = <<EOT;
Automatically updated field pointing to the active subsite for the document.
Implemented in www.ku.dk/db/updates/2015_09_18_documents_tree_table.sql.
EOT

my %aliases = (
    path_tree => "path_tree.id",
    public_or_latest_version => "documents.public_or_latest_version",
    has_public_path => "documents.has_public_path",
    closest_subsite => "documents.closest_subsite",
);

sub get_optimizations {
    my ($self) = @_;

    if(not $self->{_optimization_data}) {
        my %data;

        foreach my $table (sort keys %config) {
            my $sth = $self->dbh->prepare(q|
                SELECT
                    COLUMN_NAME
                FROM
                    INFORMATION_SCHEMA.COLUMNS
                WHERE
                    TABLE_SCHEMA=DATABASE() AND
                    TABLE_NAME=?
            |);
            $sth->execute($table);
            while(my ($columnname) = $sth->fetchrow_array) {
                if(my $desc = $config{$table}{$columnname}) {
                     $data{lc("${table}.${columnname}")} = $desc;
                }
            }
        }

        $self->{_optimization_data} = \%data;
    }

    return $self->{_optimization_data};
}

sub has_optimization {
    my ($self, $name) = @_;

    my $data = $self->get_optimizations;

    $name = $aliases{$name} || $name;

    return exists $data->{$name} ? 1 : 0;
}

1;