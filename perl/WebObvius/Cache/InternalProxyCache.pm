package WebObvius::Cache::InternalProxyCache;

use strict;
use warnings;

use Obvius;
use Data::Dumper;
use WebObvius::InternalProxy;

sub new {
     my ($class, $obvius) = @_;
     
     return bless {obvius => $obvius}, $class;
}

sub find_and_flush {
     my ($this, $cache_objs) = @_;
     
     my $vals = $cache_objs->request_values('docid', 'dont_internal_proxy_this');
     my @docids = map { 
	  $_->{docid} 
     } grep { 
	  $_->{docid} && !$_->{dont_internal_proxy_this}
     } @$vals;

     $this->flush(\@docids) if (scalar(@docids));
}

sub flush {
     my ($this, $relations) = @_;
     
     my $internal_proxy = WebObvius::InternalProxy->new($this->{obvius});
     
     return $internal_proxy->check_and_update_internal_proxies($relations);
}

1;

     
