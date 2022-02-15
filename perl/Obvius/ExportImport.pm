package Obvius::ExportImport;

=head1 Obvius::ExportImport

Module for facilitating import and export of documents from Obvius
databases.

=head2 Methods

=over 4
=cut

use strict;
use warnings;

use Carp;
use IO::File;
use JSON::SL;
use JSON;
use Data::Dumper;
use File::Copy;
use File::Copy::Recursive;
use File::Path;
use File::Temp qw(tempdir);
use Env;
use Archive::Zip;
use Archive::Zip qw( :ERROR_CODES );
use DateTime;
use SQL::Abstract;
use POSIX qw(strftime);

use Obvius::Config;
use Obvius::Data;
use Obvius;
use WebObvius::Cache::Cache;
use URI;


my $json = JSON->new->allow_nonref->indent(2)->space_after(1);

sub new {
    my ($class, $obvius_or_config) = @_;

    if (!defined $obvius_or_config) {
        die "You must specify an Obvius object, an Obvius::Config object or an Obvius configname";
    }

    if (!ref($obvius_or_config)) {
        $obvius_or_config = Obvius::Config->new($obvius_or_config);
        if (!$obvius_or_config) {
            die "Could not turn '%s' into an Obvius::Config object";
        }
    }

    my $self = {};

    my $ref = ref($obvius_or_config);

    if ($ref eq 'Obvius::Config') {
        $self->{obvius_config} = $obvius_or_config;
    } elsif (ref($obvius_or_config) eq 'Obvius') {
        $self->{obvius} = $obvius_or_config;
        $self->{obvius_config} = $self->{obvius}->config;
    } else {
        die sprintf("Could not turn '%s' into an Obvius object", $obvius_or_config);
    }

    $self->{'export_cache'} = {
        'users'     => {},
        'groups'    => {}
    };

    $self->{'import_cache'} = {
        'docids'   => {}, # Docids we have encountered and have a mapping for. This includes non-imported parents located by path
        'versions' => {}  # Versions on docids that we have imported. Does not include anything we have not imported. This means that preexisting documents will not show up here.
    };

    $self->{'export_types'} = [
        'documents',
        'docparams',
        'versions',
        'vfields',
        'proxies'
    ];

    $self->{'export_functions'} = {
        'documents' => 'export_document',
        'docparams' => 'export_docparam',
        'versions'  => 'export_version',
        'vfields'   => 'export_vfield',
        'proxies'   => 'export_proxy',
    };
    $self->{'import_functions'} = {
        'documents' => 'import_document',
        'docparams' => 'import_docparam',
        'versions'  => 'import_version',
        'vfields'   => 'import_vfield',
        'proxies'   => 'import_proxy',
    };
    $self->{'list_functions'} = {
        'documents' => 'list_documents',
        'docparams' => 'list_docparams',
        'versions'  => 'list_versions',
        'vfields'   => 'list_vfields',
        'proxies'   => 'list_proxies'
    };
    $self->{'import_keys'} = ['documents', 'docparams', 'versions', 'vfields', 'proxies'];

    $self->{'fallback_owner'} = 'admin';
    $self->{'fallback_group'} = 'Admin';
    $self->{'user_map'} = {};
    $self->{'group_map'} = {};

    # TODO split into import_options and export_options
    # TODO set these on initialization instead of via $exporter->set_options
    $self->{'options'} = {
        'imported_public_version_is_new_public' => 1,
        'zip' => 1,
        'depth' => -1,
        'version_depth' => -1,
        'only_public_or_latest_version' => 0,
        'include_references' => 0,
        'zipfilename' => undef,
        'destination' => undef,
        'create_dest_if_not_exists' => 0,
        'clear_cache' => 1,
    };

    return bless($self, $class);
}

sub obvius_config {
    my ($self) = @_;
    return $self->{obvius_config};
}
sub obvius {
    my ($self) = @_;
    my $obvius = $self->{obvius};
    if (!defined $obvius) {

        my $log = Obvius::Log->new('error');
        $obvius = Obvius->new($self->obvius_config, undef, undef, undef, undef, undef, 'log'=>$log);
        # Ensure we have admin privileges or docparam import will fail
        $obvius->{USER} = 'admin';
        $self->{obvius} = $obvius;
    }
    return $obvius;
}


# Methods that should be implemented in inheriting modules
sub folder_doctypename          { die "Not implemented " }
sub docidify                    { die "Not implemented " }

sub load_mapping {
    my ($self, $map) = @_;
    if (!ref($map)) {
        if (-e $map) {
            my $fp = IO::File->new("$map", "r");
            my @buf;
            while (my $line = <$fp>) {
                push(@buf, $line);
            }
            $map = decode_json(join("", @buf));
            $fp->close();
        } else {
            $map = decode_json($map);
        }
    }
    return $map;
}

sub set_user_map {
    my ($self, $map) = @_;
    $self->{'user_map'} = $self->load_mapping($map);
}

sub set_group_map {
    my ($self, $map) = @_;
    $self->{'group_map'} = $self->load_mapping($map);
}

sub set_options {
    my ($self, $options) = @_;
    # Merge options into defaults, override where applicable
    $self->{options} = {%{$self->{options}}, %{$options}};
}

sub clear_document_cache {
    my ($self, @docids) = @_;
    foreach my $docid (@docids) {
        $self->obvius->register_modified(docid => $docid);
    }
    $self->obvius->register_modified(admin_leftmenu => \@docids);
}

