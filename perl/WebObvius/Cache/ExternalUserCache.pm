package WebObvius::Cache::ExternalUserCache;

use strict;
use warnings;

use Data::Dumper;
use WebObvius::Cache::SOAPHelper;
use WebObvius::Cache::UserCache;

our @ISA = qw( WebObvius::Cache::UserCache );

sub new {
     return shift->SUPER::new(@_);
}

sub find_and_flush {
     my ($this, $cache_objects) = @_;
     
     print STDERR "Finding and flushing here\n";
     my $relevant = $cache_objects->request_values('users');
     my $flush = grep { $_->{users} } @$relevant;
     
     if ($flush) {
	  print STDERR "Flushing\n";
	  my $commands = {all => 1};
	  $this->flush($commands);
 	  print STDERR "Commands: " .  Dumper($commands);

	  my $command = {cache => 'WebObvius::Cache::UserCache', commands => $commands};
	  WebObvius::Cache::SOAPHelper::send_command($this, $command);
     }
}

1;
