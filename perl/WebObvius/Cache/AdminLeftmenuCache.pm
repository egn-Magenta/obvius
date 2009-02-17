package WebObvius::Cache::AdminLeftmenuCache;

use strict;
use warnings;

use WebObvius::Cache::FileCache;
use Exporter;

our @ISA = qw( WebObvius::Cache::FileCache Exporter );
our @EXPORT_OK = qw( cache_new_version_p );

sub new {
     my ($class, $obvius) = @_;

     return $class->SUPER::new($obvius, 'subdocs');
}

sub find_dirty {
     my ($this, $cache_objects) = @_;

     my $obvius = $this->{obvius};
     
     $obvius->connect if (!$obvius->{DB});
     my $values = $cache_objects->request_values('admin_leftmenu');
     
     my @docids = map { @{$_->{admin_leftmenu}} } grep { $_->{admin_leftmenu} } @$values;
     
     return \@docids;
}

sub cache_new_version_p {
     my ($obvius, $docid, $lang) = @_;
     
     my $query = <<END;
     select distinct docid d from 
            versions v
     where 
            v.public = 1 AND v.docid = ? AND v.lang = ?;
END

     my $res = $obvius->execute_select($query, $docid, $lang);
     return !(scalar @$res);
}
     
1;