sub export_to_folder {
    my ($self, $output_folder, $head_docid) = @_;

    if ($head_docid =~ /^\//) {
        $head_docid =~ s/\/?$/\//;
        my @doc = $self->obvius->get_doc_by_path($head_docid);
        if (!scalar(@doc)) {
            die("Didn't find head document at $head_docid");
        }
        my $doc = @doc[scalar(@doc)-1];
        if ($doc->param('path') ne $head_docid) {
            die("Didn't find head document at $head_docid (found ".$doc->param('path').")");
        }
        $head_docid = $doc->param('id');
    }
    my $head_doc = $self->obvius->get_doc_by_id($head_docid);

    $output_folder =~ s!/$!!; # Remove trailing slash
    mkdir($output_folder);

    my $tmp_folder = tempdir(CLEANUP => 1); # Create throwaway folder

    $self->{export_cache}->{basepath} = $self->obvius->get_doc_uri($head_doc);

    my ($documents, $versions);
    for my $type (@{$self->{export_types}}) {
        my $list_function = $self->{list_functions}->{$type};
        my $items;
        ($items, $documents, $versions) = $self->$list_function($head_docid, $documents, $versions);
        my $file = IO::File->new("${tmp_folder}/${type}.json", "w");
        if (!defined($file)) {
            die "Cannot create file $tmp_folder/${type}.json\n";
        }
        $self->export_items($items, $type, $file, 0);
        $file->close();
    }

    if ($self->{options}->{'zip'}) {
        my $zip = Archive::Zip->new();
        # TODO Default to something like "$doc->Name" . '_YYYY_MM_DD.zip'
        my $zipfilename = $self->{options}->{zipfilename} || 'exporting.zip';
        my $zipfile = "$output_folder/$zipfilename";
        $zip->addTree($tmp_folder, '', sub { $_ ne $zipfile });
        $zip->writeToFileNamed($zipfile);
        print "Wrote to file $zipfile\n";
    } else {
        File::Copy::Recursive::dircopy($tmp_folder, $output_folder);
        print "Wrote to folder $output_folder\n";
    }
}

sub import_from_zip_file {
    my ($self, $zipfile) = @_;

    my $zip = Archive::Zip->new();
    if ($zip->read($zipfile) != AZ_OK) {
        die "Could not read $zipfile";
    }

    my $tmp_folder = tempdir(CLEANUP => 1); # Create throwaway folder
    $zip->extractTree('', $tmp_folder);
    $self->import_from_folder($tmp_folder);
}

sub import_from_folder {
    my ($self, $folder) = @_;

    $self->obvius->db_begin;

    # Disable Obvius::DB::db_commit method, since some of the obvius methods will call it.
    # By making it a noop we ensure that only the commit at the end of this method is
    # executed.
    my $original_commit_method = \&Obvius::DB::db_commit;
    no warnings 'redefine';
    local *Obvius::DB::db_commit = sub {};
    local *Obvius::DB::db_begin = sub {};
    use warnings;

    eval {
        for my $type_key (@{$self->{'import_keys'}}) {
            my $filename = "$folder/$type_key.json";
            if (-e $filename) {
                my $file = IO::File->new("$folder/$type_key.json", "r");
                my $sl = JSON::SL->new();
                $sl->set_jsonpointer([ "/^" ]);
                my $table;
                while (my $buf = <$file>) {
                    $sl->feed($buf);
                    while (my $obj = $sl->fetch()) {
                        if ($obj->{'Path'} eq '/0') {
                            $table = $obj->{'Value'}->{'table'};
                        }
                        else {
                            if ($table eq $type_key) {
                                my $import_function = $self->{'import_functions'}{$table};
                                for my $item_json (@{$obj->{'Value'}}) {
                                    $self->$import_function($item_json);
                                }
                            }
                            else {
                                die(qq|Invalid table in "$filename#$obj->{'Path'}": expected "$type_key", got "$table"|);
                            }
                        }
                    }
                }
                $file->close();
            } else {
                print "Could not find $folder/$type_key.json\n";
            }
        }

        $self->import_files("$folder/files");
    };
    if ($@) {
        $self->obvius->db_rollback;
        die($@);
    }
    $original_commit_method->($self->obvius);

    if ($self->{options}->{clear_cache}) {
        $self->flush_cache;
    }
}

sub create_parent_folders {
    my ($self, $path, $owner_id, $group_id) = @_;

    my $doc = $self->obvius->lookup_document($path);
    if ($doc) {
        return $doc->Id;
    } else {
        my @p = grep { $_ } split('/', $path);
        my $name = pop(@p);
        my $parent_path = @p ? '/'. join('/', @p) . '/' : '/';
        my $parent_docid = $self->create_parent_folders($parent_path, $owner_id, $group_id);

        my $folder_type = $self->obvius->get_doctype_by_name($self->folder_doctypename);

        # obvius->create_new_document is sadly a no-go here, because we don't really have a user
        $self->obvius->db_begin;
        my $docid = $self->obvius->db_insert_document($name, $parent_docid, $folder_type->Id, $owner_id, $group_id);

        my $version = $self->obvius->db_insert_version($docid, $folder_type->Id, 'da');
        # Make sure parent folders are public
        $doc = $self->obvius->get_doc_by_id($docid);
        my $vdoc = $self->obvius->get_version($doc, $version);
        $self->obvius->db_update_version_mark_public($vdoc);

        my $fields = Obvius::Data->new();
        for my $key (keys %{$folder_type->{FIELDS}}) {
            my $default_value = $folder_type->{FIELDS}->{$key}->{DEFAULT_VALUE};
            if (defined($default_value)) {
                $fields->param($key => $default_value);
            }
        }
        $fields->param('title', $name);
        $fields->param('docdate', strftime('%Y-%m-%d 00:00:00', localtime));
        $self->obvius->db_insert_vfields($docid, $version, $fields);

        $self->obvius->db_commit;
        if ($self->{options}->{clear_cache}) {
            $self->clear_document_cache($docid, $parent_docid);
        }
        return $docid;
    }
}

sub path_length {
    my ($self, $document) = @_;
    my $path = $self->obvius->get_doc_uri($document);
    $path =~ s/[^\/]//g;
    return length($path);
}

