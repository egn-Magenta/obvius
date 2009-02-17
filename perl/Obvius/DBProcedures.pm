package Obvius::DBProcedures;

use strict;
use warnings;

my $commands = [
	   {
	    command => 'copy_docparams',
	    args    => [ qw(from to) ],
	    options => {explicit_transactional => 1}
	   },
           {
	    command => 'read_vfields',
	    args => [ qw(docid version names) ],
	    options => {output => 1},
	   },
	   {
	    command => 'read_vfields_from_pol',
	    args => [ qw(docid names) ],
	    options => {output => 1}
	   },
	   {
	    command => "add_vfield",
	    args => [qw( docid version name text_value int_value double_value date_value )],
	    options => {explicit_transactional => 1}
	   },
	   {
	    command => "do_search", 
	    args => [qw( path pattern owner grp newer_than older_than )], 
	    options => {output => 1}
	   },
	   {
	    command => "publish_version",
	    args => [qw( docid version lang )],
	    options =>{explicit_transactional => 1}
	   },
	   {
	    command => "unpublish_document",
	    args => [qw( docid lang )],
	    options =>{explicit_transactional => 1}
	   },
	   {
	    command => "new_internal_proxy_entry",
	    args =>  [qw( docid version depends_on fields) ],
	    options => { explicit_transactional => 1}
	   },
	   {
	    command => "update_internal_proxy_docids",
	    args => [qw( docids )],
	    options =>{ transactional => 1}
	   },
	   {
	    command => "update_internal_proxy_document",
	    args => [ qw( docid version) ],
	    options => {explicit_transactional => 1}
	   },
	   {
	    command => "move_document",
	    args => [qw( docid new_parent new_name ) ],
	    options =>{explicit_transactional => 1}
	   },
	   {
	    command => "copy_tree", 
	    args =>  [qw( docid new_parent new_name ) ],
	    options =>{ "explicit_transactional" => 1}
	   },
	   {
	    command => "delete_tree",
	    args =>[ qw( docid ) ],
	    options =>{ explicit_transactional => 1}
	   },
	   {
	    command => "is_internal_proxy_document",
	    args => [ qw( docid ) ],
	    options => {output => 1, post_hook => 
			sub {
			     my $res = shift;
			     if (ref $res eq 'ARRAY' && 1 == @$res) {
				  return $res->[0]{is_};
			     } 
			     return 0;
			}}}];
		
		
sub new {
     my ($class, $db) = @_;
     
     my $this = bless {db => $db}, $class;
     $this->{DBProcedures} = $this->make_cmds($commands);
     return $this;
}

sub execute_output {
     my ($this, $sql, @args) = @_;
     my @result;

     my $sth = $this->db->prepare($sql);
     
     $sth->execute(@args);
     if ($sth) {
	  while (my $res = $sth->fetchrow_hashref()) {
	       push @result, {map { $_ => $res->{$_} } keys(%$res)};
	  }
     }
     $sth->finish();

     return \@result;
}

sub db {
     return shift->{db};
}

sub do {
     my ($this, $query, @args) = @_;

     return $this->db->do($query, undef, @args);
}

sub rollback {
     return shift->db->rollback;
}

sub start_transaction {
     return shift->db->begin_work;
}

sub commit {
     return shift->db->commit;
}

sub make_cmds {
     my ($this, $cmds) = @_;
     
     my %res;
     
     for my $cmd (@$cmds) {
	  my $fun = $this->make_cmd($cmd->{command}, $cmd->{args}, $cmd->{options});
	  $res{$cmd->{command}}  = $fun;
	  if ($cmd->{aliases}) {
	       $res{$_} = $fun for @{$cmd->{aliases}};
	  }
     }
     return \%res;
}
	  
sub make_cmd {
     my ($this, $cmd, $args, $options)  = @_;
     
     my $nr_args = scalar(@$args);
     my @a = ('?') x $nr_args;

     my $query = "call $cmd(" . (join ",", @a) . ");";
     
     $options->{transactional} ||= $options->{explicit_transactional};

     return sub {
	  my ($this, @args) = @_;
	  my $result;
	  
	  $this->db->{RaiseError} = 1;
	  
	  my @qargs;
	  if (scalar(@args) == 1 && ref $args[0] eq 'HASH') {
	       my $arg = $args[0];
	       for my $n (@$args) {
		     if (exists $arg->{$n}) {
			  push @qargs, $arg->{$n};
		     } else {
			  push @qargs, undef;
		     }
		}
	  } else {
	       @qargs = (@args, (undef) x ($nr_args - @args));
	  }
	  
	  $this->start_transaction if ($options->{explicit_transactional});
	  
	  eval {
	       if ($options->{output}) {
		    $result = $this->execute_output($query, @qargs);
	       } else {
		    $result = $this->do($query, @qargs);
	       }
	  };
	  
	  if ($@) {
	       $this->rollback if ($options->{transactional});
	       warn "Error: $@";
	       die "Error: $@";
	  }
	  
	  $this->commit if ($options->{explicit_transactional});
	  
	  return $options->{post_hook}->($result) if ($options->{post_hook});
	  return $result;
     }
}

AUTOLOAD {
     my ($this, @args) = @_;
     our $AUTOLOAD;
     
     my ($method) = $AUTOLOAD =~ /::([^:]+)$/;
     
     my $fun = $this->{DBProcedures}{$method};
     return $fun->($this, @args) if ($fun);

     die "Function not found: $AUTOLOAD\n";
}

DESTROY {
     undef shift->{db};
}

1;
