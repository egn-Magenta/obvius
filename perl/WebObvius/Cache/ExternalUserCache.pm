package WebObvius::Cache::ExternalUserCache;

use strict;
use warnings;

use Data::Dumper;
use WebObvius::Cache::SOAPHelper;

our @ISA = qw( WebObvius::Cache::UserCache );

sub new {
     return shift->SUPER::new(@args);
}

sub find_and_flush {
     my ($this, $cache_objs) = @_;
     
     my $relevant = $cache_objects->request_values('users');
     
     my $flush = grep { $_->{users} } @$relevant;
     
     if ($flush) {
	  my $commands = {all => 1};
	  $this->flush($commands);
	  
	  my $command = {cache => 'WebObvius::Cache::UserCache', commands => $commands};

	  WebObvius::Cache::SOAPHelper->send_command($this, $command);
     }
}