sub list_documents {
    my ($self, $head_docid, $documents, $versions) = @_;
    # A future release may want to introduce filtering
    my @docs;
    my $depth = $self->{options}->{depth};
    my $include_references = $self->{options}->{include_references};

    my $head_doc = $self->obvius->get_doc_by_id($head_docid);
    if (defined($head_doc)) {
        push(@docs, @{$self->list_doc_tree($head_doc, $depth)});
    }

    if ($include_references == 1) {
        my %document_map = map {$_->param('id') => $_} @docs;
        for my $docid (keys(%document_map)) {
            my $references = $self->find_referred_docids($docid, 1);
            for my $reference (keys(%$references)) {
                if (!exists($document_map{$reference}) && $reference > 1) {
                    my $document = $self->obvius->get_doc_by_id($reference);
                    if (defined($document)) {
                        $document_map{$reference} = $document;
                    }
                }
            }
        }
        @docs = values(%document_map);
    }

    @docs = sort { $self->path_length($a) <=> $self->path_length($b) } @docs;
    return \@docs, \@docs, undef;
}

# $remaining_depth is either -1 (infinite), 0 (don't recurse any further) or positive
sub list_doc_tree {
    my ($self, $rootdoc, $remaining_depth) = @_;
    my @docs;
    push(@docs, $rootdoc);
    my $subdocs = $self->obvius->get_docs_by_parent($rootdoc->param('id'));
    if (defined($subdocs) && $remaining_depth != 0) {
        $remaining_depth -= 1;
        for my $subdoc (@$subdocs) {
            push(@docs, @{$self->list_doc_tree($subdoc, $remaining_depth)});
        }
    }
    return \@docs;
}

sub list_proxies {
    my ($self, $head_docid, $documents, $versions) = @_;
    my @docids = map { ref($_) ? $_->Id : $_ } @{$documents};
    my $rows = $self->obvius->execute_select(
        "select id, docid, dependent_on, version
        from internal_proxy_documents
        where docid in (" . join(",", map { "?" } @docids) . ")",
        @docids
    );
    return $rows, $documents, $versions;
}

sub list_docparams {
    my ($self, $head_docid, $documents, $versions) = @_;
    my @docparams;
    for my $document (@$documents) {
        push(@docparams, values(%{$self->obvius->get_docparams($document)}));
    }
    return \@docparams, $documents, $versions;
}

sub list_versions {
    my ($self, $head_docid, $documents, $versions) = @_;
    # A future release may want to introduce filtering
    my $version_depth = $self->{options}->{version_depth};
    my $only_public_or_latest_version = $self->{options}->{only_public_or_latest_version};
    my @extra_args;
    if ($version_depth != -1) {
        push @extra_args, '$max';
        push @extra_args, $version_depth;
    }
    my @versions;
    for my $document (@$documents) {
        if ($only_public_or_latest_version) {
            my $version = $self->obvius->get_public_version($document) || $self->obvius->get_latest_version($document);
            push @versions, $version unless not defined($version);
        } else {
            my $versions = $self->obvius->get_versions($document, @extra_args);
            if (defined($versions)) {
                push(@versions, @{$versions});
            }
        }
    }
    return \@versions, $documents, \@versions;
}

sub list_vfields {
    my ($self, $head_docid, $documents, $versions) = @_;
    # A future release may want to introduce filtering
    my @vfields;
    for my $version (@$versions) {
        push(@vfields, map { { 'vfield' => $_, 'version' => $version } } $self->obvius->get_version_fields($version, 1000));
    }
    return \@vfields, $documents, $versions;
}

sub find_referred_docids {
    my ($self, $docid, $level, $references) = @_;

    if (ref($docid)) {
        $docid = $docid->Id;
    }
    if (!defined($references)) {
        $references = {};
    }

    my $doc = $self->obvius->get_doc_by_id($docid);
    if (defined($doc)) {
        my $parentid = $doc->param('parent');
        if ($parentid > 0 && !exists($references->{$parentid})) {
            $references->{$parentid} = 1;
            $self->find_referred_docids($parentid, $level, $references);
        }
    }
    if ($level <= 0) {
        return $references;
    }
    my $sth = $self->obvius->dbh->prepare("SELECT distinct text_value FROM vfields WHERE docid = ? and text_value like '%.docid%'");
    $sth->execute($docid);
    while (my $row = $sth->fetchrow_hashref()) {
        my $value = $row->{'text_value'};
        for my $ref_docid ($value =~ /(\d+).docid/g) {
            if (!exists($references->{$ref_docid})) {
                $references->{$ref_docid} = 1;
                # if ($ref_docid != 1) { # Don't find references on front page
                    $self->find_referred_docids($ref_docid, $level-1, $references);
                # }
            }
        }
    }

    my @p = ($docid);
    my $proxies = $self->list_proxies(\@p);
    for my $proxy (@{$proxies}) {
        my $ref_docid = $proxy->{'dependent_on'};
        if (!exists($references->{$ref_docid})) {
            $references->{$ref_docid} = 1;
            $self->find_referred_docids($ref_docid, $level-1, $references);
        }
    }

    return $references;
}

sub get_user {
    my ($self, $login, $item_desc) = @_;
    my $fallback_owner = $self->{'fallback_owner'};
    if (!$login) {
        #print "No login provided. Using default user '$fallback_owner'\n";
        return $self->obvius->get_user($self->{'fallback_owner'})->{'id'};
    }
    my $mapped_login = $self->{'user_map'}->{$login};
    if (defined($mapped_login)) {
        #print("Mapping user $login to $mapped_login\n");
        $login = $mapped_login;
    }
    my $dest_owner = $self->obvius->get_user($login);
    if (!defined($dest_owner)) {
        #print("Did not find user '$login' to give ownership of '$item_desc' to. Falling pack to default user '$fallback_owner'\n");
        $dest_owner = $self->obvius->get_user($self->{'fallback_owner'});
    }
    return $dest_owner->{'id'};
}

