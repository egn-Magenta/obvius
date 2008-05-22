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
     
     my $vals = $cache_objs->request_values('docid');
     my @docids = map { $_->{docid} } grep { $_->{docid}} @$vals;

     $this->flush(\@docids);
}

sub flush {
     my ($this, $relations) = @_;
     
     my $internal_proxy = WebObvius::InternalProxyCache->new($this->{obvius});
     
     return $internal_proxy->check_and_update_internal_proxies($relations);
}

1;

     
