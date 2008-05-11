package WebObvius::Cache::SOAPHelper;

use strict;
use warnings;

use Data::Dumper;
use SOAP::Lite;

sub send_command {
     my ($cache, $cmds) = @_;
     
     my $obvius = $cache->{obvius};
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
