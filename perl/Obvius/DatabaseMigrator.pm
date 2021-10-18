package Obvius::DatabaseMigrator;

use Scalar::Util;
use Carp;
use Moose;
extends 'Database::Migrator::mysql';

use Obvius::Config;
use Carp;

has 'config' => (
    is => 'rw',
    isa => 'Obvius::Config',
    required => 1
);

# Make username and password rw so we can change them when escalating privileges
has 'username' => (is => 'rw');
has 'password' => (is => 'rw');

sub new_with_obvius_config {
    my ($class, $obvius_config, $options) = @_;

    if(!$obvius_config) {
        croak 'You must specify an Obvius::Config object or a confname';
    }

    if(!ref $obvius_config) {
        $obvius_config = Obvius::Config->new($obvius_config);
    } elsif(ref $obvius_config eq 'Obvius') {
        $obvius_config = $obvius_config->config;
    }

    if(ref $obvius_config ne 'Obvius::Config') {
        croak "Do not know how to make an Obvius::Config object from $obvius_config";
    }

    my $sitebase = $obvius_config->param('sitebase');
    my $database_name = $obvius_config->param('db_database');
    my $schema_name = lc $obvius_config->param('perlname'); # Constant name for each Obvius project
    my $schema_file = join q{/}, $sitebase, 'db', "schema", "${schema_name}.sql";
    $schema_file =~ s{/+}{/}gx; # Remove double slashes

    $options ||= {};

    return $class->new_with_options({
        config => $obvius_config,
        database => $database_name,
        host => $obvius_config->param('db_host'),
        username => $obvius_config->param('normal_db_login'),
        password => $obvius_config->param('normal_db_passwd'),
        schema_file => $schema_file,
        %$options
    });
}

sub _switch_to_privileged_user {
    my ($self) = @_;

    my $config = $self->config;
    my $priv_user = $config->param('privileged_db_login');
    my $priv_password = $config->param('privileged_db_passwd');

    if(!$priv_user || !$priv_password) {
        croak "Can not switch to privileged user: No privileged login information";
    }

    $self->username($priv_user);
    $self->password($priv_password);

    return;
}

sub _switch_to_normal_user {
    my ($self) = @_;

    my $config = $self->config;
    $self->username($config->param('normal_db_login'));
    $self->password($config->param('normal_db_passwd'));

    return;
}

# Builds a dbh that actually uses the correct hostname
sub _build_dbh {
    my ($self) = @_;

    my $config = $self->config;

    return DBI->connect(
        $config->param('dsn'),
        $self->username,
        $self->password,
        {
            RaiseError         => 1,
            PrintError         => 1,
            PrintWarn          => 1,
            ShowErrorStatement => 1,
        }
    );
}

# Check if tables have been created in the database by testing if
# the documents table exists
sub _check_obvius_schema_exists {
    my ($self) = @_;

    my $tables = $self->_build_dbh->selectcol_arrayref(
        "show tables like 'documents'"
    );

    return $tables->[0] ? 1: 0;
}

# Override create_or_update_database to make it run the DDL if the database
# exists but is empty.
sub create_or_update_database {
    my $self = shift;

    if ( $self->_database_exists() ) {
        my $database = $self->database();
        $self->logger()->debug("The $database database already exists");
        if(!$self->_check_obvius_schema_exists) {
            $self->logger()->info('Schema not found, running DDL');
            $self->_run_ddl( $self->schema_file() );
            $self->logger()->info('Flushing tables');
            $self->_switch_to_privileged_user;
            $self->_run_command([$self->_cli_args(), '-e FLUSH TABLES']);
            $self->_switch_to_normal_user;
        }
    }
    else {
        $self->_create_database();
        $self->_run_ddl( $self->schema_file() );
    }

    $self->_run_migrations();

    return;
}


sub _run_one_migration {
    my ($self, $migration, @args) = @_;

    if($migration->basename =~ m{privileged}) {
        $self->logger()->info("Enabling privileges for " . $migration->basename);
        $self->_switch_to_privileged_user;
        $self->SUPER::_run_one_migration($migration, @args);
        $self->_switch_to_normal_user;
    } else {
        $self->SUPER::_run_one_migration($migration, @args);
    }
    return;
}

1;
