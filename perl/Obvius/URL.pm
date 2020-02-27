package Obvius::URL;

use strict;
use warnings;
use utf8;

use Scalar::Util;
use Obvius;
use Obvius::Config;
use Obvius::Hostmap;

my $obvius_ref;
my $hostmap_ref;


=head1 METHODS

=over

=item new($source, %options)

Examples:

    my $url = Obvius::URL->new("/some/path/")
    my $url = Obvius::URL->new("/1234.docid")
    my $url = Obvius::URL->new("https://example.com:666/some/path/?param=value#fragment")

    my $uri = URI->new(...)
    Obvius::URL->new($uri)

    my $other = Obvius::URL->new(...)
    my $url = Obvius::URL->new($other)

Input:
    One of:
        - A path
        - A path in /<docid>.docid format
        - A full URL
        - An URI object
        - Another Obvius::URL object

Output:
    An Obvius::URL object

=cut
sub new {
    my ($class, $source, %options) = @_;

    my $ref = {
        orig_source => $source,
        options => \%options,
    };

    bless($ref, $class);

    $ref->_resolve_source;

    return $ref;
}


=item obvius()

Returns the current obvius object if set. Dies if not obvius
object has been set.

Example:
    my $obvius = $url->obvius

Output:
    An Obvius object

=cut
sub obvius {
    if(!$obvius_ref) {
        die 'Obvius ref not set. Please set it using ' .
        'Obvius::URL->set_obvius($obvius) before calling ' .
        'Obvius::URL->set_obvius.';
    }

    return $obvius_ref;
}

=item set_obvius($obvius)

Sets the obvius object that will be used for resolving URLs. If set to
an existing Obvius object a weak reference will be used to refer to the
object.
If a configname is used a new Obvius object will be created and
refered with a non-weak reference, so it does not go out of scope.

Example:
    Obvius::URL->set_obvius($obvius)
    Obvius::URL->set_obvius("myconfname")

Input:
    An existing Obvius object
    or
    A confname

Output:
    An Obvius object

=cut
sub set_obvius {
    my ($obvius) = @_;

    # Make callable with both Obvius::URL->set_obvius, Obvius::URL::set_obvius
    # and $obj->set_obvius;
    if($obvius && (ref($obvius) || $obvius) eq __PACKAGE__) {
        shift(@_);
        ($obvius) = @_;
    }

    # If we get a config name as first parameter, just create an Obvius
    # object and do not weaken the reference to it, since this module
    # will have the only reference.
    if(!ref($obvius)) {
        $obvius_ref = Obvius->new(Obvius::Config->new($obvius));
        return;
    }

    # Set and weaken reference
    $obvius_ref = $obvius;
    Scalar::Util::weaken($obvius_ref);
}


=item hostmap()

Gets the hostmap for the current Obvius object. If no hostmap
has been saved on the Obvius object a new one will be created.

Example:
    my $hostmap = $url->hostmap($obvius)

Output:
    An Obvius::Hostmap object

=cut
sub hostmap {
    my ($self) = @_;

    if($hostmap_ref && $$hostmap_ref) {
        return $$hostmap_ref;
    }

    $self ||= __PACKAGE__;

    my $hostmap = $self->obvius->config->param('hostmap');
    if(!$hostmap) {
        $hostmap = Obvius::Hostmap->new_with_obvius($self->obvius);
        $self->obvius->config->param('hostmap' => $hostmap);
    }

    # Save and weaken reference to hostmap
    $hostmap_ref = \$hostmap;
    Scalar::Util::weaken($hostmap_ref);

    return $hostmap;
}


