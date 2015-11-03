package WebObvius::InternalProxy;

use strict;
use warnings;

use Data::Dumper;
use Obvius;
use Obvius::Data;

my @overloaded_vfields = qw(
    title
    show_title
    short_title
    seq
    internal_proxy_path
    internal_proxy_overload_rightboxes
    internal_proxy_overload_tags
);

sub new {
     my ($class, $obvius) = @_;
     die "Illegal argument" if (ref($obvius) ne 'Obvius');
     return bless {obvius => $obvius}, $class;
}

sub can_preview {
     return 0;
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

sub get_attrib {
     my ($this, $vdoc, @attribs) = @_;
     
     my $attribs = join ',', (map { "\"$_\"" } grep {/^[\w\d_]+$/} @attribs);
     
     my $sel_res = $this->{obvius}->execute_select("select name, text_value, int_value, 
                                            double_value, date_value from vfields
                                            where docid = ? and version = ? and name in ($attribs)", 
                                            $vdoc->Docid, $vdoc->Version);
     my %res;
     for my $elem (@$sel_res) {
          my $name = lc $elem->{name};
          my $val = $elem->{text_value} || 
                    $elem->{int_value} ||
                    $elem->{date_value} ||
                    $elem->{double_value};
          if ($res{$name}) {
               if (ref $res{$name} eq 'ARRAY') {
                    push @{$res{$name}}, $val;
               } else {
                    $res{$name} = [$res{$name}, $val];
               }
          } else {
               $res{$name} = $val;
          }
     }
     return \%res;
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
     
     my $compatible_field_values = $this->make_old_obvius_data_from_hash(\%fields);

     my @overloaded_fields = @overloaded_vfields;
     push @overloaded_fields, "rightboxes" if (!$fields{internal_proxy_overload_rightboxes});
     push @overloaded_fields, "tags" if (!$fields{internal_proxy_overload_tags});
	  
     my $parent = $obvius->get_doc_by_id($options{parent});
     my $error;

    my ($docid, $version) = $obvius->create_new_document (
        $parent,
        $options{name},
        $doctype_id->Id,
        $options{lang},
        $compatible_field_values,
        $obvius->get_userid($options{owner}),
        $options{grpid},
        \$error
    );
     die $error if ($error);

     $this->new_internal_proxy_entry($docid, $version, $reference_doc->Id, \@overloaded_fields);
     
     eval {
	  $obvius->dbprocedures->add_vfield({
					     docid => $docid, 
					     version => $version, 
					     name => "internal_proxy_path",
					     int_value => $fields{internal_proxy_path}
					    });
	  $obvius->dbprocedures->add_vfield({
					     docid => $docid, 
					     version => $version, 
					     name => "internal_proxy_overload_rightboxes",
					     int_value => $fields{internal_proxy_overload_rightboxes}
					    });
	  $obvius->dbprocedures->add_vfield({
					     docid => $docid, 
					     version => $version, 
					     name => "internal_proxy_overload_tags",
					     int_value => $fields{internal_proxy_overload_tags}
					    });
     };
     warn @$ if ($@);
     
				      
     return ($docid, $version);
}
     
sub new_internal_proxy_entry {
     my ($this, $docid, $version, $depends_on, $fields) = @_;
     
     my $str = join ",", @$fields;
     eval {
          $this->{obvius}->dbprocedures->new_internal_proxy_entry($docid, $version, 
                                                                  $depends_on, $str); 
     };
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

     my $doctype = $this->get_doctype($reference_doc);
     my $compatible_field_values	= $this->make_old_obvius_data_from_hash(\%fields);
     
     my $error;

     my $new_version = $obvius->create_new_version($referrer_doc,
						   $doctype->Id,
						   $options{lang},
						   $compatible_field_values);
     
     die "error creating new version" if(!$new_version);

     my @overloaded_fields = @overloaded_vfields;
     push @overloaded_fields, "rightboxes" if (!$fields{internal_proxy_overload_rightboxes});
     push @overloaded_fields, "tags" if (!$fields{internal_proxy_overload_tags});
     
     $this->new_internal_proxy_entry($options{docid}, $new_version, $fields{internal_proxy_path}, \@overloaded_fields);
     eval {
	  $obvius->dbprocedures->add_vfield({
					     docid => $referrer_doc->Id, 
					     version => $new_version, 
					     name => "internal_proxy_path",
					     int_value => $fields{internal_proxy_path}
					    });
	  
	  $obvius->dbprocedures->add_vfield({
					     docid => $referrer_doc->Id, 
					     version => $new_version, 
					     name => "internal_proxy_overload_rightboxes",
					     int_value => $fields{internal_proxy_overload_rightboxes}
					    });

	  $obvius->dbprocedures->add_vfield({
					     docid => $referrer_doc->Id, 
					     version => $new_version, 
					     name => "internal_proxy_overload_tags",
					     int_value => $fields{internal_proxy_overload_tags}
					    });
     };
     warn $@ if ($@);

     return $new_version;
}
     
sub update_internal_proxies {
     my ($this, $docids) = @_;
     
     $docids = [$docids] if (!ref($docids));
     return if (!@$docids);
     eval { $this->{obvius}->dbprocedures->update_internal_proxy_docids(join ',', @$docids )};
     warn $@ if ($@);
     
     my $docids_template = join ',', (('?') x @$docids);
     my $updated = $this->{obvius}->execute_select("select distinct docid from 
                                                    internal_proxy_documents where 
                                                    dependent_on in ($docids_template)",
                                                   @$docids);
     
     $this->{obvius}->register_modified(docid => $_) for (map { $_->{docid} } @$updated);
}

1;
