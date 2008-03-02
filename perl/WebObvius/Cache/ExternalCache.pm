package WebObvius::Cache::ExternalCache;

use strict;
use warnings;

use Data::Dumper;
use SOAP::Lite;

our @ISA = qw( WebObvius::Cache::ApacheCache );

# Stub.
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
	  $this->send_commands($commands);
     }
}

sub send_commands {
     my ($this, $cmds) = @_;
     
     my $obvius = $this->{obvius};
     return if (!$obvius);
     my $other_servers = $obvius->{OBVIUS_CONFIG}{OTHER_SERVERS};
     return if (!$other_servers);

     for my $host (@$other_servers) {
	  my $uri =SOAP::Lite->uri("http://$host/WebObvius::SOAP::CacheHandler");
	  my $proxy = $uri->proxy("http://$host/soap");
	  $proxy->flush($cmds);
     }
}

1;
