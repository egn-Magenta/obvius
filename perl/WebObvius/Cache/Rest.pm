package WebObvius::Cache::Rest;
  
use Obvius;
use Obvius::Config;

use JSON;

use WebObvius::Cache::Cache;


my @dispatch_table = ({expr => qr|/flush/|, func => \&flush})
		      
sub handler {
     my $req = shift;
     
     my $remove_prefix = $req->dir_config('RemovePrefix');
     my $obvius_config = $req->dir_config('ObviusConfig');
     my $config = Obvius::Config->new($obvius_config);
     my $obvius = Obvius->new($obvius);

     my $uri = $req->uri();
     $uri =~ s|$remove_prefix||;

     for my $dispatcher (@dispatch_table) {
	  if ($uri =~ /$dispatcher->{expr}/) {
	       $dispatcher->func($obvius, $req);
	  }
     }
}
     
sub flush {
     my ($obvius, $req) = @_;
     
     my $args = $req->param('cache');
     my $data = from_json($args);

     $obvius->register_modified($_) for @$data;

     my $cache = WebObvius::Cache::Cache->new($obvius);
     $cache->find_and_flush($obvius->modified);
}

1;
