package WebObvius::InternalProxy;

use strict;
use warnings;

use Data::Dumper;
use Obvius;
use Obvius::Data;

my @overloaded_vfields = qw( title short_title seq internal_proxy_path internal_proxy_overload_rightboxes );

sub new {
     my ($class, $obvius) = @_;
     die "Illegal argument" if (ref($obvius) ne 'Obvius');
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
     my $obvius = $this->{obvius};

     my $version = $obvius->get_public_version($doc) || $obvius->get_latest_version($doc);
     die "Couldn't get version." if (!$version);

     my $reference_doctype = $obvius->get_version_type($version);
     die "Couldn't get doctype." if (!$reference_doctype);
     return $reference_doctype;
}

sub make_old_obvius_data_from_hash {
     my ($this, $hash) = @_;
     
     my $data = Obvius::Data->new;
     $data->param($_ => $hash->{$_}) for (keys %$hash);
     return $data;
}
     
sub create_internal_proxy_document {
     my ($this, %options) = @_;

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
     my $obvius = $this->{obvius};
     
     my $reference_docid = $fields{internal_proxy_path};
     my $reference_doc = $obvius->get_doc_by_id($reference_docid);
     die "Couldn't find document: $reference_docid" if (!$reference_doc);

     my $doctype_id = $this->get_doctype($reference_doc);
     warn $doctype_id;
     
     my $compatible_field_values = $this->make_old_obvius_data_from_hash(\%fields);

     my @overloaded_fields = @overloaded_vfields;
     push @overloaded_fields, "rightboxes" if ($fields{internal_proxy_overloaded_rightboxes});
	  
     my $parent = $obvius->get_doc_by_id($options{parent});
     my $error;
     
     my ($docid, $version) = $obvius->create_new_document (
							    $parent,
							    $options{name},
	                				    $doctype_id->Id,
							    $options{lang},
							    $compatible_field_values,
							    $options{owner},
							    $options{grpid},
							    \$error
							  );
     die $error if ($error);
     
     $this->dbprocedures->add_vfield({docid => $docid, 
				      version => $version, 
				      name => "internal_proxy_overloaded_rightboxes",
				      int_value => $fields{internal_proxy_overloaded_rightboxes}});
     $this->dbprocedures->add_vfield({docid => $docid, 
				      version => $version, 
				      name => "internal_proxy_path",
				      int_value => $fields{internal_proxy_path}});
     
				      
     $this->new_internal_proxy_entry($docid, $reference_doc->Id, \@overloaded_fields);
     return ($docid, $version);
}
     
sub new_internal_proxy_entry {
     my ($this, $docid, $depends_on, $fields) = @_;
     
     my $str = join ",", @$fields;
     eval {$this->{obvius}->dbprocedures->new_internal_proxy_entry($docid, $depends_on, $str); };
     if ($@) {
	  die "Error creating internal_proxy_entry: $@\n";
     }
	  
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

     my $reference_doc			= 
       $obvius->get_doc_by_id($reference_docid);
     die "Couldn't find document: $reference_docid" if (!$reference_doc);

     my $doctype_id = $this->get_fields_and_doctype($reference_doc);
     my $compatible_field_values	= $this->make_old_obvius_data_from_hash(\%fields);
     
     my $error;

     my $new_version = $obvius->create_new_version($referrer_doc,
						   $doctype_id,
						   $options{lang},
						   $compatible_field_values);
     
     die "error creating new version" if(!$new_version);

     my @overloaded_fields = @overloaded_vfields;
     push @overloaded_fields, "rightboxes" if ($fields{internal_proxy_overloaded_vfields});

     $this->dbprocedures->add_vfield({
				      docid => $referrer_doc->Id, 
				      version => $new_version, 
				      name => "internal_proxy_overloaded_rightboxes",
				      int_value => $fields{internal_proxy_overloaded_rightboxes}
				     });
     $this->dbprocedures->add_vfield({
				      docid => $referrer_doc->Id, 
				      version => $new_version, 
				      name => "internal_proxy_path",
				      int_value => $fields{internal_proxy_path}
				     });

     $this->new_internal_proxy_databasen_entry($options{docid}, $new_version, \@overloaded_fields);

     return $new_version;
}
     
sub update_internal_proxies {
     my ($this, $docids) = @_;
     
     $docids = [$docids] if (!ref($docids));
     return if (!@$docids);
     eval { $this->{obvius}->dbprocedures->update_internal_proxy_docids(join ',', @$docids )};
     warn $@ if ($@);
}

1;
