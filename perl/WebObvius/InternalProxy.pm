package Obvius::WebObvius::InternalProxy;

use strict;
use warnings;

use Obvius;
use Obvius::Data;

my @overloaded_vfields = qw( title short_title seq rightboxes );

sub new {
     my ($class, $obvius) = @_;
     return bless {obvius => $obvius}, $class;
}

sub is_internal_proxy_document {
     my ($this, $docid) = @_;
     
     my $obvius = $this->{obvius};

     my $query = <<END;
select * from documents d inner join internal_proxy_documents id on (id.docid = d.id) 
where id.docid = ?;
END
     my $res = @{$obvius->execute_select($query, $docid)};
     
     return $res;
}

sub get_fields_doctype_and_version {
     my ($this, $reference_doc, $fields) = @_;;
     my $obvius = $this->{obvius};

     my $version = $obvius->get_public_version($referred_doc) || $obvius->get_latest_version($referred_doc);
     die "Couldn't get version." if (!$version);
     
     my $reference_doctype = $obvius->get_version_type($version);
     die "Couldn't get doctype." if (!$reference_doctype) 

     my @fieldnames = map {lc} @{$reference_doctype->field_names};
     die "No fieldnames" if (!@fieldnames);

     my %field_values = map {
	  lc($_->{name}) => $_->{text_value} || $_->{int_value} || $_->{date_value} || $_->{double_value}
     }
       @{$obvius->execute_select("select * from vfields where docid=? and version=?", 
				 $reference_doc->Id, $version->Version)};
     
     %field_values = %fields_values{@fieldnames};
     for my $field (@overloaded_vfields) {
	  if ($fields{$field}) {
	       $field_values{$_} = $fields{$_};
	  } else {
	       delete $field_values{$_};
	  }
     }
     return ($version, $reference_doctype->Id, \%field_values);
}
     
     
sub make_old_obvius_data_from_hash {
     my ($this, $hash) = @_;
     
     my $data = Obvius::Data->new;
     $data->param{$_ => $hash->{$_}} for (keys %$hash);
     return $data;
}
     
sub create_new_internal_proxy_database_entry {
     my ($this, $referrer_docid, $referrer_version, $reference_docid, $reference_version)  = @_;
     my $obvius = $this->{obvius};
     
     $obvius->execute_command('insert into internal_proxy_documents set 
           referrer_version=?, referrer_docid=?, reference_docid=?, reference_version=?', 
			      $referrer_docid, $referrer_version, $reference_docid, $reference_version);
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
	   !$options{fields}{path});


     my $reference_path = $fields{path};
     my $reference_doc = $obvius->lookup_document($refered_path);
     die "Couldn't find document: $reference_path" if (!$reference_doc);

     my ($reference_version, $doctype_id, $fields) = $this->get_fields_and_doctype($reference_doc, $options{fields});
     my $compatible_field_values = $this->make_old_obvius_data_from_hash($fields);

     my $error;
     my ($docid, $version) = $obvius->create_new_document (
							    $options{parent},
							    $options{name},
	                				    $doctype_id,
							    $options{lang},
							    $compatible_field_values,
							    $options{owner},
							    $options{grpid},
							    \$error
							  );
     die $error if ($error);
     
     $this->create_new_internal_proxy_entry($docid, $version, $reference_doc->Id, $reference_version->Version);
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
			       !ref{$options}{path});
     

     my $referrer_doc = $obvius->get_doc_by_docid($options{docid});
     die "Illegal docid." if (!$referrer_doc);

     my $reference_doc			= 
       $obvius->lookup_document($refered_path);
     die "Couldn't find document: $reference_path" if (!reference_doc);

     my ($reference_version, $doctype_id, $fields)		= 
       $this->get_fields_and_doctype($reference_doc, $options{fields});
     my $compatible_field_values	= $this->make_old_obvius_data_from_hash($fields);
     
     my $error;
     my $new_version = $obvius->create_new_version($referrer_doc,
						   $doctype_id,
						   $options{lang},
						   $compatible_field_values);
     
     die "error creating new version" if(!$new_version);

     $this->create_new_internal_proxy_entry($options{docid}, $version, $reference_doc->Id, $reference_version->Version);

     return $version;
}
     

