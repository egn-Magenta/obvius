package WebObvius::Cache::MysqlAdminLeftmenuCache;

use strict;
use warnings;

use WebObvius::Cache::MysqlTableCache;
use Exporter;

our @ISA = qw( WebObvius::Cache::MysqlTableCache Exporter );
our @EXPORT_OK = qw( cache_new_version_p );

sub new {
     my ($class, $obvius) = @_;

     return $class->SUPER::new($obvius, 'admin_leftmenu_cache');
}

sub find_dirty {
     my ($this, $cache_objects) = @_;

     my $obvius = $this->{obvius};
     
     $obvius->connect if (!$obvius->{DB});
     my $values = $cache_objects->request_values('admin_leftmenu');
     
     my @docids = map { @{$_->{admin_leftmenu}} } grep { $_->{admin_leftmenu} } @$values;
     
     return \@docids;
}

sub flush {
     my ($this, $dirty) = @_;
     $dirty = [$dirty] if !ref $dirty;
     
     my $obvius = $this->{obvius};
     
     if($obvius->config->param('use_old_admin_subdocs_sort')) {
          my @clear_keys;
          for my $docid (@$dirty) {
               my $d = $obvius->get_doc_by_id($docid);
               next unless($d);
               my $versions = $obvius->get_versions($d);
               next unless($versions);
               for my $v (@$versions) {
                    push(@clear_keys, $v->Docid . "_" . $v->Version);
               }
          }
          $this->flush_from_table(\@clear_keys);
     } else {
          $this->flush_from_table(\@$dirty);
     }
}


sub cache_new_version_p {
     my ($obvius, $docid, $lang) = @_;
     
     # If we use the old leftmenu sorting, always clear after creating a new version:
     return 1 if($obvius->config->param('use_old_admin_subdocs_sort'));
     
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