sub get_group {
    my ($self, $group_name, $item_desc) = @_;

    my $mapped_group = $self->{'group_map'}->{$group_name};
    if (defined($mapped_group)) {
        #print("Mapping group $group_name to $mapped_group\n");
        $group_name = $mapped_group;
    }

    my $dest_group_id = $self->obvius->get_grpid($group_name);
    if (!defined($dest_group_id)) {
        #print("Did not find group '$group_name' to give ownership of '$item_desc' to. Falling pack to default group '$self->{'fallback_group'}'\n");
        return $self->obvius->get_grpid($self->{'fallback_group'});
    }
    return $dest_group_id;
}

sub export_items {
    my ($self, $items, $type, $file, $indent_size) = @_;
    my $export_function = $self->{export_functions}->{$type};
    if (!defined($indent_size)) {
        $indent_size = 0;
    }
    my $i = " " x $indent_size;

    print $file $i."[\r\n";
    print $file "$i  { \"table\": \"$type\" },\r\n";
    print $file "$i  [";

    if (defined($items)) {
        my $first = 1;
        for my $item (@$items) {
            if ($first == 1) {
                $first = 0;
                print $file "\r\n";
            } else {
                print $file ",\r\n";
            }
            $self->$export_function($item, $file, $indent_size+4);
        }
    }

    print $file "\r\n$i  ]\r\n";
    print $file "$i]";
}

sub export_document {
    my ($self, $document, $file, $indent_size) = @_;
    if (!defined($indent_size)) {
        $indent_size = 0;
    }
    my $i = " " x $indent_size;

    my %data = map { $_ => $document->{$_} } grep { $_ ne 'VERSIONS' && $_ ne 'path' } keys(%$document);

    my $owner_id = $data{'OWNER'};
    my $owner_login = $self->{'export_cache'}->{'users'}->{$owner_id};
    if (!defined($owner_login)) {
        my $user = $self->obvius->get_user($owner_id);
        if (!defined($user)) {
            $owner_login = $self->{'fallback_owner'};
            #print("Warning: Document $data{'ID'} has unknown userid $owner_id. Falling back to $owner_login user\n");
        } else {
            $owner_login = $user->{'login'};
            $self->{'export_cache'}->{'users'}->{$owner_id} = $owner_login;
        }
        $self->{'export_cache'}->{'users'}->{$owner_id} = $owner_login;
    }
    $data{'OWNER_LOGIN'} = $owner_login;

    my $group_id = $data{'GRP'};
    my $group_name = $self->{'export_cache'}->{'groups'}->{$group_id};
    if (!defined($group_name)) {
        my $group = $self->obvius->get_group($group_id);
        if ($group_id == 0 || !$group) {
            $group_name = $self->{'fallback_group'};
        } else {
            $group_name = $group->{'name'};
        }
        $self->{'export_cache'}->{'groups'}->{$group_id} = $group_name;
    }
    $data{'GRP_NAME'} = $group_name;

    $data{'PATH'} = $self->obvius->get_doc_uri($document);

    my @relative_path;
    my @basepath = split('/', $self->{export_cache}->{basepath});
    my @subjectpath = split('/', $data{'PATH'});
    my $j=0;
    for my $part (@subjectpath) {
        my $basepart = $basepath[$j];
        if (!defined($basepart) || $basepart ne $part) {
            if (scalar(@basepath) > $j) {
                push(@relative_path, ".." x (scalar(@basepath) - $j));
            }
            push(@relative_path, splice(@subjectpath, $j))
        }
        $j++;
    }
    push(@relative_path, '');

    $data{'RELATIVE_PATH'} = join('/', @relative_path);

    $data{'TYPE_NAME'} = $self->obvius->get_doctype_by_id($data{'TYPE'})->{"NAME"};

    my $output = $json->encode(\%data);
    $output =~ s/^\s+|\s+$//;
    $output =~ s/\n/\n$i/g;
    $output = $i.$output;
    print $file $output;
}

sub import_document {
    my ($self, $obj) = @_;

    my @path = split('/', $self->{options}->{destination});
    for my $part (split('/', $obj->{RELATIVE_PATH})) {
        if ($part eq '..') {
            pop(@path);
        } else {
            push(@path, $part);
        }
    }
    my $path = join("/", @path);
    $path =~ s{/?$}{/};

    print "Importing '$obj->{RELATIVE_PATH}' to '$path'\n";

    my @d = $self->obvius->get_doc_by_path($path);
    if (@d) {
        print "    A document already exists on the destination at $path. Not overwriting\n";
        my $id = $d[-1]->Id;
        $self->{'import_cache'}->{'docids'}->{$obj->{'ID'}} = "$id";
        return;
    }


    my $dest_owner_id = $self->get_user($obj->{'OWNER_LOGIN'}, $obj->{'PATH'});
    my $dest_group_id = $self->get_group($obj->{'GRP_NAME'}, $obj->{'PATH'});

    my $src_parent = $obj->{'PARENT'};
    my $dest_parent = $self->{'import_cache'}->{'docids'}->{$src_parent};
    if (defined($dest_parent)) {
        print "    Found cached parent at docid=$dest_parent.\n";
    } else {
        #print "Did not find already imported parent document for $src_path (with source parent docid=$src_parent)\n";
        my $parent_path = $path;
        $parent_path =~ s{[^/]+/$}{};
        my $dest_parent_doc = $self->obvius->lookup_document($parent_path);
        if ($dest_parent_doc) {
            $dest_parent = $dest_parent_doc->param('id');
            print "    Found existing parent at $parent_path (" . $dest_parent_doc->param('path') . ") (docid=$dest_parent).\n";
        } else {
            if ($self->{options}->{create_dest_if_not_exists}) {
                print "    Did not find parent at $parent_path. Creating.\n";
                $dest_parent = $self->create_parent_folders($parent_path, $dest_owner_id, $dest_group_id);
            } else {
                die("    Did not find parent at path $parent_path");
            }
        }
    }
    my $name = $obj->{'NAME'};
    if ($obj->{RELATIVE_PATH} eq '') {
        $name = $self->{options}->{destination};
        $name =~ s{/$}{}g;  # Remove trailing slash
        $name =~ s{[^/]*/}{}g;  # Remove everything and including the last slash
    }
    print "    Appending child '$name'\n";

    my $src_type_name = $obj->{'TYPE_NAME'};
    my $dest_type = $self->obvius->get_doctype_by_name($src_type_name);
    if (!defined($dest_type)) {
        die("    Did not find document type $src_type_name needed for document $obj->{'PATH'}");
    }
    my $dest_type_id = $dest_type->param('id');

    my $docid = $self->obvius->db_insert_document($name, $dest_parent, $dest_type_id, $dest_owner_id, $dest_group_id);
    $self->{'import_cache'}->{'docids'}->{$obj->{'ID'}} = $docid;
    $self->{'import_cache'}->{'versions'}->{$docid} = {};
    if ($self->{options}->{clear_cache}) {
        $self->clear_document_cache($docid, $dest_parent);
    }
}

