package Obvius::MultiSite;

use strict;
use warnings;

require Exporter;
use Obvius;
use Obvius::UriCache;

our @ISA = qw( Obvius Obvius::UriCache Exporter );
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub new {
    my($class, $obvius_config, $user, $password, $doctypes, $fieldtypes, $fieldspecs, %options) = @_;

    my $this = $class->SUPER::new($obvius_config, $user, $password, $doctypes, $fieldtypes, $fieldspecs, %options);

    # Store siteroot
    if(my $siteroot = $options{siteroot}) {
        $this->{SITEROOT} = $siteroot;
        if($options{rootid}) {
            $this->{ROOTID} = $options{rootid};
        } else {
            my $rootdoc = $this->lookup_document($siteroot, break_siteroot => 1);
            if($rootdoc) {
                $this->{ROOTID} = $rootdoc->Id;
            } else {
                die "Couldn't lookup root document $this->{SITEROOT}";
            }
        }
    } else {
        $this->{SITEROOT} = '';
        $this->{ROOTID} = 1; # XXX root ref
    }

    return $this;
}


# Special methods using the new root:

sub get_root_document
{
    my ($this, %options) = @_;

    if($options{break_siteroot}) {
        return $this->get_doc_by_id(1); # XXX asumes top root is always 1
    } else {
        return $this->get_doc_by_id($this->{ROOTID});
    }
}

sub get_doc_by_path {
    my ($this, $uri, $path_info, %options) = @_;

    $this->tracer($uri, $path_info||'') if ($this->{DEBUG});

    if ($uri =~ /^\/(\d+).docid\/?$/) {
        return ($this->get_doc_by_id($1));
    }

    my $id = $options{break_siteroot} ? 1 : $this->{ROOTID};
    my $root = $this->get_doc_by_id($id);
    return () unless ($root);

    my @path = ($root);
    if ($uri eq '/') {
        $$path_info = undef if (defined $path_info);
        return @path;
    }

    my @uri = split('/+', $uri);

    shift(@uri);
    while (my $name = shift(@uri)) {
        my $vec;
        my $parent;

        $this->{LOG}->debug("get_doc_by_path: searching $name parent $id");

        $parent = $this->get_doc_by_name_parent($name, $id);
        unless ($parent) {
            return () unless ($path_info);

            $$path_info = join('/', $name, @uri);
            return @path;
        }

        $id = $parent->_id;
        $this->{LOG}->debug("get_doc_by_path: got id $id");

        push(@path, $parent);
    }

    $this->{LOG}->debug("get_doc_by_path: done");

    $$path_info = undef if (defined $path_info);
    return @path;
}

sub get_doc_path {
    my ($this, $doc, %options) = @_;

    $this->tracer($doc) if ($this->{DEBUG});

    my $rootid = $options{break_siteroot} ? 1 : $this->{ROOTID};

    my @path = ( $doc );
    while ($doc->_id != $rootid and $doc->_id != 1) {
        my $parent = $this->get_doc_by_id($doc->_parent);
        unshift(@path, $parent);
        $doc = $parent;
    }

    return @path;
}

sub get_doc_uri {
    my ($this, $doc, %options) = @_;

    my @path = $this->get_doc_path($doc, %options);
    shift(@path);			# remove root

    return '/' unless (@path);
    my $uri = '/' . join('/', map { $_->param('name') } @path) . '/';
    $uri =~ s!/+!/!g;
    return $uri;
}


sub lookup_document {
    my ($this, $path, %options) = @_;

    $this->tracer($path) if ($this->{DEBUG});

    if (wantarray) {
        my $path_info;
        if (my @path = $this->get_doc_by_path($path, \$path_info, %options)) {
            return ($path[-1], $path_info);
        }
        return ();
    }

    if (my @path = $this->get_doc_by_path($path, undef, %options)) {
        return $path[-1];
    }
    return undef;
}

##################################################################
#
#                       URI caching stuff
#
##################################################################


sub delete_document {
    my ($this, $doc) = @_;

    die "User $this->{USER} does not have access to delete the document."
        unless $this->can_delete_document($doc);

    $this->db_begin;
    eval {
        die "Document has sub documents\n"
            if ($this->get_docs_by_parent($doc->Id));

        $this->{LOG}->info("====> Deleting fields ... delete from vfields");
        $this->db_delete_vfields($doc->Id);
        $this->{LOG}->info("====> Deleting versions ... delete from versions");
        $this->db_delete_versions($doc->Id);

        # We could delete docparms as well:
        # We could delete voters and votes as well:

        $this->{LOG}->info("====> Deleting document ... delete from subscriptions");
        $this->db_delete_subscriptions($doc->Id);

        $this->{LOG}->info("====> Deleting document ... delete from comments");
        $this->db_delete_comments($doc->Id);

        $this->{LOG}->info("====> Deleting document ... delete from document");
        $this->db_delete_document($doc->Id);

        $this->{LOG}->info("====> Deleting document ... COMMIT");
        $this->db_commit;
    };

    if ($@) {			# handle error
        $this->{DB_Error} = $@;
        $this->db_rollback;
        $this->{LOG}->error("====> Deleting document ... failed ($@)");
        return undef;
    }

    undef $this->{DB_Error};

    $this->{LOG}->info("====> Deleting document ... removing from URI cache");
    $this->remove_from_uricache($doc);

    $this->{LOG}->info("====> Deleting document ... done");
    return 1;
}

