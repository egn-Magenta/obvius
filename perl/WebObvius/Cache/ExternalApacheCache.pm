package WebObvius::Cache::ExternalApacheCache;

use strict;
use warnings;

use Data::Dumper;
use WebObvius::Cache::SOAPHelper;
our @ISA = qw( WebObvius::Cache::ApacheCache );

sub new {
     my ($class,  @args) = @_;
     
     my $new = $class->SUPER::new(@args);
     return $new;
}


sub find_and_flush {
     my ($this, $cache_objs) = @_;
     
     my $commands = $this->find_dirty($cache_objs);
     
     @$commands = grep {$_} @$commands;
     if (scalar @$commands) {
	  $this->flush($commands);
	  my $command = {cache => 'WebObvius::Cache::ApacheCache', commands => $commands}; 
	  WebObvius::Cache::SOAPHelper::send_command($this, $command);
     }
}


1;