sub export_docparam {
    my ($self, $docparam, $file, $indent_size) = @_;
    if (!defined($indent_size)) {
        $indent_size = 0;
    }
    my $i = " " x $indent_size;

    my %data = %{$docparam};

    my $output = $json->encode(\%data);
    $output =~ s/^\s+|\s+$//;
    $output =~ s/\n/\n$i/g;
    $output = $i.$output;

    print $file $output;
}

sub import_docparam {
    my ($self, $obj) = @_;
    my $src_docid = $obj->{'DOCID'};
    my $dest_docid = $self->{'import_cache'}->{'docids'}->{$src_docid};
    if (!defined($dest_docid)) {
        die("Needed to find already imported document with source docid=$src_docid. None found.\n");
    }
    my $document = $self->obvius->get_doc_by_id($dest_docid);

    my $error;
    $self->obvius->set_docparam($document, $obj->{'NAME'}, $obj->{'VALUE'}, \$error);
    if ($error) {
        print "Error importing docparam: $error\n";
        # Have to split print & die into separate expressions to ensure error gets printed
        die "Aborting import";
    }
}

sub export_version {
    my ($self, $version, $file, $indent_size) = @_;

    if (!defined($indent_size)) {
        $indent_size = 0;
    }
    my $i = " " x $indent_size;

    my %data = map { $_ => $version->{$_} } grep { $_ ne 'FIELDS' && $_ ne 'ID' } keys(%$version);

    my $user_id = $data{'USER'};
    if (defined($user_id) && $user_id > 0) {
        my $user_login = $self->{'export_cache'}->{'users'}->{$user_id};
        if (!defined($user_login)) {
            my $user = $self->obvius->get_user($user_id);
            if (!defined($user)) {
                $user_login = $self->{'fallback_owner'};
                #print("Warning: Document $data{'DOCID'} version $data{'VERSION'} has unknown userid $user_id. Falling back to user '$user_login'\n");
            }
            else {
                $user_login = $user->{'login'};
                $self->{'export_cache'}->{'users'}->{$user_id} = $user_login;
            }
        }
        $data{'USER_LOGIN'} = $user_login;
    }
    $data{'TYPE_NAME'} = $self->obvius->get_doctype_by_id($data{'TYPE'})->{"NAME"};

    my $output = $json->encode(\%data);
    $output =~ s/^\s+|\s+$//;
    $output =~ s/\n/\n$i/g;
    $output = $i.$output;

    print $file $output;
}

sub import_version {
    my ($self, $obj) = @_;

    my $src_docid = $obj->{'DOCID'};
    my $dest_docid = $self->{'import_cache'}->{'docids'}->{$src_docid};
    if (!defined($dest_docid)) {
        die("Version import needed to find already imported document with source docid=$src_docid. None found.\n");
    }

    if (!exists($self->{'import_cache'}->{'versions'}->{$dest_docid})) {
        #print("Document $dest_docid was not imported, but preexisting. Not populating with versions\n");
        return;
    }

    my $document = $self->obvius->get_doc_by_id($dest_docid);

    my $src_version = $obj->{'VERSION'};
    my $dest_version = $src_version;

    if ($self->obvius->get_version($document, $src_version)) {
        my $path = $self->obvius->get_doc_uri($document);
        #print("Version $src_version already exists in destination document $path (docid=$dest_docid).\n");
        return;
    }

    my $dest_owner_id = $self->get_user($obj->{'USER_LOGIN'}, "docid $dest_docid version $dest_version");

    my $src_type_name = $obj->{'TYPE_NAME'};
    my $dest_type = $self->obvius->get_doctype_by_name($src_type_name);
    if (!defined($dest_type)) {
        die("Did not find document type $src_type_name needed for document $dest_docid version $dest_version");
    }
    my $dest_type_id = $dest_type->param("id");

    my $previous_public = $self->obvius->get_public_version($document);
    my $dest_public = $self->{'options'}->{'imported_public_version_is_new_public'} || !defined($previous_public) ? $obj->{'PUBLIC'} : 0;

    my $item = {
        public	 => $dest_public,
        docid	 => $dest_docid,
        version	 => $dest_version,
        type	 => $dest_type_id,
        lang	 => $obj->{'LANG'},
        user     => $dest_owner_id,
    };
    # We would use db_insert_version, except that method always writes localtime as timestamp
    my $set = DBIx::Recordset->SetupObject({
        '!DataSource' => $self->obvius->{DB},
        '!Table'      => 'versions',
    });
    if ($dest_public == 1) {
        $set->Update({public => 0}, { 'docid' => $dest_docid });
    }
    $set->Insert($item);
    $set->Disconnect();

    if (!exists($self->{'import_cache'}->{'versions'}->{$dest_docid})) {
        $self->{'import_cache'}->{'versions'}->{$dest_docid} = {};
    }
    $self->{'import_cache'}->{'versions'}->{$dest_docid}->{$dest_version} = 1;
}


