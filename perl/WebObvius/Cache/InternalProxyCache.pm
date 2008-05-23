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

sub clean_table {
     my ($this) = @_;
     my $obvius = $this->{obvius};
     
     my $query = "delete i from 
            internal_proxy_documents i left join versions v on 
            (v.version = i.referrer_version and i.referrer_docid = v.docid) where
            v.docid is null";
     
     $obvius->execute_command($query);
}

sub flush {
     my ($this, $relations) = @_;
     
     $this->clean_table;
     my $internal_proxy = WebObvius::InternalProxy->new($this->{obvius});
     
     return $internal_proxy->check_and_update_internal_proxies($relations);
}

1;

     
