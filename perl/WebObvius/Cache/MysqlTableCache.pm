package WebObvius::Cache::MysqlTableCache;

use strict;
use warnings;

use Data::Dumper;
use Storable qw(nfreeze thaw);

sub new {
    my ($class, $obvius, $table, %cache_options) = @_;
    
    my %options = (
        key_column => 'id',
        data_column => 'cache_data',
        %cache_options
    );
    
    my $this = bless {
        obvius => $obvius, 
        table => $table, 
        cache_options => \%options,
    }, $class;
    
    return $this;
}

sub save {
    my ($this, $key, $data) = @_;
    my $serialized = nfreeze([$data]);
    my $table = $this->{table};
    my $keyname = $this->{cache_options}->{key_column};
    my $dataname = $this->{cache_options}->{data_column};
    my $sth = $this->{obvius}->dbh->prepare(qq|
        INSERT INTO
            ${table}
            (${keyname}, ${dataname})
        VALUES
            (?,?)
        ON DUPLICATE KEY UPDATE
            ${dataname} = VALUES(${dataname})
    |);
    $sth->execute($key, $serialized)
}

sub get {
    my ($this, $key) = @_;

    my $table = $this->{table};
    my $keyname = $this->{cache_options}->{key_column};
    my $dataname = $this->{cache_options}->{data_column};

    my $sth = $this->{obvius}->dbh->prepare(qq|
        SELECT
            ${dataname}
        FROM
            ${table}
        WHERE
            ${keyname} = ?
    |);
    $sth->execute($key);

    if(my ($serialized) = $sth->fetchrow_array) {
        my $thawed = thaw($serialized);
        return $thawed->[0];
    }

    return undef;
}

sub flush_from_table {
    my ($this, $dirty) = @_;
    $dirty = [$dirty] if !ref $dirty;

    my $table = $this->{table};
    my $keyname = $this->{cache_options}->{key_column};
    
    my @todo = @$dirty;

    while(my @cur_uris = splice @todo, 0, 50) {
        my $qmarks = join(",", map{'?'} @cur_uris);
        my $flusher = $this->{obvius}->dbh->prepare(qq|
            DELETE FROM ${table}
                WHERE
                    ${keyname} IN ($qmarks)
        |);
        $flusher->execute(@cur_uris);
    }
}

sub flush {
    my ($this, $dirty) = @_;
    $this->flush_from_table($dirty);
}

sub flush_completely {
    my $this = shift;
    my $cache = $this->get_cache();

    my $table = $this->{table};
    my $sth = $this->{obvius}->dbh->prepare(qq|DELETE FROM ${table}|);
    $sth->execute;
}

sub find_and_flush {
    my ($this, $cache_objects) = @_;
  
    my $dirty = $this->find_dirty($cache_objects);
    $this->flush($dirty);
}

1;