sub export_vfield {
    my ($self, $item, $file, $indent_size) = @_;

    my $vfields = $item->{'vfield'};
    my $version = $item->{'version'};

    if (!defined($indent_size)) {
        $indent_size = 0;
    }
    my $i = " " x $indent_size;

    my $src_docid = $version->DocId;

    my %v = %$vfields;
    for my $key (keys(%v)) {
        my $value = $v{$key};
        if (ref($value)) {
            my @replaced = map { $self->replace_vfield_docid_reference($src_docid, $version->param('version'), $_) } @$value;
            $v{$key} = \@replaced;
        } else {
            $v{$key} = $self->replace_vfield_docid_reference($src_docid, $version->param('version'), $value);
        }
    }

    my $data = {
        'version' => $version->Version,
        'docid'   => $src_docid,
        'vfields'  => \%v
    };

    my $output = $json->encode(\%$data);
    $output =~ s/^\s+|\s+$//;
    $output =~ s/\n/\n$i/g;
    $output = $i.$output;
    print $file $output;
}

my %path_cache;
sub replace_vfield_docid_reference {
    my ($self, $src_docid, $version, $value) = @_;

    my %path_map;
    for my $docid ($value =~ /\/(\d+).docid/g) {
        my $path;
        if (exists($path_cache{$docid})) {
            $path = $path_cache{$docid};
        } else {
            my $paths = $self->obvius->execute_select("select path from docid_path where docid=?", $docid);
            if (@$paths) {
                $path = $paths->[0]{path};
                $path_cache{$docid} = $path;
            }
        }
        if (defined($path)) {
            $path_map{$docid} = $path;
        } else {
            $path_map{$docid} = '/error404/';
            #print "Warning: Document $src_docid, version $version references document $docid, but that was not found in the database. Replacing with reference to /error404/\n";
        }

    }
    if (keys(%path_map)) {
        for my $docid (keys(%path_map)) {
            my $path = $path_map{$docid};
            $value =~ s/\/$docid\.docid/$path/g;
        }
    }
    return $value;
}

sub import_vfield {
    my ($self, $obj) = @_;

    my $src_docid = $obj->{'docid'};
    my $dest_docid = $self->{'import_cache'}->{'docids'}->{$src_docid};
    if (!defined($dest_docid)) {
        die("Vfield import needed to find already imported document with source docid=$src_docid. None found");
    }

    if (!exists($self->{'import_cache'}->{'versions'}->{$dest_docid})) {
        #print("Document $dest_docid was not imported, but preexisting. Not populating with vfields\n");
        return;
    }

    my $src_version = $obj->{'version'};
    my $dest_version = $src_version;

    if (!exists($self->{'import_cache'}->{'versions'}->{$dest_docid}->{$dest_version})) {
        #print("Did not import version $dest_version of document $dest_docid; it may have already existed. Not populating with vfields.\n");
        return;
    }

    my $vdoc_fields = bless({}, "Obvius::Data");

    my $vfields = $obj->{'vfields'};
    foreach my $name (keys(%$vfields)) {
        my $value = $vfields->{$name};
        while ($value =~ /^(.*)\/(\d+)(\.docid.*)/) {
            my $src_ref_docid = $2;
            my $dest_ref_docid = $self->{'import_cache'}->{'docids'}->{$src_ref_docid};
            if (!defined($dest_ref_docid)) {
                die("Vfield import (ref) needed to find already imported document with source docid=$src_ref_docid. None found");
            }
            $value = "$1$dest_ref_docid$3";
        }

        $value =~ s{(/[/\w\-.]+/)}{$self->docidify($1)}ge;
        $vdoc_fields->param($name => $value);
    }

    $self->obvius->db_insert_vfields($dest_docid, $dest_version, $vdoc_fields);
}

sub export_files {
    my ($self, $dest_folder, $vfields_list) = @_;
    my @filefields = ('UPLOADFILE');
    my $source_folder = "/var/www/www.ku.dk/docs";
    for my $vfields_entry (@$vfields_list) {
        my $vfields = $vfields_entry->{'vfield'};
        for my $filefield (@filefields) {
            if (exists($vfields->{$filefield})) {
                my $referred_file = $vfields->{$filefield};
                $referred_file =~ s/^\s|\s$//;
                $referred_file =~ s/^\///;
                my $dest_subfolder = "$dest_folder/$referred_file";
                $dest_subfolder =~ s/[^\/]+$//;
                my $error;
                File::Path::make_path($dest_subfolder, {'error'=>$error});
                if (defined($error)) {
                    die("Failed to create subfolders $dest_subfolder for file $referred_file: \n" . join("\n", @$error));
                }
                File::Copy::copy("$source_folder/$referred_file", "$dest_folder/$referred_file");
            }
        }
    }
}

sub import_files {
    my ($self, $src_folder) = @_;
    my $dest_folder = "/var/www/www.ku.dk/docs";
    File::Copy::Recursive::dircopy($src_folder, $dest_folder);
}

sub export_proxy {
    my ($self, $item, $file, $indent_size) = @_;
    if (!defined($indent_size)) {
        $indent_size = 0;
    }
    my $i = " " x $indent_size;

    my $fields = $self->obvius->execute_select("select name from internal_proxy_fields where relation_id = ?", $item->{'id'});
    my @fields = map { $_->{'name'} } @{$fields};
    $item->{'fields'} = \@fields;

    my $output = $json->encode(\%$item);
    $output =~ s/^\s+|\s+$//;
    $output =~ s/\n/\n$i/g;
    $output = $i.$output;
    print $file $output;
}

