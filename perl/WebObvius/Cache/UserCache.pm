package WebObvius::Cache::UserCache;

use warnings;
use strict;

use Data::Dumper;
use WebObvius::Cache::FileCache;

our @ISA = qw( WebObvius::Cache::FileCache );


sub new {
     my ($class, $obvius) = @_;
     return $class->SUPER::new($obvius, 'user_data');
}


sub check_and_fix_abandoned_documents {
     my ($this) = @_;

     my $obvius = $this->{obvius};

     my $user_query =
       "select distinct(d.id) as docid from documents d left join users u on (u.id = d.owner) where u.id is null";
     my $group_query = 
       "select distinct(d.id) as docid from documents d left join groups g on (g.id = d.grp) where g.id is null";
     
     my $user_docids  = join ",", map {$_->{docid}} @{$obvius->execute_select($user_query)};
     my $group_docids = join ",", map {$_->{docid}} @{$obvius->execute_select($group_query)};
     
     $obvius->execute_command("update documents set owner=1 where id in ($user_docids)") if ($user_docids);
     $obvius->execute_command("update documents set grp=1 where id in ($group_docids)") if ($group_docids);
}
     
sub flush {
     my ($this, $cmd) = @_;
     
     if (ref($cmd) eq 'HASH' && $cmd->{all}) {
	  $this->flush_completely();
	  return;
     }
     
     shift @_;
     return $this->SUPER::flush(@_);
}

sub find_and_flush {
     my ($this, $cache_objects) = @_;

     my $relevant = $cache_objects->request_values('users');
     
     my $flush = grep { $_->{users} } @$relevant;
 
     $this->flush({all => 1}) if ($flush);
}     

1;