sub find_docs_in_sequence {
     my ($this, $docids) = @_;
     my $obvius = $this->{obvius};

     my @docids = grep { $_ =~ /^\d+$/} @$docids;
     return [] if (!@docids);

     my $docid_query = join ', ', @docids;
     
     my $query = "select i2.reference_docid as docid, i2.reference_version as version 
                  from internal_proxy_documents i2
                  where i2.reference_docid in ($docid_query) and 
                  not exists 
                   (select * from versions v inner join internal_proxy_documents i on 
                   (v.docid = i.reference_docid and v.version = i.reference_version)
                   where v.public = 1 and i2.reference_docid = v.docid and i2.reference_version = v.version)"
     
     my $query_result = $obvius->execute_select($query);
     my @irrelevant_docids = map { $_->{docid} }  @$query_result;
     my @relevant_docids = grep { my $a = $_; !(grep { $a == $_} @irrelevant_docids)} @docids;
     return [] if (!@relevant_docids);
     
     my $docid_versions = $this->get_proxy_stack($query_result);
     # It is important to keep these docids in sequence, so that all dependencies, come first.
     
     return $docid_versions;
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
	  warn "Horrible recursion problem. Somebody has directed a document to itself (probably).";
	  return [];
     }     
     my $docid_version_query = join ',', map { '(' . $_->{docid} . ', "' . $_->{version} . '")' } @$docid_versions;
     
     my $obvius = $this->{obvius};
     my $query =  "select *
                   from internal_proxy_documents i where (reference_docid, reference_version) in 
                   ($docid_version_query);";
     
     my $result = $obvius->execute_select($query);
     
     return [] if (!@$result);

     my @arguments = map { {version => $_->{referrer_version}, docid => $_->{referrer_docid}}} @$result;
     my @new_result = (@$result, @{$this->get_proxy_stack(@arguments, $count)});
     return \@new_result;
}
     
     
sub check_and_update_internal_proxies {
     my ($this, $docids) = @_;
     
     my $docs_versions = $this->find_docs_in_sequence($docids);
     
     my @relevant;
     for my $doc_version ($docs_versions) {
	  push @relevant, $doc_version 
	    if (! grep { 
		     $doc_version->{id} == $_->{id}
		} @relevant;
	       );
     $this->update_proxy($_) for (@relevant);
}
     
sub update_references {
     my ($this, $id, $docid, $version) = @_;
     
     my $query = "update set reference_docid=?, reference_version=? where id=?";
     $this->{obvius}->execute_command($query, $docid, $version, $id);
}
                  
sub update_proxy {
     my ($this, $dv) = @_;
     my $obvius = $this->{obvius};
     
     my $doc = $obvius->get_doc_by_id($dv->{reference_docid});

     my ($version, $doctype_id, $fields) = eval {$this->get_field_doctype_and_version($doc, {})};
     if ($@) {
	  warn $@;
	  return;
     }
     
     $this->update_references($dv->{id}, $dv->{reference_docid}, $version->Version);
     
     $this->run_copy_query($dv->{id}, $fields);
}
     
sub run_copy_query {
     my ($this, $id, $fields) = @_;
     
     my $field_names = join ",", map { '"' . $_ . '"' } keys %$fields;
     
     my $query = "update vfields vf join internal_proxy_documents i on 
                  (vf.docid = i.reference_document and vf.version = i.reference_version) join
                  vfields vf2 on (i.referrer_version = vf2.version and 
                                  i.referrer_docid = vf2.docid and vf.name=vf2.name)
                  set vf2.text_value = vf.text_value, vf2.double_value = vf.double_value,
                      vf2.int_value = vf.int_value, vf2.date_value = vf.date_value 
                   where vf.name in ($field_names) and i.id = ?";
     $obvius->execute_command($query, $id);
}

                      