sub import_proxy {
    my ($self, $obj) = @_;
    my $dest_docid = $self->{'import_cache'}->{'docids'}->{$obj->{'docid'}};
    my $dest_dependent_on = $self->{'import_cache'}->{'docids'}->{$obj->{'dependent_on'}};
    my $version = $obj->{'version'};
    my $fields = join(",", @{$obj->{'fields'}});

    if (!defined($dest_docid)) {
        die("Document $obj->{'docid'} was not imported - cannot establish proxy\n");
    }
    if (!defined($dest_dependent_on)) {
        die("Document $obj->{'dependent_on'} was not imported - cannot establish proxy\n");
    }
    my $row = $self->obvius->execute_select("select count(*) from internal_proxy_documents where docid = ? and dependent_on = ? and version = ?", $dest_docid, $dest_dependent_on, $version);
    if ($row->[0]->{'count(*)'} == 0) {
        $self->obvius->execute_command("call new_internal_proxy_entry(?,?,?,?)", $dest_docid, $obj->{'version'}, $dest_dependent_on, $fields);
        #print("Imported internal proxy $dest_docid -> $dest_dependent_on for version $version.\n");
    } else {
        #print("Did not import internal proxy $dest_docid -> $dest_dependent_on for version $version. It already exists.\n");
    }
}

sub read_file {
    my ($filename, $descriptor) = @_;
    if (!defined($descriptor)) {
        $descriptor = "input file";
    }
    if (!(-e $filename)) {
        die("Specified $descriptor $filename does not exist");
    }
    local $/;
    open(my $fp, $filename) or die("Cannot open $descriptor $filename");
    my $contents = <$fp>;
    close($fp);
    return $contents;
}


#################################
# Methods for web import/export #
#################################


=item remote_dumps_dir()

Returns the directory used for caching dumps fetched from remote servers.

Example:

    my $dir = $exportimpot->remote_dumps_dir;

=cut
sub remote_dumps_dir {
    my ($self) = @_;

    if(!$self->{remote_dumps_dir}) {
        my $base_path = $self->obvius->config->param('importexport_dir');
        $base_path =~ s{/$}{}x;

        $self->{remote_dumps_dir} = $base_path . '/remote';
    }

    return $self->{remote_dumps_dir};
}

=item remote_dumps_useragent($host, %options)

Sets up and returns a useragent that can be used for fetching remote
dumps from the specified host.

Arguments:

    $host - The host dumps are to be fetched from.

    %options:

        api_key - The API key used to grant access to the remote host.

If no API key is provided in the options, the Obvius config will be
checked for a an API key stored under the key
`remote_api_key_for_<hostname>` where `<hostname>` is the provided
hostname with . replaced with underscores. So for the hostname
`www.example.com` the config key would be
`remote_api_key_for_www_example_com`.

Example:

    my $ua = $exportimport->remote_dumps_useragent(
        'example.com',
        api_key => '<some-uuid>'
    )

=cut
sub remote_dumps_useragent {
    my ($self, $host, %options) = @_;

    if(!$self->{remote_dumps_useragent}->{$host}) {
        my $roothost = $self->obvius->config->param('roothost');

        my $config_key = 'remote_api_key_for_' . $host;
        $config_key =~ s{\.}{_}gx;

        my $api_key = $options{api_key} ||
                      $self->obvius->config->param($config_key);
        if(!$api_key) {
            croak "No remote API key specified for $host";
        }

        my $headers = HTTP::Headers->new();
        $headers->header('x-obvius-api-key' => $api_key);

        my $modulename = ref($self);

        $self->{remote_dumps_useragent}->{$host} = LWP::UserAgent->new(
            agent => "${modulename}::fetch_remote_dump/${roothost}/0.1",
            default_headers => $headers,
        );
    }

    return $self->{remote_dumps_useragent}->{$host};
}

=item fetch_remote_dump($host, $path, %options)

Fetches and stores a remote dump and returns the filename of the locally
stored file.

Arguments:

    $host
        The hostname of the server to fetch dumps from

    $path_and_filename
        The path and filename to fetch. Will usually end in `/exported.zip`

    %options:

        use_cache
            Use cached dump if one exists.

        force_remote_dump
            Force the remote end to recreate the dump even if an existing
            dump exists.

        api_key
            API key used for authentication with remote server. See
            `remote_dumps_useragent` for details. Defaults to looking
            for the API key in the Obvius configuration instead.

        timeout
            The maximum amount of seconds to wait for a remote to be
            created. Defaults to five minutes.

        protocol
            The protocol to use when contacting the remote server.
            Default is 'https'.
            Should be set to 'http' when making calls to localhost
            from within a web container.

=cut
sub fetch_remote_dump {
    my ($self, $host, $path_and_filename, %options) = @_;

    # Make sure $path_and_filename begins with a single slash
    $path_and_filename =~ s{^/*}{/};

    # Separate filename from path
    my ($path, $filename) = ($path_and_filename =~ m{(.*/)([^/]+)$}x);
    if(!$path) {
        carp "Could not split $path_and_filename into path and filename";
        return;
    }

    if($options{force_remote_dump}) {
        my $res = $self->create_remote_dump($host, $path, %options);
        if($res) {
            return $self->store_remote_dump_from_response(
                $host, $path_and_filename, $res
            );
        } else {
            return;
        }
    }

    # If file has already been downloaded, skip download if use_cache is set
    my $dest_file = $self->remote_dumps_dir . '/' . $host . $path_and_filename;
    if(-f $dest_file && $options{use_cache}) {
        return $dest_file;
    }

    my $proto = $options{protocol} || 'https';
    my $dump_service_uri = $options{dump_service_uri} || ':obvius/dumps';
    my $url = "${proto}://${host}/${dump_service_uri}${path_and_filename}";

    my $ua = $self->remote_dumps_useragent($host, %options);

    my $res = $ua->get($url);
    if($res->code == 200) {
        return $self->store_remote_dump_from_response(
            $host, $path_and_filename, $res
        );
    }

    if($res->code == 404 && $path_and_filename =~ m{exported.zip$}x) {
        $res = $self->create_remote_dump($host, $path, %options);
        if($res) {
            return $self->store_remote_dump_from_response(
                $host, $path_and_filename, $res
            );
        } else {
            croak "Remote dump at $url has failed";
        }
    }

    if($res->code == 500) {
        croak "Remote dump at $url has failed";
    }

    my $code = $res->code;
    return croak "Do not know how to handle response code $code from $url";

}