sub rename_document {
    my ($this, $doc, $new_uri) = @_;

    die "User $this->{USER} does not have access to rename/move the document."
        unless $this->can_rename_document($doc);

    $new_uri =~ s/[.]html?$//;
    return undef unless ($new_uri);

    my $old_uri = $this->get_doc_uri($doc, break_siteroot => 1);

    # Split path from name:
    my @new_path=grep {defined $_ and $_ ne ''} split m!/!, $new_uri;
    foreach (@new_path) {
        unless (/^[a-zA-Z0-9._-]+$/) {
            $this->log->warn("Bad characters in name");
            return undef;
        }
    }
    my $new_name=pop @new_path;
    my $new_path='/' . join '/', @new_path;

    # Find the new parent:
    my $new_parent=$this->lookup_document($new_path);
    unless ($new_parent) {
        warn "Parent does not exist";
        return undef;
    }

    # Does the document exists already?
    if ($this->lookup_document("$new_path/$new_name")) {
        warn "Another document by that name already exists";
        return undef;
    }

    # Don't move below myself:
    my @new_path_docs=$this->get_doc_by_path($new_path);
    foreach (@new_path_docs) {
        next unless defined $_;
        if ($_->Id eq $doc->Id) {
            $this->log->warn("Won't move document under itself");
            return undef;
        }
    }

    $this->db_begin;
    eval {
        $this->{LOG}->info("====> Renaming/moving document ...");
        $doc->param(parent=>$new_parent->Id);
        $doc->param(name=>$new_name);
        $this->db_update_document($doc, [qw(parent name)]);

        $this->{LOG}->info("====> Renaming/moving document ... COMMIT");
        $this->db_commit;
    };

    if ($@) {			# handle error
        $this->{DB_Error} = $@;
        $this->db_rollback;
        $this->{LOG}->error("====> Renaming/moving document ... failed ($@)");
        return undef;
    }

    undef $this->{DB_Error};

    # The URI cache for the document and its subdocs should be rebuild
    $this->{LOG}->info("====> Renaming/moving document ... Rebuilding URI cache");
    $this->rebuild_uricache_for_uri_recursive($old_uri);

    $this->{LOG}->info("====> Renaming/moving document ... done");
    return 1;
}

sub create_new_document {		# RS 20010819 - ok
    my ($this, $parent, $name, $type, $lang, $fields, $owner, $grp, $error) = @_;

    die "User " . $this->{USER} . " does not have access to create a document here (" .
        $parent->Id . " " . $parent->Name . ")."
            unless $this->can_create_new_document($parent);

    die "create_new_document needs an owner and a group"
        unless (defined $owner and defined $grp);

    # Procedure:
    # validate, insert document, insert version, insert fields, end.

    # Doctype specific handler will be called after having validated
    # the doctype.

    my ($docid, $version);

    $this->db_begin;
    eval {
        die "Parent object is not an Obvius::Document\n"
            unless (ref $parent and $parent->UNIVERSAL::isa('Obvius::Document'));

        die "Document name is malformed\n" unless ($name and $name =~ /^[a-zA-Z0-9._-]+$/);

        my $newdoc = $this->get_doc_by_name_parent($name, $parent->param('id'));
        die "Document already exists\n" if ($newdoc);

        my $doctype = $this->get_doctype_by_id($type);
        die "Document type does not exist\n" unless ($doctype);

        if($doctype->UNIVERSAL::can('create_new_version_handler')) {
            my $retval = $doctype->create_new_version_handler($fields, $this);
            die "Doctype specific new_version handler failed" unless($retval == OBVIUS_OK);
        }

        die "Language code invalid\n" unless ($lang and $lang =~ /^\w\w(_\w\w)?$/);

        die "Fields object has no param() method\n"
            unless (ref $fields and $fields->UNIVERSAL::can('param'));

        my %status = $doctype->validate_fields($fields, $this);
        warn "Invalid fields stored anyway: @{$status{invalid}}\n" if ($status{invalid});
        warn "Missing fields stored undef: @{$status{missing}}\n" if ($status{missing});
        warn "Excess fields not stored: @{$status{excess}}\n" if ($status{excess});

        my @fields = @{$status{valid}};
        # Same as new_version:
        push @fields, @{$status{invalid}}
            if ($status{invalid});
        # This is necessary for searching; missing fields has to be in the database,
        # but with the undef/NULL value.
        push @fields, @{$status{missing}}
            if ($status{missing});

        $this->{LOG}->info("====> Inserting new document ... insert into documents");
        $docid = $this->db_insert_document($name, $parent->param('id'), $type, $owner, $grp);

        $this->{LOG}->info("====> Inserting new document ... insert into versions");
        $version = $this->db_insert_version($docid, $type, $lang);

        $this->{LOG}->info("====> Inserting new document ... insert info vfields");
        $this->db_insert_vfields($docid, $version, $fields, \@fields);

        $this->{LOG}->info("====> Inserting new document ... COMMIT");
        $this->db_commit;
    };

    if ($@) {			# handle error
        $this->{DB_Error} = $@;
        $this->db_rollback;
        $this->{LOG}->error("====> Inserting new document ... failed ($@)");
        ($$error) = ($@ =~ /^(.*)\n/) if(defined($error));
        return wantarray ? () : undef;
    }

    undef $this->{DB_Error};

    # Insert the new document into the URI cache
    $this->{LOG}->info("====> Inserting new document ... Adding to URI cache");
    my $doc = $this->get_doc_by_id($docid);
    $this->add_to_uricache($doc);

    $this->{LOG}->info("====> Inserting new document ... done");
    return wantarray ? ($docid, $version) : [$docid, $version];
}


