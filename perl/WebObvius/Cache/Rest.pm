package WebObvius::Cache::Rest;
  
use strict;
use warnings;
  
use Obvius;
use Obvius::Config;

use JSON;
use Data::Dumper;

use WebObvius::Cache::Cache;
use Apache2::Request;

use Apache2::Const -compile => qw(OK SERVER_ERROR);

our @dispatch_table = ({expr => qr|/flush/|, func => \&flush});
		      
sub handler {
    my ($this, $req) = @_;
    
    my $remove_prefix = $req->dir_config('RemovePrefix');
    my $obvius_config = $req->dir_config('ObviusConfig');
    my $config = Obvius::Config->new($obvius_config);

    my $obvius = Obvius->new($config);

    my $uri = $req->uri();
    $uri =~ s|$remove_prefix||;
    
    for my $dispatcher (@dispatch_table) {
	if ($uri =~ /$dispatcher->{expr}/) {
	    my ($status, $data) = $dispatcher->{func}->($obvius, $req);
	    $obvius->{DB} = undef;
	    if($data) {
		$req->print($data);
		$req->set_content_length(length($data))
		    unless ($req->header_only);
	    }
	    return $status;
	}
    }

    return Apache2::Const::SERVER_ERROR;
}
     
sub flush {
    my ($obvius, $req) = @_;

    my $ap2_req = Apache2::Request->new($req);
    my $args = $ap2_req->param('cache');
    my $data = from_json($args);
    
    return (400) if (ref $data ne 'ARRAY');

    (ref $_ eq 'HASH' and $obvius->register_modified(%$_)) for @$data;

    if ($obvius->modified) {
	 my $cache = WebObvius::Cache::Cache->new($obvius);
	 $cache->quick_flush($obvius->modified);
	 $cache->find_and_flush($obvius->modified);
    }

    return (Apache2::Const::OK, "OK\n");
}

1;