# Method intended for internal use: Parses the given source and
# populates variables.
sub _resolve_source {
    my ($self) = @_;

    my $source = $self->{orig_source};

    if(ref($source) eq 'Obvius::URL') {
        $source = $source->{source};
    } elsif(ref($source) eq 'URI') {
        $self->{source_uri_object} = $source;
        $source = $source->as_string;
    } elsif(ref($source) eq 'Obvius::Document') {
        $self->_resolve_docid($source->Id);
    } elsif(ref($source) eq 'Obvius::Version') {
        $self->_resolve_docid($source->DocId);
    }

    $self->{source} = $source;

    # Save URL elements that can be parsed from the source
    my $uri = $self->{source_uri_object} ||= URI->new($self->{source});
    $self->{fragment} = $uri->fragment;
    $self->{querystring} = $uri->query;
    $self->{path} = $uri->path;
    $self->{scheme} = $uri->scheme;
    if($uri->UNIVERSAL::can("port")) {
        $self->{port} = $uri->_port;
    }
    if($uri->UNIVERSAL::can("host")) {
        $self->{hostname} = $uri->host;
    }

    if($self->{path} =~ m{^\d+$}) {
        $self->_resolve_docid($source);
    } elsif($self->{path} =~ m{/(\d+).docid}) {
        $self->_resolve_docid($1);
    } elsif(!$self->{hostname} && $self->{path} =~ m{/}) {
        $self->_resolve_relative_to_root($source);
    } elsif($self->{hostname}) {
        $self->_resolve_with_hostname($source);
    } else {
        die "Do not know how to resolve source '$source'";
    }

}

# Method intended for internal use: Resolves a docid-based
# source.
sub _resolve_docid {
    my ($self, $docid) = @_;

    $self->{docid} = $docid;
}

