package WebObvius::Storage::CustomDb;

use strict;
use warnings;

use Data::Dumper;
use DBI;

our $VERSION = '0.01';

sub new {
    my ($class, $options, $obvius) = @_;

    my $this = bless { obvius => $obvius, %$options} , $class;

    return $this;
}

sub query_append {
     my ($this, $o) = @_;
     
     my $as = "";
     my @args;

     if ($o->{sort}) {
	  $as .= "ORDER BY " . $o->{sort} . ($o->{reverse} ? ' DESC ' : ' ASC ');
     }
     if ($o->{start}) {
	  $as .= ' OFFSET ? ';
	  push @args, $o->{start};
     }
     if ($o->{max}) {
	  $as .= ' LIMIT ? ';
	  push @args, $o->{max}
     }

     return ($as, \@args);
}

sub exec_query {
     my ($this, $query, $args, $handler, $options) = @_;

     my ($as, $append_args) = $this->query_append($options) if $options;
     
     $query .= $as if ($as);
     my @args = @$args;
     @args = (@args, @$append_args) if ($append_args);

     print STDERR "exec_query: $query\n";
     print STDERR "args: " . Dumper(\@args);
     my $dbh = $this->{obvius}->{DB}->DBHdl;
     die "No dbhdl in obvius" if (!$dbh);

     my $sth = $dbh->prepare($query);
     $sth->execute(@args);

     my @res;
     while (my $row = $sth->fetchrow_hashref) {
	  push @res, &$handler($row);
     }

     $sth->finish;
     return \@res;
}

sub list {
     my ($this, $object, $options) = @_;

     my $ps = $this->{prepare_statement};
     die "No prepare statement" if (!$ps);

     my @args = map { $object->{$_} } @{$this->{args}} if ($this->{args});
     for (@args) {
	  die "unknown arguments in args list" if (!$_);
     }

     my $res = $this->exec_query($ps, \@args, 
				 sub { return {
				      map { $_ =>
					    {
					     value => $_[0]->{$_},
					     status => 'OK'
					    }
				       } keys %{$_[0]}
				  }
				  }, $options);

     my $total_count = $this->exec_query($this->{count_statement}, \@args, sub { return $_[0]->{count} })->[0];
     
     return $res, $total_count;
}

sub lookup {
     my ($this, @a) = @_;

     return;
}

1;
