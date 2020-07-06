package Obvius::DatabaseMigrator;

use Scalar::Util;
use Carp;
use Moose;
extends 'Database::Migrator::mysql';

use Obvius;
my $obvius_ref; # See set_obvius subroutine

### ATTRIBUTES ###
# Used by Database::Migrator::mysql when running SQL commands
# Attributes are lazy-loaded because we want to be able to set
# an Obvius reference before Moose tries to initialise the
# attributes

## KEYS ##
# required: set to 0 to indicate we don't need to specify it when invoking the Migrator
# lazy: see above
# default: the actual value; can be overridden when invoking
has '+database' => (
    required => 0,
    lazy => 1,
    default => sub {
        my $self = shift;
        return $self->obvius->config->param('db_database');
    },
);

has '+host' => (
    required => 0,
    lazy => 1,
    default => sub {
        my $self = shift;
        return $self->obvius->config->param('db_host');
    },
);

has '+username' => (
    required => 0,
    lazy => 1,
    default => sub {
        my $self = shift;
        return $self->obvius->config->param('normal_db_login');
    },
);

has '+password' => (
    required => 0,
    lazy => 1,
    default => sub {
        my $self = shift;
        return $self->obvius->config->param('normal_db_passwd');
    },
);

# We don't want to provide an initial schema
has '+schema_file' => (
    required => 0,
    default  => '',
);

# We don't want to try to create a database, so just make it a no-op
sub _create_database {}

# Only used when checking for existance of database
# All other methods on Database::Migrator use raw mysql CLI calls
# ¯\_(ツ)_/¯
sub _build_dbh {
    my $self = shift;

    my $config = $self->obvius->config;
    return DBI->connect(
        $config->param('dsn'),
        $config->param('normal_db_login'),
        $config->param('normal_db_passwd')
    );
}

=item obvius()

Returns the current obvius object if set. Dies if not obvius
object has been set.

Example:
    my $obvius = $url->obvius

Output:
    An Obvius object

=cut
sub obvius {
    if(!$obvius_ref) {
        carp 'Obvius ref not set. Please set it using ' .
        'Obvius::DatabaseMigrator->set_obvius() before calling ' .
        'Obvius::DatabaseMigrator->obvius.';
    }

    return $obvius_ref;
}

=item set_obvius($obvius)

Sets the obvius object used to look up db config params. If set to
an existing Obvius object a weak reference will be used to refer to the
object.
If a configname is used a new Obvius object will be created and
refered with a non-weak reference, so it does not go out of scope.

Example:
    Obvius::DatabaseMigrator->set_obvius($obvius)
    Obvius::DatabaseMigrator->set_obvius("myconfname")

Input:
    An existing Obvius object
    or
    A confname

Output:
    An Obvius object

=cut

sub set_obvius {
    my ($obvius) = @_;

    # Make callable with both Obvius::DatabaseMigrator->set_obvius, Obvius::DatabaseMigrator::set_obvius
    # and $obj->set_obvius;
    if($obvius && (ref($obvius) || $obvius) eq __PACKAGE__) {
        shift @_;
        ($obvius) = @_;
    }

    # If we get a config name as first parameter, just create an Obvius
    # object and do not weaken the reference to it, since this module
    # will have the only reference.
    if(!ref $obvius) {
        $obvius_ref = Obvius->new(Obvius::Config->new($obvius));
        return 1;
    }

    # Set and weaken reference
    $obvius_ref = $obvius;
    Scalar::Util::weaken($obvius_ref);

    return 1;
}

1;