# Method intended for internal use: Handles path sources that
# are not in docid-format.
sub _resolve_relative_to_root {
    my ($self, $path) = @_;

    my $lookup_uri = $path;
    # Remove querystring and fragment
    $lookup_uri =~ s{\?.*$}{};
    $lookup_uri =~ s{#.*$}{};

    # Add ending slash if it is missing
    if($lookup_uri !~ m{/$}) {
        $lookup_uri .= "/";
    }

    if($self->obvius->lookup_document($lookup_uri)) {
        $self->{obvius_path} = $lookup_uri;
        return;
    }


    if($lookup_uri =~ m{^/admin/}) {
        my $non_admin_uri = substr($lookup_uri, 6);
        if($self->obvius->lookup_document($non_admin_uri)) {
            $self->{obvius_path} = $non_admin_uri;
        }
    }

    # TODO: Handle when the path is relative to a subsite
}

# Method intended for internal use: Handles sources that provide a
# hostname.
sub _resolve_with_hostname {
    my ($self) = @_;

    if($self->{hostname} eq $self->roothost ||
       $self->{hostname} eq $self->https_roothost) {
        $self->_resolve_relative_to_root($self->path);
    } elsif(my $subsite_uri = $self->hostmap->host_to_uri($self->{hostname})) {
        $self->{resolved_path} = $subsite_uri . substr($self->path, 1);

        my ($url, $hostname, $subsite_root_path, $levels, $scheme) =
            $self->hostmap->translate_uri($self->{resolved_path});

        $self->{hostmap_data} = {
            public_url => $url,
            public_hostname => $hostname,
            subsite_root_path => $subsite_root_path,
            levels_from_roothost => $levels,
            scheme => $scheme
        };

        if(my $d = $self->obvius->lookup_document($self->{resolved_path})) {
            $self->{docid} = $d->Id;
            $self->{obvius_path} = $self->{resolved_path};
        }
    }

}

=item source_uri_object()

Returns an URI object parsed from the source of the url.

Example:
    my $uri_obj = $url->source_uri_object;

Output:
    An URI object.

=cut
sub source_uri_object { $_[0]->{source_uri_object} || URI->new($_[0]->path) }

=item port()

Returns port as parsed from the source of the URL. If the scheme for the
url is specified and matches the port number, no value is returned.

Example:
    my $port = $url->port;

Output:
    A port number
    or
    Nothing if the port number matches the scheme

=cut
sub port { $_[0]->{port} }

=item path()

Returns path as parsed from the source of the URL.

Example:
    my $path = $url->path;

Output:
    A path string

=cut
sub path { $_[0]->{path} }

=item resolved_path()

Returns path as resolved in regards to the current Obvius hostmap.
For example if the hostname matches a subsite with obvius path /subsite/
and the path is /my/path/, this method will return /subsite/my/path/.

Example:
    my $path = $url->resolved_path;

Output:
    A path string

=cut
sub resolved_path {
    my ($self) = @_;

    if(!$self->{resolved_path}) {
        if(my $docid = $self->docid) {
            $self->{resolved_path} = $self->obvius_path;
        }
        $self->{resolved_path} ||= $self->path
    }

    return $self->{resolved_path};
}


=item fragment()

Returns fragment as parsed from the source of the URL.

Example:
    my $fragment = $url->fragment;

Output:
    A fragment string
    or
    undef if no fragment was present in the source

=cut
sub fragment { $_[0]->{fragment} }

=item querystring()

Returns querystring as parsed from the source of the URL.

Example:
    my $querystring = $url->querystring;

Output:
    A querystring string
    or
    undef if no querystring was present in the source

=cut
sub querystring { $_[0]->{querystring} }


=item querystring_and_fragment()

Returns querystring and fragment formatted as to be added to an URL.


Example:
    my $url_extra = $url->querystring_and_fragment;

Output:
    When both querystring and fragment are set:
        ?<querystring>#<fragment>
    When only querystring is set:
        ?<querystring>
    When only fragment is set:
        #<fragment>
    When neither querystring or fragment are set:
        '' (the empty string)
=cut

sub querystring_and_fragment() {
    my ($self) = @_;

    my $result = '';
    if(my $qstring = $self->querystring) {
        $result .= "?" . $qstring;
    }
    if(my $fragment = $self->fragment) {
        $result .= "#" . $fragment;
    }

    return $result;
}

=item obvius_path()

Returns the full obvius path of an obvius document matched by the source.

Example:
    my $path = $url->obvius_path;

Output:
    A path string
    or
    undef if no obvius document could be resolved from the source

=cut
sub obvius_path {
    my ($self) = @_;

    if(!exists $self->{obvius_path}) {
        $self->{obvius_path} = undef;

        if(my $docid = $self->docid) {
            if(my $d = $self->obvius->get_doc_by_id($docid)) {
                $self->{obvius_path} = $self->obvius->get_doc_uri($d);
            }
        }
    }

    return $self->{obvius_path};
}

=item docid()

Returns the docid of an obvius document matched by the source.

Example:
    my $docid = $url->docid;

Output:
    A docid
    or
    undef if no obvius document could be resolved from the source

=cut
sub docid {
    my ($self) = @_;

    if(!exists $self->{docid}) {
        $self->{docid} = undef;

        if(my $path = $self->obvius_path) {
            if(my $d = $self->obvius->lookup_document($path)) {
                $self->{docid} = $d->Id;
            }
        }
    }

    return $self->{docid};
}

# Method intended for internal use: Returns any data found by making
# a lookup in the Obvius Hostmap.
sub _hostmap_data {
    my ($self) = @_;

    if(!exists $self->{hostmap_data}) {
        # By default set hostmap data to nothing
        $self->{hostmap_data} = undef;

        # Handle URLs under the roothost
        if($self->{hostname} && (
            $self->{hostname} eq $self->roothost ||
            $self->{hostname} eq $self->https_roothost
        )) {
            $self->{hostmap_data} = {
                public_url => join("",
                    $self->scheme, "://",
                    $self->{hostname},
                    $self->port ? (":" . $self->port) : '',
                    $self->obvius_path
                ),
                public_hostname => $self->{hostname},
                subsite_root_path => "/",
                levels_from_roothost => 0,
                scheme => $self->scheme,
            };
        } elsif(my $path = $self->obvius_path) {
            my ($url, $hostname, $subsite_root_path, $levels, $scheme) =
                $self->hostmap->translate_uri($path);
            $self->{hostmap_data} = {
                public_url => $url,
                public_hostname => $hostname,
                subsite_root_path => $subsite_root_path,
                levels_from_roothost => $levels,
                scheme => $scheme
            };
        }
    }

    return $self->{hostmap_data};
}

=item public_hostname()

Returns the hostname used in a public Obvius URL. Returns undef if the source
could not be resolved to an Obvius document.

Example:
    my $hostname = $url->public_hostname;

Output:
    A hostname string
    or
    undef if no obvius document could be resolved from the source

=cut
sub public_hostname {
    my ($self) = @_;

    if(!exists $self->{public_hostname}) {
        $self->{public_hostname} = undef;
        if(my $hostmap_data = $self->_hostmap_data) {
            $self->{public_hostname} = $hostmap_data->{public_hostname};
        }
    }

    return $self->{public_hostname};
}

=item roothost()

Returns the root hostname for the current Obvius instance.

Example:
    my $hostname = $url->roothost;

Output:
    A hostname string

=cut
sub roothost { $_[0]->obvius->config->param('roothost') || '' }

=item https_roothost()

Returns the root https hostname for the current Obvius instance.

Example:
    my $hostname = $url->https_roothost;

Output:
    A hostname string

=cut
sub https_roothost { $_[0]->obvius->config->param('https_roothost') || '' }


=item scheme()

Returns the schema part of the URL. Returns undef if no scheme could be
found from the source or from a resolved Obvius document

Example:
    my $scheme = $url->scheme;

Output:
    A hostname string
    or
    undef if no scheme could be resolved from the source

=cut
sub scheme {
    my ($self) = @_;

    if(my $hostmap_data = $self->_hostmap_data) {
        return $hostmap_data->{scheme};
    }

    return $self->source_uri_object->scheme || undef;
}

# Method intended for internal use: Used to look up information on the subsite
# closest to a document resolved from the source. Will return undef if no
# document is matched or if a document with no subsite is matched by the
# source.
sub _closest_subsite_data {
    my ($self) = @_;

    if(!exists $self->{closest_subsite_data}) {
        $self->{closest_subsite_data} = undef;
        if(my $docid = $self->docid) {
            my $sth = $self->obvius->dbh->prepare(q|
                select
                    subsites2.id subsite_id,
                    docid_path.path path
                from
                    docs_with_extra
                    left join subsites2 on (
                        docs_with_extra.closest_subsite = subsites2.id
                    )
                    left join docid_path on (
                        subsites2.root_docid = docid_path.docid
                    )
                where
                    docs_with_extra.id = ?
            |);
            $sth->execute($docid);
            if(my ($subsite_id, $path) = $sth->fetchrow_array) {
                $self->{closest_subsite_data} = {
                    id => $subsite_id,
                    path => $path
                };
            }
        } elsif(my $path = $self->path) {
            my $sth = $self->obvius->dbh->prepare(q|
                select
                    subsites2.id subsite_id,
                    docid_path.path path
                from
                    subsites2
                    join docid_path on (
                        subsites2.root_docid = docid_path.docid
                    )
                where
                    docid_path.path = ?
            |);
            # Add ending slash to path if it is not already there
            if($path !~ m{/$}) {
                $path .= "/";
            }
            while($path ne "/") {
                $sth->execute($path);
                if(my ($subsite_id, $path) = $sth->fetchrow_array) {
                    $self->{closest_subsite_data} = {
                        id => $subsite_id,
                        path => $path
                    };
                    last;
                }
                $path =~ s{[^/]*/$}{};
            }
        }
    }

    return $self->{closest_subsite_data};
}

=item closest_subsite_id()

Returns the id of the subsite closest to a document resolved from the source.
Returns undef if no document could be matched or if the matched document does
not have a closest subsite.

Example:
    my $subsite_id = $url->closest_subsite_id;

Output:
    An id of a subsite
    or
    undef if no subsite could be resolved from the source

=cut
sub closest_subsite_id {
    my ($self) = @_;

    if(my $subsite_data = $self->_closest_subsite_data) {
        return $subsite_data->{id};
    }

    return undef;
}

=item closest_subsite_path()

Returns the path of the subsite closest to a document resolved from the
source. Returns undef if no document could be matched or if the matched
document does not have a closest subsite.

Example:
    my $subsite_path = $url->closest_subsite_path;

Output:
    An Obvius path pointing to a subsite
    or
    undef if no subsite could be resolved from the source

=cut
sub closest_subsite_path {
    my ($self) = @_;

    if(my $subsite_data = $self->_closest_subsite_data) {
        return $subsite_data->{path};
    }

    return undef;
}

# Method intended for internal use: Used to look up information on the
# domain-enabled subsite closest to a document resolved from the source.
# Will return undef if no document is matched or if a document with no
# domain-enabled subsite is matched by the source.
sub _domain_subsite_data {
    my ($self) = @_;

    if(!exists $self->{domain_subsite_data}) {
        $self->{domain_subsite_data} = undef;
        if(my $docid = $self->docid) {
            my $sth = $self->obvius->dbh->prepare(q|
                select
                    subsites2.id subsite_id,
                    docid_path.path path
                from
                    path_tree
                    join
                    subsites2 on (
                        subsites2.root_docid = path_tree.parent
                        and
                        subsites2.domain IS NOT NULL
                        and
                        subsites2.domain != ''
                    )
                    join docid_path on (
                        subsites2.root_docid = docid_path.docid
                    )
                where
                    path_tree.child = ?
                order by
                    path_tree.depth
                limit 1
            |);
            $sth->execute($docid);
            if(my ($subsite_id, $path) = $sth->fetchrow_array) {
                $self->{domain_subsite_data} = {
                    id => $subsite_id,
                    path => $path
                };
            }
        } elsif(my $path = $self->path) {
            if(my $hostmap_data = $self->_hostmap_data) {
                my $sth = $self->obvius->dbh->prepare(q|
                    select id from subsites2 where domain = ?
                |);
                $sth->execute($hostmap_data->{public_hostname});
                my ($id) = $sth->fetchrow_array;
                $self->{domain_subsite_data} = {
                    id => $id,
                    path => $hostmap_data->{subsite_root_path}
                };
            }
        }
    }

    return $self->{domain_subsite_data};
}

=item domain_subsite_id()

Returns the id of the subsite closest to a document resolved from the source,
that also has a domain.
Returns undef if no document could be matched or if the matched document is
not below a subsite with a domain.

Example:
    my $subsite_id = $url->domain_subsite_id;

Output:
    An id of a subsite
    or
    undef if no subsite could be resolved from the source

=cut
sub domain_subsite_id {
    my ($self) = @_;

    if(my $subsite_data = $self->_domain_subsite_data) {
        return $subsite_data->{id};
    }
}

=item domain_subsite_path()

Returns the path of the subsite closest to a document resolved from the
source, that also has a domain.
Returns undef if no document could be matched or if the matched document is
not below a subsite with a domain.

Example:
    my $subsite_path = $url->domain_subsite_path;

Output:
    A path of a subsite
    or
    undef if no subsite could be resolved from the source

=cut
sub domain_subsite_path {
    my ($self) = @_;

    if(my $subsite_data = $self->_domain_subsite_data) {
        return $subsite_data->{path};
    }
}

=item public_path()

Returns the resolved public path from the source, taking matched Obvius
documents and subsites into account: When matching a document below a
subsite with a domain, the subsite part of the full resolved path will
have been removed.
Will return the original path from the source if no connection to Obvius
documents or subsites could be made.

Example:
    my $path = $url->public_path;

Output:
    A resolved Obvius public path
    or
    The original path from the source if no document or subsite could
    be matched from the source.

=cut
sub public_path {
    my ($self) = @_;

    my $subsite_path = $self->domain_subsite_path || '';

    if($subsite_path) {
        return substr($self->resolved_path, length($subsite_path) - 1);
    }

    return $self->obvius_path || $self->path;
}

=item has_public_path()

Returns whether an Obvius document matched by the source has a public
path or not. Will return undef if no document could be matched from the
source.

Example:
    my $is_public = $url->has_public_path;

Output:
    1 if an Obvius document was matched and the document has a fully
    public path.

    0 if an Obvius document was matched and the document does not have
    a fully public path.

    undef if no documment could be matched from the source.

=cut
sub has_public_path {
    my ($self) = @_;

    if(!exists $self->{has_public_path}) {
        $self->{has_public_path} = undef;
        if(my $docid = $self->docid) {
            my $sth = $self->obvius->dbh->prepare(q|
                select
                    docs_with_extra.has_public_path
                from
                    docs_with_extra
                where
                    docs_with_extra.id = ?
            |);
            $sth->execute($docid);
            if(my $result = $sth->fetchrow_array) {
                $self->{has_public_path} = $result ? 1 : 0;
            }
        }
    }

    return $self->{has_public_path};
}

=item open_in_new_window()

Returns whether a link to an Obvius document matched by the source should
open in a new window.

Example:
    my $open_in_new_window = $url->open_in_new_window;

Output:
    1 if an Obvius document was matched and the document is of a type
    that should be opened in a new window.

    0 if an Obvius document was matched and the document is not of a
    type that should be opened in a new window or if no document could
    be matched.

=cut
sub open_in_new_window {
    my ($self) = @_;

    if(!exists $self->{open_in_new_window}) {
        $self->{open_in_new_window} = 0;
        if(my $docid = $self->docid) {
            my $sth = $self->obvius->dbh->prepare(q|
                select
                    vfields.text_value mimetype
                from
                    docs_with_extra
                    join versions on (
                        docs_with_extra.public_or_latest_version = versions.id
                    )
                    join vfields on (
                        versions.docid = vfields.docid
                        and
                        versions.version = vfields.version
                        and
                        vfields.name = "mimetype"
                    )
                where
                    docs_with_extra.id = ?
            |);
            $sth->execute($docid);
            my ($mimetype) = $sth->fetchrow_array;
            if($mimetype && $mimetype =~ m{application/}) {
                $self->{open_in_new_window} = 1;
            }
        }
    }

    return $self->{open_in_new_window};
}

=item public_url()

Returns a full URL as constructed from the source. If an Obvius document
is matched, schema, hostname and path will have been canonized to match
relevant document and subsite data.
If the source did not match any Obvius data as much of an URL as can be
constructed from the original data will be returned.

Example:
    my $public_url = $url->public_url;

Output:
    An URL string.

=cut
sub public_url {
    my ($self) = @_;

    if($self->_hostmap_data) {
        return join("",
            $self->scheme || 'https',
            '://',
            $self->public_hostname || $self->roothost,
            $self->port ? (":" . $self->port) : '',
            $self->public_path,
            $self->querystring ? ("?" . $self->querystring) : '',
            $self->fragment ? ('#' . $self->fragment) : '',
        );
    } else {
        return $self->source_uri_object->as_string;
    }
}

=item resource_url($in_admin)

Returns an URL that can be used to point a resource, for example the path
used in the src attribute on an image tag. If the source matched an Obvius
document canonized Obvius public and admin URLs will be returned.

Example:
    my $image_src = $url->resource_url;

Input:
    $in_admin - a boolean value specifying whether the resulting URL should
                point inside Obvius admin or to a public path.

Output:
    An URL string.

=cut
sub resource_url {
    my ($self, $in_admin) = @_;

    if($self->_hostmap_data) {
        if($in_admin) {
            my $path = $self->admin_path;
            $path =~ s{/$}{};

            return join("",
                'https://',
                $self->roothost,
                $path,
                $self->querystring ? ("?", $self->querystring) : '',
                $self->fragment ? ('#' . $self->fragment) : '',
            );
        } else {
            return $self->public_url;
        }
    } else {
        return $self->source_uri_object->as_string;
    }
}

=item admin_path($remove_ending_slash)

Returns the path that is used to access the document in admin.
An optional argument specifies whether to remove the last slash of
the URI.

Example:
    my $admin_path = $url->admin_path;
    my $admin_path_without_slash = $url->admin_path(1)

Output:
    A path pointing to the document within admin.

=cut
sub admin_path {
    my ($self, $remove_ending_slash) = @_;

    if($self->_hostmap_data) {
        my $result = '/admin' . $self->resolved_path;
        if($remove_ending_slash) {
            $result =~ s{/$}{};
        }
        return $result;
    } else {
        return $self->source_uri_object->path;
    }
}

=item admin_url()

Returns the canonical Obvius admin URL for a matched document. Will return
the source URL if no documentis matched.

Example:
    my $admin_url = $url->admin_url;

Output:
    An URL string.

=cut
sub admin_url {
    my ($self) = @_;

    if($self->_hostmap_data) {
        return join("",
            'https://',
            $self->roothost,
            $self->admin_path,
            $self->querystring ? ("?", $self->querystring) : '',
            $self->fragment ? ('#' . $self->fragment) : '',
        );
    } else {
        return $self->source_uri_object->as_string;
    }
}

=item all_data()

Returns all available data that can be found for the URL as a hashref.

Example:
    my $url_data = $url->url_data;

Output:
    An URL string.

=cut
sub all_data {
    my ($self) = @_;

    my $has_public_path = $self->has_public_path;
    my $public_res_url = $self->resource_url;
    my $admin_res_url = $self->resource_url(1);

    return {
        source => $self->{source},
        fragment => $self->{fragment},
        querystring => $self->{querystring},
        querystring_and_fragment => $self->querystring_and_fragment,
        docid => $self->docid,
        obvius_path => $self->obvius_path,
        admin_path => $self->admin_path,
        closest_subsite_id => $self->closest_subsite_id,
        closest_subsite_path => $self->closest_subsite_path,
        domain_subsite_id => $self->domain_subsite_id,
        domain_subsite_path => $self->domain_subsite_path,
        public_url => $self->public_url,
        admin_url => $self->admin_url,
        resource_url => $has_public_path ? $public_res_url : $admin_res_url,
        resource_path => $has_public_path ? $self->obvius_path : $self->admin_path(1),
        public_resource_url => $public_res_url,
        admin_resource_url => $admin_res_url,
        has_public_path => $has_public_path,
        open_in_new_window => $self->open_in_new_window,
    };
}

=back

=cut

1;
