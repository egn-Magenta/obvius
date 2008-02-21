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

sub list {
     my ($this, $object, $options) = @_;

     my $list_sql = $this->{list_sql};
     die "No list sql " if (!$list_sql);

     my $dbh = $this->{obvius}->{DB}->DBHdl;
     die "No dbhdl in obvius" if (!$dbh);

     my $sth = $dbh->prepare($list_sql);
     $sth->execute;

     my @res;

     while (my $row = $sth->fetchrow_hashref) {
	  push @res, {
		     map { $_ =>
			   {
			    value => $row ->{$_},
			    status => 'OK'
			   }
		      } keys %$row
		     };
     }

     $sth->finish;
     return \@res, length (@res);
}

sub lookup {
     my @a = @_;
     die Dumper(\@a);
}

1;