=item create_remote_dump($host, $path, %options)

Instructs a remote server to create a new dump and waits for the
dump to be created before returning a response object with the
resulting dump.

Will return nothing on failure.

Arguments:

    $host
        The host to create the dump on.

    $full_path
        The URI for the root of the dump followed by a filename ending
        in .zip, usually `exported.zip`.
        The filename part is ignored for this method as it will always
        return the newly created dump.

    %options:

        api_key
            API key used for authentication with remote server. See
            `remote_dumps_useragent` for details. Defaults to looking
            for the API key in the Obvius configuration instead.

        timeout
            The maximum amount of seconds to wait for a remote to be
            created. Defaults to five minutes.

        protocol
            The protocol to use when contacting the remote server.
            Default is 'https'.
            Should be set to 'http' when making calls to localhost
            from within a web container.

=cut
sub create_remote_dump {
    my ($self, $host, $path, %options) = @_;

    # Set default timeout to 5 minutes
    my $timeout = $options{timeout} || 5 * 60;

    my $proto = $options{protocol} || 'https';
    my $base_url = "${proto}://${host}";
    my $dump_service_uri = $options{dump_service_uri} || ':obvius/dumps';
    my $url = $base_url . "/${dump_service_uri}${path}";

    my $ua = $self->remote_dumps_useragent($host, %options);

    my $start_time = time;

    my $res = $ua->post($url);
    if(!$res->is_success) {
        if($res->code == 400) {
            carp "Could not start creation of new dump at $url: " .
                 'Another dump is already being created';
        } else {
            carp "Could not start creation of new dump at $url. " .
                 'Got response status code: ' . $res->code;
        }
        return;
    }

    my $new_uri = eval {
        my $data = JSON::decode_json($res->decoded_content);
        $data->{uri};
    };
    if($@) {
        carp $@;
        return;
    }

    my $new_dump_url = $base_url . $new_uri;
    my $elapsed_time = time - $start_time;

    do {
        $res = $ua->get($new_dump_url);
        if($res->code == 500) {
            carp "Creation of remote dump $new_dump_url failed.";
            return;
        }
        if(!$res->code != 200) {
            print STDERR "Waiting for remote dump at $new_dump_url to be " .
                         "created. Time elapsed: $elapsed_time.\n";
            sleep(5);
        }
        $elapsed_time = time - $start_time;
    } while($res->code != 200 && $elapsed_time < $timeout);

    if($res->code == 200) {
        return $res;
    }

    carp "Timeout while waiting for creation of new dump at $new_dump_url";
    return;
}

=item store_remote_dump_from_response($host, $path_and_filename, $response)

Takes a dump from a successful HTTP::Response and stores it in the local
dumps cache.

Arguments:

    $host
        Hostname of the server the dump was fetched from.

    $path_and_filename
        Obvius URI and filename on the remote server.

    $response
        A HTTP::Response object containing a successfully retrieved dump.

=cut
sub store_remote_dump_from_response {
    my ($self, $host, $path_and_filename, $response) = @_;

    my $dest_file = $self->remote_dumps_dir . '/' . $host .
                    $path_and_filename;
    my $dir = $dest_file;
    $dir =~ s{[^/]+$}{}x;

    File::Path::make_path($dir);

    open(my $fh, '>', $dest_file) or croak "Could not open $dest_file for writing";
    print $fh $response->decoded_content;
    close($fh);

    return $dest_file;
}

=item import_remote_dump($host, $remote_path, $dest_path, %options)

Fetches and imports a remote dump.

Arguments:

    $host
        The host to fetch the dump from

    $remote_path
        The path to dump on the remote host.
        Can be both an Obvius path ending i a / or a path to
        a zip file like '/some_path/exported.zip' or
        '/some_path/2020-01-01_11:45:00.zip'

    %options
        Options passed on to the `fetch_remote_dump` method. See
        the documentation for this method.

=cut
sub import_remote_dump {
    my ($self, $host, $remote_path, $dest_path, %options) = @_;

    if($remote_path =~ m{/$}) {
        $remote_path .= 'exported.zip';
    }

    if($remote_path !~ m{\.zip$}x) {
        croak "Remote path must end in either / or <filename>.zip";
    }

    my $filename = $self->fetch_remote_dump($host, $remote_path, %options);
    $options{'destination'} = $dest_path;
    if($filename) {
        if ($options{'forked-import'}) {
            my $name = $self->obvius->config->param("name");
            local $Data::Dumper::Terse = 1;
            local $Data::Dumper::Indent = 0;
            local $Data::Dumper::Useqq = 1;
            my $modulename = ref($self);
            my $perlcmd = join('',
                'my $i = ', $modulename, '->new("', $name, '");',
                '$i->set_options('.Dumper(\%options).');',
                '$i->import_from_zip_file("', $filename, '");'
            );
            system("perl -M${modulename} -e '$perlcmd' &");
        } else {
            $self->set_options(\%options);
            $self->import_from_zip_file($filename);
        }
    }
}

sub adjust_domain {
    my ($self, $remote_base, $remote_domain) = @_;

    # Can not adjust if we do not have a remote base or a remote domain
    if(!$remote_domain || !$remote_base) {
        return $remote_domain;
    }
    # Can not adjust of we do not have a local base
    my $local_base = $self->obvius->config->param('subsite_base_domain');
    if(!$local_base) {
        return $remote_domain;
    }

    if(substr($remote_domain, -length($remote_domain)) ne $remote_domain) {
        return $remote_domain;
    }

    # Return string with remote base replaced with local base
    return substr($remote_domain, 0, -length($remote_base)) . $local_base;

}

sub flush_cache {
    my ($self) = @_;

    my $obvius = $self->obvius;

    my $cache = WebObvius::Cache::Cache->new($obvius);
    my $modified = $obvius->modified;
    if (defined($modified)) {
        $obvius->clear_modified;
        $cache->find_and_flush($modified);
    }
}

=back
=cut

1;
