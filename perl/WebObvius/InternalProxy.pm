package WebObvius::InternalProxy;

use strict;
use warnings;

use Data::Dumper;
use Obvius;
use Obvius::Data;

my @overloaded_vfields = qw( title short_title seq internal_proxy_path internal_proxy_overload_rightboxes );

sub new {
     my ($class, $obvius) = @_;
     return bless {obvius => $obvius}, $class;
}

sub is_internal_proxy_document {
     my ($this, $docid) = @_;
     
     my $obvius = $this->{obvius};

     my $query = "call is_internal_proxy_document();";
     my $res = $obvius->execute_select($query, $docid)->[0]{is_};
     
     return $res;
}

sub get_doctype {
     my ($this, $doc) = @_;
     my $version = $obvius->get_public_version($reference_doc) || $obvius->get_latest_version($reference_doc);
     die "Couldn't get version." if (!$version);

     my $reference_doctype = $obvius->get_version_type($version);
     die "Couldn't get doctype." if (!$reference_doctype);
     return $reference_doctype;
}

sub get_fields_and_doctype {
     my ($this, $reference_doc) = @_;;
     my $obvius = $this->{obvius};

     my $version = $obvius->get_public_version($reference_doc) || $obvius->get_latest_version($reference_doc);
     die "Couldn't get version." if (!$version);

     my $reference_doctype = $obvius->get_version_type($version);
     die "Couldn't get doctype." if (!$reference_doctype);

     my @fieldnames = map { lc } @{$reference_doctype->fields_names};
     die "No fieldnames" if (!@fieldnames);

     my $vfields = $obvius->execute_select("select * from vfields where docid=? and version=?", 
					   $reference_doc->Id, $version->Version);

     my %fields;
     for my $field (@$vfields) {
	 $fields{$field->{name}} ||= [];
	 my $val = $field->{text_value} || $field->{int_value} || $field->{double_value} || $field->{date_value}
	 push @{$fields{$field->{name}}}, $val;
    }
     
     return ($reference_doctype->Id, \%fields);
}
     

sub assemble_fields {
     my ($this, $referrer_fields, $reference_fields) = @_;

     my %fields = %$reference_fields;
     
     for my $field (@overloaded_vfields) {
	  $fields{$field} = [$referrer_fields->{$field}]
     }

     if ($referrer_fields->{internal_proxy_overload_rightboxes}) {
	  $fields{rightboxes} = $referrer_fields->{rightboxes};
     }
     
     return \%fields;
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

     my ($doctype_id, $fields) = $this->get_fields_and_doctype($reference_doc);
     $fields = $this->assemble_fields(\%fields, $fields);
     
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
     
     
     my %fields = %{$options{fields}};

     my $reference_docid = $options{fields}{internal_proxy_path};
     my $referrer_doc = $obvius->get_doc_by_id($options{docid});
     die "Illegal docid." if (!$referrer_doc);
     die "A document can not proxy itself\n" if ($reference_docid == $referrer_doc->Id);
     die "Error: detected a cycle\n" if ($this->any_cycles_p($reference_docid, [$reference_docid, $options{docid}]));

     my $reference_doc			= 
       $obvius->get_doc_by_id($reference_docid);
     die "Couldn't find document: $reference_docid" if (!$reference_doc);

     my ($doctype_id, $fields) = $this->get_fields_and_doctype($reference_doc);
     $fields = $this->assemble_fields(\%fields, $fields);
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
     
sub endemic_fields {
     my ($this, $docid, $version) = @_;

     my @fields = (@overloaded_fields, ('rightboxes'));
     my $fields_query = join ",", map { '"' . $_ . '"' } @fields;

     my $query = "select * from vfields where docid=? and version=? and name in ($field_query);";
     
     my $fields = $this->{obvius}->execute_select($query, $docid, $version);

     my %fields;
     for my $field (@$fields) {
	 $fields{$field->{name}} ||= [];
	 my $val = $field->{text_value} || $field->{int_value} || $field->{double_value} || $field->{date_value}
	 push @{$fields{$field->{name}}}, $val;
    }
}

sub update_proxy {
     my ($this, $dv) = @_;
     my $obvius = $this->{obvius};
     
     my $doc = $obvius->get_doc_by_id($dv->{reference_docid});

     my $endemic_fields = eval { $this->endemic_fields($dv->{referrer_docid}, $dv->{referrer_version})};
     if ($@) {
	  warn $@;
	  return;
     }

     my ($doctype_id, $fields) = eval {$this->get_fields_doctype_and_version($doc)};
     if ($@) {
	  warn $@;
	  return;
     }

     $fields = $this->assemble_fields($endemic_fields, $fields);
     $this->run_copy_query($dv, $fields);
     $obvius->register_modified(docid => $dv->{referrer_docid}, dont_internal_proxy_this => 1);
}

sub run_copy_query {
     my ($this, $dv, $fields) = @_;

     my $delete_query = "delete v from internal_proxy_documents i join vfields v on
                         (v.docid = i.referrer_docid AND v.version = i.referrer_version) where 
                         i.id = ?";
     
     $this->execute_command($delete_query, $dv->{id});
     
     my $data_fields = $this->make_old_obvius_data_from_hash($fields);
     $obvius->db_insert_vfields($dv->{referrer_docid}, $dv->{referrer_version}, $data_fields);
     
     my $update_query = <<END
update versions v join internal_proxy_documents i on 
                        (i.referrer_docid = v.docid and i.referrer_version = v.version) join
                        (select docid, version, public,type from versions v2 where 
                          public = 1 or version=
                          (select max(version) from versions v3 where v2.docid=v3.docid )
                          group by docid having (public = max(public))) ve on 
                          (i.reference_docid = v.docid)
                         set v.type = ve.type where i.id = ?;
END

     $obvius->execute_command($update_query, $dv->{id});
}

1;
