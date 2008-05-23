package WebObvius::InternalProxy;

use strict;
use warnings;

use Data::Dumper;
use Obvius;
use Obvius::Data;

my @overloaded_vfields = qw( title short_title seq rightboxes internal_proxy_path );

sub new {
     my ($class, $obvius) = @_;
     return bless {obvius => $obvius}, $class;
}

sub is_internal_proxy_document {
     my ($this, $docid) = @_;
     
     my $obvius = $this->{obvius};

     my $query = <<END;
select * from internal_proxy_documents i
where i.referrer_docid = ?;
END
     my $res = @{$obvius->execute_select($query, $docid)};
     
     return $res;
}

sub get_fields_doctype_and_version {
     my ($this, $reference_doc, $fields) = @_;;
     my $obvius = $this->{obvius};

     my $version = $obvius->get_public_version($reference_doc) || $obvius->get_latest_version($reference_doc);
     die "Couldn't get version." if (!$version);
     
     my $reference_doctype = $obvius->get_version_type($version);
     die "Couldn't get doctype." if (!$reference_doctype);

     my @fieldnames = map { lc } @{$reference_doctype->fields_names};
     die "No fieldnames" if (!@fieldnames);

     my %field_values = map {
	  lc($_->{name}) => $_->{text_value} || $_->{int_value} || $_->{date_value} || $_->{double_value}
     }
       @{$obvius->execute_select("select * from vfields where docid=? and version=?", 
				 $reference_doc->Id, $version->Version)};
     
     %field_values = map { $_ => $field_values{$_} } @fieldnames;
     for my $field (@overloaded_vfields) {
	  if ($fields->{$field}) {
	       $field_values{$field} = $fields->{$field};
	  } else {
	       delete $field_values{$field} if (exists $field_values{$field});
	  }
     }
     print STDERR "Field_values: " . Dumper(\%field_values);
     return ($reference_doctype->Id, \%field_values);
}
     
     
sub make_old_obvius_data_from_hash {
     my ($this, $hash) = @_;
     
     my $data = Obvius::Data->new;
     $data->param($_ => $hash->{$_}) for (keys %$hash);
     return $data;
}
     
sub create_new_internal_proxy_database_entry {
     my ($this, $referrer_docid, $referrer_version, $reference_docid)  = @_;
     my $obvius = $this->{obvius};
     
     $obvius->execute_command('insert into internal_proxy_documents set 
           referrer_version=?, referrer_docid=?, reference_docid=?', 
			      $referrer_version, $referrer_docid, $reference_docid);
}

sub any_cycles_p {
     my ($this, $docid, $docids) = @_;
     $docids ||= [$docid];

     my $query = "select reference_docid as docid from internal_proxy_documents where 
                  referrer_docid = ?";
     
     my $obvius  = $this->{obvius};

     my $result = $obvius->execute_select($query, $docid);
     return 0 if (!@$result);
     
     print STDERR "Result: " . Dumper($result);
     my @docids = map { $_->{docid}} @$result;
     for my $new_docid (@docids) {
	  return 1 if (is_in($new_docid, $docids));
	  my @new_docids = @$docids;
	  push @new_docids, $new_docid;
	  
	  return 1 if ($this->any_cycles_p($new_docid, \@new_docids));
     }

     return 0;
}
sub create_internal_proxy_document {
     my $this = shift;
     my $obvius = $this->{obvius};
     my %options = @_;

     die "Please send me the correct values." 
       if (!$options{parent}			||
	   !$options{name}			|| 
	   !$options{grpid}			|| 
	   !$options{owner}			||
	   !$options{lang}			||
	   !$options{fields}			||
	   ref($options{fields}) ne 'HASH'	|| 
	   !$options{fields}{internal_proxy_path});

     my %fields = %{$options{fields}};
     
     my $reference_docid = $fields{internal_proxy_path};
     my $reference_doc = $obvius->get_doc_by_id($reference_docid);
     die "Couldn't find document: $reference_docid" if (!$reference_doc);

     my ($doctype_id, $fields) = $this->get_fields_doctype_and_version($reference_doc, $options{fields});
     my $compatible_field_values = $this->make_old_obvius_data_from_hash($fields);
     
     my $parent = $obvius->get_doc_by_id($options{parent});
     my $error;
     
     my ($docid, $version) = $obvius->create_new_document (
							    $parent,
							    $options{name},
	                				    $doctype_id,
							    $options{lang},
							    $compatible_field_values,
							    $options{owner},
							    $options{grpid},
							    \$error
							  );
     die $error if ($error);
     
     $this->create_new_internal_proxy_database_entry($docid, $version, $reference_doc->Id);
     return ($docid, $version);
}
     
sub create_internal_proxy_version {
     my $this = shift;
     my $obvius = $this->{obvius};
     my %options = @_;
     
     die "Argument error." if (!$options{docid}			||
			       !$options{lang}			||
			       !$options{owner}			||
			       !$options{fields}		||
			       ref ($options{fields}) ne 'HASH' ||
			       !$options{fields}{internal_proxy_path});
     
     
     my $reference_docid = $options{fields}{internal_proxy_path};
     my $referrer_doc = $obvius->get_doc_by_id($options{docid});
     die "Illegal docid." if (!$referrer_doc);
     die "A document can not proxy itself\n" if ($reference_docid == $referrer_doc->Id);
     die "Error: detected a cycle\n" if ($this->any_cycles_p($reference_docid, [$reference_docid, $options{docid}]));

     my $reference_doc			= 
       $obvius->get_doc_by_id($reference_docid);
     die "Couldn't find document: $reference_docid" if (!$reference_doc);

     my ($doctype_id, $fields)		= 
       $this->get_fields_doctype_and_version($reference_doc, $options{fields});
     my $compatible_field_values	= $this->make_old_obvius_data_from_hash($fields);
     
     my $error;

     my $new_version = $obvius->create_new_version($referrer_doc,
						   $doctype_id,
						   $options{lang},
						   $compatible_field_values);
     
     die "error creating new version" if(!$new_version);

     $this->create_new_internal_proxy_database_entry($options{docid}, $new_version, $reference_doc->Id);

     return $new_version;
}
     

