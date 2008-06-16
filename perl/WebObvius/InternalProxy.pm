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

sub make_old_obvius_data_from_hash {
     my ($this, $hash) = @_;
     
     my $data = Obvius::Data->new;
     $data->param($_ => $hash->{$_}) for (keys %$hash);
     return $data;
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

     my $doctype_id = $this->get_doctype($reference_doc);
     
     my $compatible_field_values = $this->make_old_obvius_data_from_hash(\%fields);

     my @overloaded_fields = @overloaded_vfields;
     push @overloaded_fields, "rightboxes" if ($fields{internal_proxy_overloaded_vfields});
	  
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
     
     $this->new_internal_proxy_entry($docid, $reference_doc->Id, \@overloaded_fields);
     return ($docid, $version);
}
     
sub new_internal_proxy_entry {
     my ($this, $docid, $depends_on, $fields) = @_;
     
     my $query = "call new_internal_proxy_entry(?, ?, ?);"

     my $str = join @$fields, ",";
     my $res = $this->{obvius}->execute_transaction($query, $docid, $depends_on, $str);
     
     die "Error creating internal_proxy_entry: $res\n" if ($res);
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

     $this->new_internal_proxy_databasen_entry($options{docid}, $new_version, \@overloaded_fields);

     return $new_version;
}
     
sub check_and_update_internal_proxies {
     my ($this, $docids) = @_;
     
     return if (!@$docids);
     my $res = $this->{obvius}->execute_transaction(join ',', @$docids );
     warn $res if ($res);
     return $res;
}

1;