sub search {
    my ($this, $fields, $where, %options) = @_;

    $this->tracer($fields, $where, %options) if ($this->{DEBUG});

    my @table = ( 'versions' );
    my @join;
    my @fields = ( 'versions.*' );
    my @where;
    my %map;
    my $straight_fields = '';
    my $having = '';

    my $i = 0;
    my $xrefs = 0;

    # Default override_repeatable to an empty hash:
    $options{override_repeatable} ||= {};

    # Options:
    my $limit;
    my @limit_fields;
    if (defined $options{nothidden} and $options{nothidden}) {
        push(@$fields, 'seq');
        $where.=' AND seq >= 0';
    }
    if (defined $options{notexpired} and $options{notexpired}) {
        push (@$fields, 'expires');
        $where.=' AND expires > NOW()';
    }
    if (defined $options{public} and $options{public}) {
        $where.=' AND public = 1'; # Formerly "public > 0", but = is more effective when using indexes.
    } else {
        # Lets try this - if public is not set we join an extra versions table on
        # versions.docid = vmax_versions.docid. Since we already group by (docid,versions.lang),
        # we can use the extra versions table to get a row with the versionnumber of the latest
        # version using MAX(vmax_versions.version) and add a HAVING statement to the GROUP BY
        # that gives us either the public or the latest version. This way we get distinct
        # docid,version,lang rows which is what select_best_language_match_multiple expects.
        #
        # Hrm. We still get both the public and the latest version in the result, so we add an
        # extra versions table with a left join to tell us whether there is a public version
        # for the current docid at all. We can then use this information in the HAVING clause
        # to search for:
        # "Versions being either the public version (public = 1) or lastest version when there
        # is no public version (version = vmax_version AND publicflag IS NULL)".
        #
        push(@table, "versions as vmax_versions");
        push(@join, "versions.docid = vmax_versions.docid");

        # Gah. Wish there was a prettier way to do this. We want to join versions directly
        # with the pubflag versions to use the indexes to the fullest, so the left join
        # has to come right after versions. We do this by adding the clause to the first
        # element in the @table array:

        $table[0] .= " LEFT JOIN versions as pubflag_versions ON (versions.docid = pubflag_versions.docid and pubflag_versions.public = 1)";

        push(@fields, "MAX(vmax_versions.version) as obvius_vmax, pubflag_versions.public as pubflag");
        $having .= "((pubflag IS NULL AND versions.version=obvius_vmax) OR public=1)";
    }

    # Sorting:
    my ($sort_fields, $order)=$this->calc_order_for_query($options{sortvdoc})
        if defined $options{sortvdoc};

    map { push @$fields, $_ } (keys %$sort_fields);

    if($options{'needs_document_fields'} and ref($options{'needs_document_fields'}) eq 'ARRAY') {
        if($options{'straight_documents_join'}) {
            $straight_fields .= 'documents as obvius_documents STRAIGHT_JOIN ';
        } else {
            push(@table, "documents as obvius_documents");
        }
        push(@join, "(obvius_documents.id = versions.docid)");
        for(@{$options{'needs_document_fields'}}) {
            push(@fields, "obvius_documents.$_ as $_");
            $map{$_} = "obvius_documents.$_";
        }
    }

    # Check if we are limited to a siteroot:
    if($this->{ROOTID} and not $options{break_siteroot}) {
        push(@table, 'uri_cache');
        push(@join, "(versions.docid = uri_cache.docid)");
        $where .= " AND uri_cache.path_part1_id = $this->{ROOTID}";

        # Don't know if we can use this?
        for(@{$options{'needs_uricache_fields'}}) {
            push(@fields, "uri_cache.$_ as $_");
            $map{$_} = "uri_cache.$_";
        }
    }

    my %seen;
    for (@$fields) {
        my $fspec = $this->get_fieldspec($_);
        next if (defined $seen{$_} and (!$fspec->Repeatable or $options{override_repeatable}->{$_})); # Duplicate skippage
        $seen{$_}++;

        # Would be cleaner to have a separate list for sorting-fields:
        unless ($fspec->Searchable or $fspec->Sortable) {
            $this->log->warn("Can't search on field $_");
            next;
        }
        my $field = $fspec->FieldType->param('value_field');

        push(@table,   "vfields AS vf$i");
        push(@join,  "(versions.docid=vf$i.docid AND versions.version=vf$i.version)");
        push(@where,   "vf$i.name='$_'");
        if($fspec->FieldType->param('validate') eq 'xref' and $fspec->FieldType->param('search') eq 'matchColumn') {
            my ($xref_table, $xref_column) = split(/\./, $fspec->FieldType->param('validate_args'));
            my $search_arg = $fspec->FieldType->param('search_args');

            # Add the table we want to join
            push(@table, "$xref_table as xref$xrefs");

            #make sure we get the right stuff
            push(@join, "(xref$xrefs.$xref_column = vf$i.${field}_value)");

            #set the name of the field
            push (@fields, "xref$xrefs.$search_arg as $_$xrefs");

            $where =~ s/$_([^\d])/$_$xrefs$1/;

            # map all occurrences of $_ to xrefX.xref_column
            $map{$_ . $xrefs} = "xref$xrefs.$search_arg";

            $xrefs++;
        } else {
            push(@fields,  "vf$i.${field}_value as $_");
            if ($fspec->Repeatable and not $options{override_repeatable}->{$_}) {
                $where =~ s/$_([^\d])/$_$i$1/;
                $map{$_ . $i} = "vf$i.${field}_value";
            } else {
                $map{$_} = "vf$i.${field}_value";
            }
        }
        $i++;
    }
    $map{$_} = "versions.$_" for (qw(docid version public lang type));

    my $regex = '(' . join('|', map { quotemeta($_) } sort { length($b)<=>length($a) } keys %map) . ')';
    $where =~ s/$regex/$map{$1}/gie;

    my $set = DBIx::Recordset->SetupObject({'!DataSource'   => $this->{DB},
                                            '!Table'	    => $straight_fields . join(', ', @table),
                                            '!TabRelation'  => join(' AND ', @join),
                                            '!Fields'	    => join(', ', @fields),
#                                           '!Debug'		=> 2,
                                        });

    $having = ($having ? " HAVING $having" : '');

    my $query = {
                    '$where'	=> join(' AND ', @where, "($where)"),
                    '$group'	=> "versions.docid, versions.version, versions.lang $having",
                };

    $query->{'$order'}=join(', ', @$order) if (defined $order and @$order);
    $query->{'$order'}=~ s/$regex/$map{$1}/gie if ($query->{'$order'});

    $options{order} =~ s/$regex/$map{$1}/gie if ($options{order});
    for (keys %options) {
        $query->{"\$$_"} = $options{$_};
    }

    $this->{LOG}->notice(" Search query: " . Dumper($query)) if ($options{'obvius_dump'});
    $set->Search($query);

    my @subdocs;
    while (my $rec = $set->Next) {
        if ($options{public}) {
            # If we've got a parent (from the search), check from the parent up:
            my $recdoc=$this->get_doc_by_id(($rec->{parent} ? $rec->{parent} : $rec->{docid}));

            # If there is no parent, we pass the hint that the document being checked _is_
            # public itself (options{public} ensures that):
            next unless ($this->is_public_document($recdoc, doc_is_public=>!($rec->{parent})));
        }
        push(@subdocs, new Obvius::Version($rec));
    }
    $set->Disconnect;

    return $this->select_best_language_match_multiple(@subdocs ? \@subdocs : undef);
}


1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Obvius::MultiSite - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Obvius::MultiSite;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Obvius::MultiSite, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head2 EXPORT

None by default.


=head1 AUTHOR

A. U. Thor, E<lt>a.u.thor@a.galaxy.far.far.awayE<gt>

=head1 SEE ALSO

L<perl>.

=cut