sub find_docs_in_sequence {
     my ($this, $docids) = @_;
     my $obvius = $this->{obvius};

     my @docids = grep { $_ =~ /^\d+$/} @$docids;
     return [] if (!@docids);

     my $docid_query = join ', ', @docids;

print STDERR "here";     
     my $query =<<END_QUERY;
select *
from internal_proxy_documents i
where i.reference_docid in ($docid_query);
END_QUERY

     my $query_result = $obvius->execute_select($query);
     print STDERR Dumper($query_result);
     my @relations = ( @$query_result, @{$this->get_proxy_stack($query_result)});
     
     print STDERR Dumper(\@relations);
     return \@relations;
}

sub get_proxy_stack {
     my ($this, $docid_versions, $count) = @_;
     my $obvius = $this->{obvius};

     if (!$count) {
	  $count = 1;
     } else {
	  $count++;
     }
     if ($count >= 10) {
	  die "Horrible recursion problem. Somebody has directed a document to itself (probably).";
	  return [];
     }     
     my $docid_query = join ',', map { $_->{referrer_docid} } @$docid_versions;
     
     my $query =  "select *
                   from internal_proxy_documents i where (reference_docid) in 
                   ($docid_query);";
     
     my $result = $obvius->execute_select($query);
     return [] if (!@$result);

     my @new_result = (@$result, @{$this->get_proxy_stack($result, $count)});
     return \@new_result;
}
     
     
sub check_and_update_internal_proxies {
     my ($this, $docids) = @_;
     
     my $docs_versions = $this->find_docs_in_sequence($docids);
     
     print STDERR Dumper($docs_versions);
     $docs_versions = $this->find_nice_order($docs_versions);
     print STDERR "Hello: " . Dumper($docs_versions);
     $this->{obvius}->db_begin;
     $this->update_proxy($_) for (@$docs_versions);
     $this->{obvius}->db_commit;
     print STDERR "Here";
}


sub depends_on {
     my ($dv, $dv2) = @_;
     
     return ($dv->{reference_docid} == $dv2->{referrer_docid});
}

sub is_in {
     my ($v, $m) = @_;
     
     return scalar(grep {$v == $_} @$m);
}

sub setup_dependencies { 
     my ($doc_versions) = @_;
     
     for my $dv (@$doc_versions) {
	  for my $dv2 (@$doc_versions) {
	       if (depends_on($dv, $dv2)) {
		    $dv->{dependencies} ||= [];
		    push @{$dv->{dependencies}}, $dv2->{id};
	       }
	  }
     }
}

sub remove_from_list {
     my ($v, $m) = @_;
     
     @$m = grep { $v != $_} @$m;
}

sub topological_sort {
     my ($dvs) = @_;
     
     my @L;
     my @Q = grep { !($_->{dependencies}) || !(@{$_->{dependencies}})} @$dvs;
     
     while (my $node = shift @Q) {
	  push @L, $node;
	  for my $node2 (@$dvs) {
	       if ($node2->{dependencies} && is_in($node->{id}, $node2->{dependencies})) {
		    remove_from_list($node->{id}, $node2->{dependencies});
		    push @Q,$node2 if (!@{$node2->{dependencies}});
	       }
	  }
     }

     return \@L;
}
	       
sub find_nice_order {
     my ($this, $dvs) = @_;

     setup_dependencies($dvs);
     my $l = topological_sort($dvs);
     return $l;
}
     
sub update_proxy {
     my ($this, $dv) = @_;
     my $obvius = $this->{obvius};
     
     my $doc = $obvius->get_doc_by_id($dv->{reference_docid});

     my ($doctype_id, $fields) = eval {$this->get_fields_doctype_and_version($doc, {})};
     if ($@) {
	  warn $@;
	  return;
     }
     
     print STDERR Dumper($dv);
     $this->run_copy_query($dv->{id}, $fields);
     $obvius->register_modified(docid => $dv->{referrer_docid}, dont_internal_proxy_this => 1);
}
     
sub run_copy_query {
     my ($this, $id, $fields) = @_;
     
     my $obvius = $this->{obvius};

     my $field_names = join ",", map { '"' . $_ . '"' } keys %$fields;
     
     my $query = <<END_QUERY;
update 
 internal_proxy_documents i 
  join
     (select docid, version, public,type from versions v2 where 
      public = 1 or version=
           (select max(version) from versions v3 where v2.docid=v3.docid )
      group by docid having (public = max(public))) v on (i.reference_docid = v.docid)
  join 
  vfields vf on (vf.docid = v.docid and vf.version = v.version) join
  vfields vf2 on (i.referrer_version = vf2.version and 
                  i.referrer_docid   = vf2.docid and vf.name=vf2.name) join
  versions v4 on (vf2.docid = v4.docid and vf2.version = v4.version) 
                  set v4.type = v.type, vf2.text_value = vf.text_value, vf2.double_value = vf.double_value,
                      vf2.int_value = vf.int_value, vf2.date_value = vf.date_value 
                   where vf.name in ($field_names) and i.id = ?;
END_QUERY

     $obvius->execute_command($query, $id);
}

1;
