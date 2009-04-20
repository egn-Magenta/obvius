package WebObvius::Cache::Rest;
  
use Obvius;
use Obvius::Config;

use JSON;
use Data::Dumper;

use WebObvius::Cache::Cache;
use Apache2::Request;

our @dispatch_table = ({expr => qr|/flush/|, func => \&flush});
		      
sub handler {
     my ($this, $req) = @_;
     
     my $remove_prefix = $req->dir_config('RemovePrefix');
     my $obvius_config = $req->dir_config('ObviusConfig');
     my $config = Obvius::Config->new($obvius_config);

     print STDERR "CAME HERE4 $config $obvius_config\n";
     my $obvius = Obvius->new($config);

     my $uri = $req->uri();
     $uri =~ s|$remove_prefix||;
     
     for my $dispatcher (@dispatch_table) {
          if ($uri =~ /$dispatcher->{expr}/) {
               my $status = $dispatcher->{func}->($obvius, $req);
               $obvius->{DB} = undef;
               return $status;
          }
     }
     select($old);

}
     
sub flush {
     my ($obvius, $req) = @_;
     
     my $ap2_req = Apache2::Request->new($req);
     my $args = $ap2_req->param('cache');
     my $data = from_json($args);

     print STDERR "ARgs is " . Dumper($args);
     return 400 if (ref $data ne 'ARRAY');

     (ref $_ eq 'HASH' and $obvius->register_modified(%$_)) for @$data;
     
     if ($obvius->modified) {
	  my $cache = WebObvius::Cache::Cache->new($obvius);
	  $cache->quick_flush($obvius->modified);
	  $cache->find_and_flush($obvius->modified);
     }
     
     return 200;
}

1;
