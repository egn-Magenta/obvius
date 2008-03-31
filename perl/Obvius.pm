package Obvius;

########################################################################
#
# Obvius.pm - Content Manager, database handling
#
# Copyright (C) 2001-2004 Magenta Aps, Denmark (http://www.magenta-aps.dk/)
#                         aparte A/S, Denmark (http://www.aparte.dk/),
#                         FI, Denmark (http://www.fi.dk/)
#
# Authors: Jørgen Ulrik B. Krag (jubk@magenta-aps.dk)
#          Peter Makholm (pma@fi.dk)
#          René Seindal,
#          Adam Sjøgren (asjo@magenta-aps.dk),
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2, or (at your option)
# any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software Foundation,
# Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
#
########################################################################

# $Id$

use strict;
use warnings;

require 5.008;

require Exporter;
use Obvius::Data;
use Data::Dumper;
use Cache::FileCache;

use WebObvius::Cache::CacheObjects; 
use WebObvius::Cache::AdminLeftmenuCache qw( cache_new_version_p );
use WebObvius::Cache::ApacheCache qw(is_relevant_for_leftmenu_cache);

our @ISA = qw(  Obvius::Data
                Obvius::DB
                Obvius::Access
                Obvius::Users
                Obvius::Subscriptions
                Obvius::Tables
                Obvius::VoteSystem
                Obvius::Comments
                Obvius::Utils
                Obvius::Pubauth
                Obvius::Annotations
                Obvius::Queue
                Exporter
            );
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

our @EXPORT = qw(OBVIUS_OK OBVIUS_DECLINE OBVIUS_ERROR);
our @EXPORT_OK = ();
our %EXPORT_TAGS = ();

use constant OBVIUS_ERROR => 0;
use constant OBVIUS_OK => 1;
use constant OBVIUS_DECLINE => 2;

use POSIX qw(strftime);

use DBIx::Recordset;
use Params::Validate qw(validate);

use Data::Dumper;
use Carp qw(cluck confess carp croak);

use Obvius::Data;
use Obvius::Config;
use Obvius::Cache;

use Obvius::Document;
use Obvius::DocType;
use Obvius::EditPage;
use Obvius::Version;
use Obvius::FieldSpec;
use Obvius::FieldType;
use Obvius::Log;

use Obvius::DB;
use Obvius::Access;
use Obvius::Users;
use Obvius::Subscriptions;
use Obvius::Tables;
use Obvius::VoteSystem;
use Obvius::Comments;
use Obvius::Utils;
use Obvius::Pubauth;
use Obvius::Annotations;
use Obvius::Queue;


########################################################################
#
#       Construction and connection
#
########################################################################

sub new {
    my($class, $obvius_config, $user, $password, $doctypes, $fieldtypes, $fieldspecs, %options) = @_;

    croak("Configuration missing")
        unless ($obvius_config);

    my $this = $class->SUPER::new(OBVIUS_CONFIG => $obvius_config,
                                  USER        => $user,
                                  PASSWORD    => $password,
                                  DB          => undef,
                                  DEBUG       => $obvius_config->param('DEBUG'),
                                  BENCHMARK   => $obvius_config->param('BENCHMARK'),
                                  LOG         => (defined $options{'log'} ? $options{'log'} : new Obvius::Log $obvius_config->param('DEBUG')),
                                  DOCTYPES    => (defined $doctypes ? $doctypes : []),
                                  FIELDTYPES  => (defined $fieldtypes ? $fieldtypes : []),
                                  FIELDSPECS  => (defined $fieldspecs ? $fieldspecs : new Obvius::Data),
                                  LANGUAGES   => {}
                                 );

    croak("No database specified")
        unless ( $this->Obvius_Config->DSN );
    
    $this->connect;
    if ($this->{USER} and not $this->validate_user) {
	 print STDERR "User not valid.\n";
	 return undef;
    }

    return $this;
}

sub connect {
    my ($this) = @_;

    $this->tracer() if ($this->{DEBUG});

    return $this->{DB} if (defined($this->{DB}));

    $this->{LOG}->debug( ref($this) . ": connecting");

    #
    # ACHTUNG: We should really make DBIx::Recordset::LOG a tied filehandle
    #          using $this->{LOG} as backend.
    #

    if ($this->{DEBUG}>1) {
        $DBIx::Recordset::Debug = 2;
        *DBIx::Recordset::LOG = \*STDERR;
    }

    my $config = $this->{OBVIUS_CONFIG};
    my $db = new DBIx::Database( {'!DataSource' => $config->param('DSN'),
                                  '!Username'   => $config->param('normal_db_login'),
                                  '!Password'   => $config->param('normal_db_passwd'),
                                  '!KeepOpen'   => 1,
                                  '!DBIAttr'    => {
                                                    AutoCommit => 1,
                                                    RaiseError => 1,
                                                    PrintError => 1,
                                                    ShowErrorStatement => ($this->{DEBUG} ? 1 : 0),
                                                   },
                                 } );
    croak(ref($this), ": failed to connect to database")
        unless (defined($db));

    $db->TableAttr('*', '!TieRow' => 0);
    $db->TableAttr('*', '!Debug'  => 2) if ($this->{DEBUG});

    $db->TableAttr('doctypes',   '!Serial' => 'id');
    $db->TableAttr('documents',  '!Serial' => 'id');
    $db->TableAttr('fieldtypes', '!Serial' => 'id');

    $this->{DB} = $db;
    # If the object doesnt have any DOCTYPES, FIELDTYPES or FIELDSPECS, read from the database:
    unless (scalar(@{$this->{DOCTYPES}}) and 
	    scalar(@{$this->{FIELDTYPES}}) and 
	    scalar ($this->{FIELDSPECS}->param)) 
    {
        $this->read_type_info(1)
    }
    $this->read_user_and_group_info;

    #print STDERR Dumper($db->MetaData('documents'));
    
    return $db;
}

sub dbh { shift-> {DB}->{'*DBHdl'} }

sub config {
    my ($this) = @_;

    return $this->{OBVIUS_CONFIG};
}

# user - returns the current users login as a string.
sub user {
    my ($this)=@_;

    return $this->{USER};
}


########################################################################
#
#       Object cache
#
########################################################################

sub cache {
    my ($this, $onoff) = @_;

    if ($onoff) {
        $this->{CACHE} = new Obvius::Cache unless ($this->{CACHE});
    } else {
        undef $this->{CACHE};
    }

    return 1;
}

sub cache_add {
    my ($this, $obj) = @_;

    $this->{CACHE}->add($obj) if ($this->{CACHE});
}

sub cache_find {
    my ($this, $domain, %key) = @_;

    return ($this->{CACHE}) ? $this->{CACHE}->find($domain, \%key) : undef;
}


########################################################################
#
#       Error logging
#
########################################################################

our $LOG;                 # Log-object used if no $obvius object is available
$LOG ||= new Obvius::Log 0;

sub log {
    my ($this) = @_;

    # Hmmmm, could there ever be a way that we can find a reasonable $obvius
    # object if it isn't given to us directly? $::obvius, maybe?
    if (defined $this && defined $this->{LOG}) {
        return $this->{LOG};
    }
    return $LOG;
}



########################################################################
#
#       Path to document mapping and vice versa
#
########################################################################

sub get_root_document
{
        my ($this) = @_;
        #XXX Assumes root is 1 !!
        return $this->get_doc_by_id(1);
}

sub get_universal_document
{
        my $this = $_[0];

        # Assume 'universal' is 5, but check for older database layouts
        my $universal = $this-> get_doc_by_id(5);
        return ( defined($universal) && $universal-> Name eq 'universal') ?
                $universal : undef;
}

sub lookup_document {
    my ($this, $path) = @_;

    $this->tracer($path) if ($this->{DEBUG});

    if (wantarray) {
        my $path_info;
        if (my @path = $this->get_doc_by_path($path, \$path_info)) {
            return ($path[-1], $path_info);
        }
        return ();
    }
    if (my @path = $this->get_doc_by_path($path)) {
        return $path[-1];
    }
    return undef;
}

# Overveje at tilføje stiens id'er til Obvius::Document når de alligevel slås op hér
# (så er get_doc_path triviel):
#
# Bemærk: Giver alle dokumenterne på stien tilbage i et array:
sub get_doc_by_path {
    my ($this, $uri, $path_info) = @_;

    $this->tracer($uri, $path_info||'') if ($this->{DEBUG});

    if ($uri =~ /^\/(\d+).docid\/?$/) {
        return ($this->get_doc_by_id($1));
    }

    my $id = 1; # XXX DOC ROOT
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
    my ($this, $doc) = @_;

    $this->tracer($doc) if ($this->{DEBUG});

    my @path = ( $doc );
    while ($doc->_id != 1) {            # XXX DOC ROOT
        my $parent = $this->get_doc_by_id($doc->_parent);
        unshift(@path, $parent);
        $doc = $parent;
    }

    return @path;
}

sub get_doc_uri {
    my ($this, $doc) = @_;

    my @path = $this->get_doc_path($doc);
    shift(@path);                       # remove root

    return '/' unless (@path);
    my $uri = '/' . join('/', map { $_->param('name') } @path) . '/';
    $uri =~ s!/+!/!g;
    return $uri;
}

# is_doc_below_doc - given two document-objects, returns true if the
#                    first document is in the second documents
#                    subtree. If not returns false.
sub is_doc_below_doc {
    my ($this, $first, $second)=@_;

    my $root_id=$this->get_root_document()->Id;

    my $parent_doc=$first;
    while ($parent_doc=$this->get_doc_by_id($parent_doc->Parent)) {
        return 1 if ($parent_doc->Id eq $second->Id);
    }

    return 0;
}


########################################################################
#
#       Look up documents by id or (name,parent)
#
########################################################################

sub get_doc_by_id {
    my ($this, $id) = @_;

    $this->tracer($id) if ($this->{DEBUG});

    return $this->get_doc_by(id=>$id);
}

sub get_doc_by_name_parent {
    my ($this, $name, $parent) = @_;

    $this->tracer($name, $parent) if ($this->{DEBUG});

    return $this->get_doc_by(parent=>$parent, name=>$name);
}

sub get_doc_by {
    my ($this, @how) = @_;
    
    $this->tracer(@how) if ($this->{DEBUG});

    my $doc = $this->cache_find('Obvius::Document', @how);
    return $doc if ($doc);

    my $set = DBIx::Recordset->SetupObject( {'!DataSource' => $this->{DB},
                                             '!Table'      => 'documents',
                                            } );
    $set->Search( {@how} );
    if (my $rec = $set->Next) {
        $doc = new Obvius::Document($rec);
        $this->cache_add($doc);
        confess "More than one document matched by get_doc_by\n" if $set->Next;
    }

    $set->Disconnect;
    return $doc;
}

sub get_docs_by_parent { # Call with docid!
    my($this, $parent) = @_;

    my $docs=$this->get_docs_by(parent=>$parent);

    return $docs;
}

sub get_docs_by {
    my ($this, @how) = @_;

    $this->tracer(@how) if ($this->{DEBUG});

    my $set = DBIx::Recordset->SetupObject( {'!DataSource' => $this->{DB},
                                             '!Table'      => 'documents',
                                            } );
    my @subdocs;
    $set->Search( {@how} );
    while (my $rec = $set->Next) {
        my $doc = $this->cache_find('Obvius::Document', @how);
        unless ($doc) {
            $doc = new Obvius::Document($rec);
            $this->cache_add($doc);
        }
        push @subdocs, $doc;
    }

    $set->Disconnect;
    return (@subdocs ? \@subdocs : undef);
}



########################################################################
#
#       Public document check
#
########################################################################

# is_public_document - et dokument er offentligt hvis der findes en offentlig
#             version af dokumentet og alle dokumenter på stien til
#             det er offentlige. Noget andet er så hvilke(t) sprog
#             det er offentligt på.

sub is_public_document {
    my ($this, $doc, %options) = @_;

    $this->tracer($doc) if ($this->{DEBUG});
    unless ($doc) {
        warn "IS_PUBLIC_DOCUMENT CALLED ON AN UNDEFINED DOC - there's a bug somewhere calling is_public_document. Go hunt.";
        return 0;
    }

    # Take advantage of the hint that $doc _is_ public itself by
    # starting the check at the parent but only for well-defined parrents:
    unless ($doc->Parent == 0) {
        $doc=$this->get_doc_by_id($doc->Parent) if ($options{doc_is_public});
    }

    my @path=$this->get_doc_path($doc);
    for (@path) {
        my $public = 0;
        if ($this->get_public_version($_)) {
            $public = 1;
        }

        #printf STDERR ("ID %5d NAME %-20s PUBLIC %d\n",
        #              $_->_id, $_->_name, $public)
        #    if ($this->{DEBUG});

        return '' if ($public == 0);
    }

    return 1;
}



########################################################################
#
#       Multilingual helpers
#
########################################################################

# select_best_language_match - selects the best match of the versions
#                              in vdocs, considering the
#                              language-preferences.
sub select_best_language_match {
    my ($this, $vdocs) = @_;

    $this->tracer($vdocs) if ($this->{DEBUG});

    return undef unless ($vdocs);

    my $prefs = $this->{LANGUAGES};

    my $vdoc = $vdocs->[0];
    return undef unless ($vdoc);
    return $vdoc unless ($prefs);

    my $best = 0;
    for (@$vdocs) {
        my $lang = $_->param('lang');
        if (($prefs->{$lang} ||= 0) > $best) {
            $vdoc = $_;
            $best = $prefs->{$lang};
        }
    }
    return $vdoc;
}

# Select best versions for a mixed list of documents
sub select_best_language_match_multiple {
    my ($this, $vdocs) = @_;

    $this->tracer($vdocs) if ($this->{DEBUG});

    return undef unless ($vdocs);

    my $prefs = $this->{LANGUAGES};

    my %best;                           # best weight by docid
    my %vdocs;                          # version by docid

    for (@$vdocs) {
        my $lang = $_->param('lang');
        my $docid = $_->param('docid');

        unless ($vdocs{$docid}) {
            $best{$docid} = 0;
            $vdocs{$docid} = $_;
        }

        # If language-preference is equal, we prefer the newer version:
        if (($prefs->{$lang} ||= 0) > $best{$docid} or
            (($prefs->{$lang} ||= 0) == $best{$docid}  and
             $_->{VERSION} gt $vdocs{$docid}->{VERSION})) {
            $vdocs{$docid} = $_;
            $best{$docid} = $prefs->{$lang};
        }
    }

    return [ grep { $vdocs{$_->_docid} == $_ } @$vdocs ];
}



########################################################################
#
#       Look up versions of a document
#
########################################################################

sub get_public_version {
    my ($this, $doc) = @_;

    $this->tracer($doc) if ($this->{DEBUG});

    return undef unless ($doc);
    return $doc->param('public_version') if ($doc->param('public_version'));

    my $public_versions = $this->get_public_versions($doc);
    return undef unless ($public_versions);

    my $vdoc = $this->select_best_language_match($public_versions);
    $doc->param(public_version => $vdoc);

    return $vdoc;
}

sub get_public_version_field {
    my ($this, $doc, $name) = @_;

    my $vdoc = $this->get_public_version($doc);
    return $vdoc ? $this->get_version_field($vdoc, $name) : undef;
}

sub get_latest_version {
    my ($this, $doc) = @_;

    $this->tracer($doc) if ($this->{DEBUG});

    my $versions = $this->get_versions($doc, '$order'=>'version DESC', '$max' => 1);

    return $versions->[0];
}

# get_version - given a document-object and a string identifying a
#               version, returns a version-object representing that
#               version.
sub get_version {
    my ($this, $doc, $version) = @_;

    $this->tracer($doc) if ($this->{DEBUG});

    my $versions = $this->get_versions($doc, version=>$version, '$max' => 1);

    return $versions->[0];
}

# get_public_versions - given a document-object, returns an array-ref
#                       containing version-objects for all the public
#                       version of the document.
#                       Note that a document can have multiple public
#                       versions, at most one per language.
#                       The array-ref is cached on the document-object
#                       for quick retrieval.
#                       XXX TODO: Handle Expires, Published?
sub get_public_versions {
    my($this, $doc) = @_;

    $this->tracer($doc) if ($this->{DEBUG});

    return $doc->param('public_versions') if ($doc->param('public_versions'));

    my $public_versions = $this->get_versions($doc, public=>1);
    $doc->param(public_versions => $public_versions);
    return $public_versions;
}

sub get_versions {
    my ($this, $doc, %options) = @_;

    $this->tracer($doc) if ($this->{DEBUG});

    croak "doc not an Obvius::Document\n"
        unless (ref $doc and $doc->UNIVERSAL::isa('Obvius::Document'));

    # Måske noget tilsvarende nedenstående linie for samtlige
    # versions? Måske i virkeligheden kun for samtlige versions, og så
    # kan get_public_versions filtrere i den fuldstændige liste?
    #  return $doc->param('public_versions') if ($doc->param('public_versions'));

    my $set = DBIx::Recordset->SetupObject({'!DataSource' => $this->{DB},
                                            '!Table'      => 'versions',
                                           });

    $set->Search({ docid=>$doc->_id, %options });
    my @versions;
    while (my $rec = $set->Next) {
        push @versions, Obvius::Version->new($rec);
    }
    $set->Disconnect;

    return @versions ? \@versions : undef;
}



########################################################################
#
#       Look up document public subdocs (returns array of Obvius::Version)
#
########################################################################

sub get_document_subdocs {
    my ($this, $doc, %options) = @_;

    $this->tracer($doc) if ($this->{DEBUG});

    my $sortvdoc=$options{sortvdoc};
    $sortvdoc=$this->get_public_version($doc) unless ($sortvdoc);

    # This ought to sort by version, so that the newest version is
    # selected (or perhaps select_best_very_long_method_name should do
    # that?):
    #
    # Changed select_blah_blah to do that (search calls that). Hope it
    # doesn't break anything.
    my $subdocs=$this->search(
                              [],
                              'parent = ' . $doc->Id,
                              needs_document_fields=>[qw(parent)],
                              sortvdoc => $sortvdoc,
                              public=>1, # Results in max one version per language per docid
                              %options,  # which is what select_best_lang...() expects.
                             );

    $subdocs=[] unless $subdocs; # Empty list if there are no subdocs
    return $subdocs;
}

# Jason: I need this one to get the latest version for the EtikSubthemes
# asjo: You could've just passed sortvdoc=>$obvius->get_latest_version($doc)
# to get_document_subdocs :-)

sub get_document_subdocs_latest {
  my ($this, $doc, %options) = @_;

  $this->tracer($doc) if ($this->{DEBUG});

  my $sortvdoc=$options{sortvdoc};
  $sortvdoc=$this->get_latest_version($doc) unless ($sortvdoc);

  my $subdocs=$this->search(
                             [],
                             'parent = ' . $doc->Id,
                             needs_document_fields=>[qw(parent)],
                             sortvdoc => $sortvdoc,
                             %options,
                            );

  $subdocs=[] unless $subdocs; # Empty list if there are no subdocs
  return $subdocs;
}

sub get_nr_of_subdocs {
    my ($this, $doc, %options) = @_;

    return 0 unless($doc);

    my $tables = 'documents';
    my $where = "parent = " . $doc->Id;

    if($options{public}) {
        $tables .= ", versions";
        $where .= " AND documents.id = versions.docid and versions.public = 1";
    }


    my $set = DBIx::Recordset->SetupObject(
                                            {
                                                '!DataSource' => $this->{DB},
                                                '!Table'      => $tables,
                                                '!Fields'     => 'COUNT(documents.id) as count'
                                            }
                                        );
    $set->Search($where);
    my $number = 0;
    if(my $rec = $set->Next) {
        $number = $rec->{count};
    }
    $set->Disconnect;

    return $number;

}



########################################################################
#
#       Search for documents (returns array of Obvius::Version)
#
########################################################################

# calc_order_for_query($sortvdoc) - Determines how subdocuments to a
#           document should be sorted. Takes a $vdoc as argument and
#           returns a hashref which keys represent unique fields to be
#           used in the sorting and an arrayref containing the order of
#           the fields. The content of the array can be joined together
#           with "," and used for an SQL ORDER BY clause.
sub calc_order_for_query {
    my ($this, $sortvdoc) = @_;

    my %sort_fields=();
    my @order=();

    my @sort_fields;
    my $sortdoctype=$this->get_document_type($sortvdoc);
    if (my $sortorder_field=$sortdoctype->param('sortorder_field_is')) {
        my $sortorder=$this->get_version_field($sortvdoc, $sortorder_field);
        @sort_fields=split /,/, $sortorder;
    }
    else { # No sortorder field - do by sequence:
        @sort_fields=qw(+seq);
    }

    foreach (@sort_fields) {
        if (/([+-])(.*)/) {
            my ($order, $fieldname) = ($1, $2);
            # Allow fields from the version table
            unless($fieldname =~ /(docid|version|type|lang)/) {
                my $fspec=$this->get_fieldspec($fieldname, $sortdoctype);
                unless ($fspec) {
                    warn "Invalid fieldname (no fieldspec found): $fieldname";
                    next;
                }

                unless ($fspec->Sortable) {
                    warn "Can't sort on field $_";
                    next;
                }

                $sort_fields{$fieldname}++;
            }
            push @order, $fieldname . ($order eq '-' ? ' DESC' : '');
        }
        else {
            $this->log->warn("Don't understand sort-field: $_");
        }
    }

    return(\%sort_fields, \@order);
}

sub search {
    my ($this, $fields, $where, %options) = @_;

    $this->tracer($fields, $where, %options) if ($this->{DEBUG});

    my @table = ( 'versions' );
    my @left_join_table;
    my @join;
    my @fields = ( 'versions.*' );
    my @where;
    my %map;
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
        # If we're not searching for public documents, we want to get either
        # the public version if it exists or the latest version if it doesn't.
        # To do this we join the versions table to the query and used MAX
        # and SUM functions in a having clause to figure out which versions we
        # want:

        push(@table, "versions as otherversions");
        push(@join, "versions.docid = otherversions.docid");
        push(@fields, "SUM(otherversions.public) as has_public_version");
        push(@fields, "MAX(otherversions.version) as latest_version");

        $having .= "(versions.public=1 OR (has_public_version = 0 and latest_version = versions.version))";
    }

    # Sorting:
    my ($sort_fields, $order)=$this->calc_order_for_query($options{sortvdoc})
        if defined $options{sortvdoc};

    map { push @$fields, $_ } (keys %$sort_fields);

    if($options{'needs_document_fields'} and ref($options{'needs_document_fields'}) eq 'ARRAY') {
        push(@table, "documents as obvius_documents");
        push(@join, "(obvius_documents.id = versions.docid)");
        for(@{$options{'needs_document_fields'}}) {
            push(@fields, "obvius_documents.$_ as $_");
            $map{$_} = "obvius_documents.$_";
        }
    }

    my %seen;
    for (@$fields) {
        my $do_left_join;
        if(s/^~//) {
            $do_left_join = 1;
        }

        my $fspec = $this->get_fieldspec($_);
        unless ($fspec) {
            # XXX It would perhaps be nicer if we just ignored the
            #     part about the unknown field, but it is not that
            #     easy to do with the limited amount of parsing we do.
            my $message='No fieldspec exists for field "' . $_ . '", returning empty result of Obvius::search on unknown field';
            carp $message;
            $this->log->error($message);
            return [];
        }

        next if (defined $seen{$_} and (!$fspec->Repeatable or $options{override_repeatable}->{$_})); # Duplicate skippage
        $seen{$_}++;

        # Would be cleaner to have a separate list for sorting-fields:
        unless ($fspec->Searchable or $fspec->Sortable) {
            $this->log->warn("Can't search on field $_");
            next;
        }
        my $field = $fspec->FieldType->param('value_field');

        if($do_left_join) {
            # Since mysql 5 we have to join with the table to the left of the
            # LEFT JOIN statement
            my $last_table = $i ? ("vf" . ($i - 1)) : "versions";
            push(@left_join_table, "LEFT JOIN vfields AS vf$i ON ($last_table.docid=vf$i.docid AND $last_table.version=vf$i.version AND vf$i.name='$_')");
        } else {
            push(@table,   "vfields AS vf$i");
            push(@join,  "(versions.docid=vf$i.docid AND versions.version=vf$i.version)");
            push(@where,   "vf$i.name='$_'");
        }

        if($fspec->FieldType->param('validate') eq 'xref' and $fspec->FieldType->param('search') eq 'matchColumn') {
            my ($xref_table, $xref_column) = split(/\./, $fspec->FieldType->param('validate_args'));
            my $search_arg = $fspec->FieldType->param('search_args');

            if($do_left_join) {
                push(@left_join_table, "LEFT JOIN $xref_table AS xref$xrefs ON (xref$xrefs.$xref_column = vf$i.${field}_value)");
            } else {
                # Add the table we want to join
                push(@table, "$xref_table as xref$xrefs");

                #make sure we get the right stuff
                push(@join, "(xref$xrefs.$xref_column = vf$i.${field}_value)");
            }

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

    # XXX This is still problematic, if someone searches for
    #     %fieldnamewhatever%, 'fieldnamewhatever' or
    #     "fieldnamewhatever":
    my $regex = '(^|[^\w])(' . join('|', map { quotemeta($_) } sort { length($b)<=>length($a) } keys %map) . ')';
    $where =~ s/$regex/$1 . $map{$2}/gie;

    my $set = DBIx::Recordset->SetupObject({'!DataSource'   => $this->{DB},
                                            '!Table'        => join(', ', @table) . " " . join(" ", @left_join_table),
                                            '!TabRelation'  => join(' AND ', @join),
                                            '!Fields'       => join(', ', @fields),
#                                           '!Debug'            => 2,
                                        });

    $having = ($having ? " HAVING $having" : '');

    my $query = {
                    '$where'    => join(' AND ', @where, "($where)"),
                    '$group'    => "versions.docid, versions.version, versions.lang $having",
                };

    $query->{'$order'}=join(', ', @$order) if (defined $order and @$order);
    $query->{'$order'}=~ s/$regex/$1 . $map{$2}/gie if ($query->{'$order'});

    $options{order} =~ s/$regex/$1 . $map{$2}/gie if ($options{order});
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

# same as search but does WHERE doc.parent IN ( get_documents_subtree ) for
# searching in a subtree; also searches in the root document itself.
# $root_id is either a document id, or an array of document ids.
sub search_subtree
{
        my ( $self, $root_docid, $fields, $where, %options) = @_;

        my @root_docids =
                ( ref( $root_docid) and ref( $root_docid) eq 'ARRAY') ?
                        @$root_docid :
                        ( $root_docid || 0);

        @root_docids = (0) unless @root_docids;

        if ( grep { $_ == 0 or $_ == 1 } @root_docids ) {
                # search in all documents
                return $self-> search( $fields, $where, %options);
        }


        my @parents = sort { $a <=> $b } $self-> get_documents_subtree( @root_docids);
        my $result = [];
        my @user_where_statement = length($where) ? ($where) : ();

        # add doc fields needed
        $options{needs_document_fields} ||= [];
        @{$options{needs_document_fields}} = grep {
                $_ ne 'id' and $_ ne 'parent'
        } @{$options{needs_document_fields}};
        push @{$options{needs_document_fields}}, qw(id parent);

        do {
                my $max = 256 - @root_docids;  # XXX approx max query length is 2K
                $max = 0 if $max < 0;
                my @slice = splice( @parents, 0, $max);

                my @where;
                push @where, 'parent IN (' . join(',', @slice) . ')'
                        if @slice;
                if ( @root_docids) {
                        push @where, 'id IN (' . join(',', @root_docids) . ')';
                        @root_docids = ();
                }

                @where = ( '(' . join( ' OR ', @where) . ')' ) if @where;

                push @$result, @{$self-> search(
                        $fields,
                        join( ' AND ', @user_where_statement, @where),
                        %options
                ) || []};

        } while (@parents);

        $result;
}

# traverses root_docid and returns set of parent ids for all documents ids under the root
sub get_documents_subtree
{
        my ( $self, @root_docids) = @_;

        @root_docids = (0) unless @root_docids;
        my $set = DBIx::Recordset-> SetupObject({
                '!DataSource'   => $self-> {DB},
                '!Table'        => 'documents',
                '!Fields'       => 'id,parent'
        });

        my ( %result, @current, %seen);
        @current = @root_docids;

        while ( @current) {
                my @slice = splice( @current, 0, 256); # XXX approx max query length is 2K

                $set-> Search({
                        '$where'        => 'parent IN (' . join(',', @slice) . ')',
                });

                while ( my $rec = $set-> Next) {
                        next if $seen{ $rec->{id} };
                        $seen{ $rec->{id} } = 1;
                        $result{ $rec->{parent} } = 1;
                        push @current, $rec->{id} ;
                }
        }

        $set-> Disconnect;

        keys %result;
}

sub get_distinct_vfields {
    my ($this, $name, $value_field, %options) = @_;

    $this->tracer($name, $value_field) if ($this->{DEBUG});

    $value_field = $value_field . "_value";

    my $tables = 'versions, vfields';

    my $where = "versions.docid = vfields.docid AND versions.version = vfields.version";
    if($options{doctypeid}) {
        $where .= " AND versions.type = " . $options{doctypeid};
    }
    if($options{lang}) {
        $where .= " AND versions.lang = '" . $options{lang} . "'";
    }
    $where .= " AND versions.public = 1 AND vfields.name = '$name'";

    # Handle a matching vfield
    if(my $vf = $options{vfields_match}) {
        if($vf->{name} and $vf->{type} and $vf->{value}) {
            $tables .= ", vfields as vf_match";
            $where .= " AND versions.docid = vf_match.docid AND versions.version = vf_match.version";
            $where .= " AND vf_match." . $vf->{type} . "_value = '" . $vf->{value} . "'";
        }
    }

    my $order;
    if($options{sortrecent}) {
        $order = 'versions.version DESC';
    } elsif($options{sortreverse}) {
        $order = 'vfields.' . $value_field . " DESC";
    } else {
        $order = "vfields." . $value_field;
    }

    my $set=DBIx::Recordset->SetupObject( {'!DataSource'=>$this->{DB},
                                            '!Table'     =>$tables,
                                            '!Order'     =>$order,
                                            '!Fields'    =>"DISTINCT vfields.$value_field",
                                        } );

    $set->Search($where);

    my $rec;
    my @data;

    while($rec=$set->Next) {
        push(@data, $rec->{$value_field}) if($rec->{$value_field});
    }
    $set->Disconnect;
    return \@data;

}



########################################################################
#
#       Methods to get fields of versions
#
########################################################################

sub get_version_fields_by_threshold {
    my ($this, $version, $threshold, $type) = @_;
    $type=(defined $type ? $type : 'FIELDS');

#    print STDERR "entering";
    $this->tracer($version, $threshold||'N/A', $type) if ($this->{DEBUG});

    my $doctype = $this->get_version_type($version);
    my @fields;

    if(ref $threshold) {
        @fields = grep { defined $doctype->field($_, undef, $type) } @$threshold;
    } else {
        $threshold = 0 unless (defined $threshold and $threshold >= 0);
        $threshold = 255 if ($threshold > 255);

        @fields = grep {
            $doctype->field($_, undef, $type)->Threshold <= $threshold
        } @{$doctype->fields_names($type)};
    }
    #local $, = ',';
    #$this->{LOG}->debug("First list of fields: @fields");

    if (my $fields = $version->fields($type)) {
        @fields = grep { not $fields->exists($_) } @fields;
    }
    #$this->{LOG}->debug("Second list of fields: @fields");

#    print STDERR "exiting";
    return @fields ? \@fields : undef;
}

sub get_version_fields {
    my ($this, $version, $threshold, $type) = @_;
#    print STDERR "Entering get_version_fields";

    $type=(defined $type ? $type : 'FIELDS');

    $this->tracer($version, $threshold||'N/A', $type) if ($this->{DEBUG});

    my $needed = $this->get_version_fields_by_threshold($version, $threshold, $type);
    return $version->fields($type) unless ($needed);

    my $fields = new Obvius::Data;
    my $doctype = $this->get_version_type($version);

    for (@$needed) {
        my $fspec = $doctype->field($_, undef, $type);
#        print STDERR "VFIELD FROM TYPE $_ (threshold $fspec->{THRESHOLD})\n";
        if ($fspec->Repeatable) {
            $fields->param($_ => []);
        } else {
            $fields->param($_ => $fspec->param('default_value'));
        }
    }

    my $set = DBIx::Recordset->SetupObject({'!DataSource'=>$this->{DB},
                                            '!Table'     =>'vfields',
                                           });

#    printf STDERR " get_version_fields %5d %s", $version->Docid, $version->Version;
#    print STDERR " ", (join ", ", @$needed), "\n";

    $set->Search({docid      => $version->Docid,
                  version    => $version->Version,
                  name       => $needed,
                  '$fields'  => 'name, text_value, int_value, double_value, date_value',
                 });
    while (my $rec = $set->Next) {
        my $fspec = $doctype->field($rec->{name}, undef, $type);
        next unless ($fspec);
        my $field = $fspec->param('fieldtype')->param('value_field') . '_value';
#        print STDERR "VFIELD FROM DB $rec->{name} = $field (threshold $fspec->{THRESHOLD})\n";

        my $value = $fields->param($rec->{name});
        # Apparantly the db returns -1.0 as -1, which is not what we want:
        my $field_value = $rec->{$field};
        $field_value=sprintf "%1.1f", $field_value if ($field eq 'double_value' and
                                                        defined $field_value and $field_value eq '-1');
        if ((ref $value || '') eq 'ARRAY') {
            push(@$value, $field_value);
        } else {
            $fields->param($rec->{name} => $field_value);
        }
    }
    $set->Disconnect;

#    print STDERR Dumper($fields);

    for (@$needed) {
#        print STDERR "VFIELD STORE $_\n";
        my $fspec = $doctype->field($_, undef, $type);
        my $ftype = $fspec->param('fieldtype');

        my $value;
        if ($fspec->Repeatable) {
            $value = [
                      grep {
                          defined $_
                      } map {
                          $ftype->copy_in($this, $fspec, $_)
                      } @{$fields->param($_)}
                     ];
        } else {
            $value = $ftype->copy_in($this, $fspec, $fields->param($_));
        }
        # $value='' unless (defined $value); # This is questionable...?
        # 20020112 asjo Indeeeeeed so. It messes up prepare_edit so that empty fields becomes ''
        # become 0! But does changing this break all sorts of other things? XXX MUST TEST!
        $version->field($_ => $value, $type);
    }

    # print STDERR Dumper($version->fields($type));
#    print STDERR "Exiting same";

    return $version->fields($type);
}

# get_version_field - given a version object, a string with a
#                     fieldname and optionally a type, gets the field
#                     and returns the value, if present. Returns undef
#                     on failure.
sub get_version_field {
    my ($this, $version, $name, $type) = @_;

    $this->tracer($version, $name) if ($this->{DEBUG});

    my $fields = $this->get_version_fields($version, [ $name ], $type);
    return $fields ? $fields->param($name) : undef;
}



########################################################################
#
#       Look up document and field types
#
########################################################################

sub get_document_type {
    my ($this, $doc) = @_;
    #$this->tracer($doc) if ($this->{DEBUG});
    return $this->get_doctype($doc->_type);
}

# get_version_type - given a version object, returns the
#                    doctype-object corresponding to the type of the
#                    version.
sub get_version_type {
    my ($this, $version) = @_;
    #$this->tracer($version) if ($this->{DEBUG});
    croak "get_version_type called without a version-object"
        unless (ref $version eq 'Obvius::Version');

    return $this->get_doctype($version->_type);
}

sub get_doctype {
    my ($this, $id) = @_;
    #$this->tracer($id) if ($this->{DEBUG});
    return $this->{DOCTYPES}->[$id];
}

sub get_doctype_by_id {
    my ($this, $id) = @_;
    #$this->tracer($id) if ($this->{DEBUG});
    return $this->{DOCTYPES}->[$id];
}

sub get_doctype_by_name {
    my ($this, $name) = @_;
    return undef unless($name);
    $this->tracer($name) if ($this->{DEBUG});
    for (@{$this->{DOCTYPES}}) {
        return $_ if ($_ and $_->param('name') eq $name);
    }
    return undef;
}

sub set_doctype {
    my ($this, $id, $type) = @_;
    #$this->tracer($type) if ($this->{DEBUG});
    return $this->{DOCTYPES}->[$id] = $type;
}

sub get_fieldtype {
    my ($this, $type) = @_;
    #$this->tracer($type) if ($this->{DEBUG});
    return $this->{FIELDTYPES}->[$type];
}

sub get_fieldtype_by_name {
    my ($this, $name) = @_;

    foreach (@{$this->{FIELDTYPES}}) {
        return $_ if (defined $_ and $name eq $_->param('name'));
    }
    return undef;
}

sub set_fieldtype {
    my ($this, $id, $type) = @_;
    #$this->tracer($id, $type) if ($this->{DEBUG});
    return $this->{FIELDTYPES}->[$id] = $type;
}

# get_fieldspec - given a string with the name of a field and a
#                 doctype object, returns the related fieldspec
#                 object, if one exists. Returns undef on failure.
sub get_fieldspec {
    my ($this, $name, $doctype) = @_;
    #$this->tracer($name) if ($this->{DEBUG});

    return undef unless (defined $this->{FIELDSPECS}->param($name));

    if (defined $doctype) {
        return $this->{FIELDSPECS}->param($name)->param($doctype->Id);
    }
    else {
        foreach ($this->{FIELDSPECS}->param($name)->param) {
            return $this->{FIELDSPECS}->param($name)->param($_);
        }
        # croak "Couldn't find fieldspec $name!";
    }

    return undef;
}

sub set_fieldspec {
    my ($this, $name, $doctypeid, $fspec) = @_;
    #$this->tracer($name, $fspec) if ($this->{DEBUG});
    my $t;
    unless ($t=$this->{FIELDSPECS}->param($name)) {
        $t=new Obvius::Data;
        $this->{FIELDSPECS}->param($name => $t);
    }

    $t->param($doctypeid=>$fspec);
}



########################################################################
#
#       Document parameters
#
########################################################################

sub get_docparams_by {
    my ($this, @how) = @_;

    $this->tracer(@how) if($this->{DEBUG});
    my $set = DBIx::Recordset->SetupObject ({'!DataSource' => $this->{DB},
                                            '!Table'      => 'docparms',
                                            });
    $set->Search({@how});

    my $docparams = new Obvius::Data;

    while(my $rec = $set->Next) {
        $docparams->param($rec->{name} => new Obvius::Data($rec));
    }
    $set->Disconnect;

    return $docparams;

}

# Get all parameters as hash of hash
sub get_docparams {
    my ($this, $doc) = @_;

    $this->tracer($doc) if ($this->{DEBUG});

    return $doc->param('docparams') if (defined $doc->param('docparams'));

    my $docparams = $this->get_docparams_by(docid => $doc->Id);

    $doc->param(docparams => $docparams);
    return $docparams;
}

# Get one parameter as hash
sub get_docparam {
    my ($this, $doc, $name) = @_;

    $this->tracer($doc, $name) if ($this->{DEBUG});

    my $parms = $this->get_docparams($doc);
    return undef unless ($parms);

    return $parms->param($name);
}

# Get one parameter as value
sub get_docparam_value {
    my ($this, $doc, $name) = @_;

    $this->tracer($doc, $name) if ($this->{DEBUG});

    my $param = $this->get_docparam($doc, $name);
    return $param ? $param->param('value') : undef;
}

sub get_docparam_recursive {
    my ($this, $doc, $name) = @_;

    $this->tracer($doc, $name) if ($this->{DEBUG});

    do {
        my $param = $this->get_docparam($doc, $name);
        return $param if (defined $param);

        my $parent = $doc->param('parent');
        $doc = $parent ? $this->get_doc_by_id($parent) : undef;
    } while ($doc);

    return undef;
}

sub get_docparam_value_recursive {
    my ($this, $doc, $name) = @_;

    $this->tracer($doc, $name) if ($this->{DEBUG});

    my $param = $this->get_docparam_recursive($doc, $name);
    return $param ? $param->param('value') : undef;
}

# Gets all docparams on the path collected as one hash.
sub get_docparams_recursive {
    my ($this, $doc) = @_;

    my @paramslist;

    do {
        my $params = $this->get_docparams($doc);
        unshift(@paramslist, $params);
        my $parent = $doc->param('parent');
        $doc = $parent ? $this->get_doc_by_id($parent) : undef;
    } while ($doc);

    my $result = new Obvius::Data;

    for my $paramset (@paramslist) {
        for($paramset->param) {
            $result->param($_ => $paramset->param($_));
        }
    }

    return $result;
}

# Setting docparams
sub set_docparams {
    my ($this, $doc, $params, $errorref) = @_;

    unless($this->can_set_docparams($doc)) {
        $$errorref = "User $this->{USER} does not have access to set docparams for this document" if($errorref);
        return undef;
    }

    $this->db_begin;
    eval {
        die "Params object has no param() method\n"
            unless (ref $params and $params->UNIVERSAL::can('param'));

        $this->{LOG}->info("====> Setting docparams ... deleting old");
        $this->db_delete_docparams($doc);
        $this->{LOG}->info("====> Setting docparams ... inserting new");
        $this->db_insert_docparams($doc, $params);
	$this->db_commit;
    };
    
    if($@) {
        $this->{DB_Error} = $@;
        $this->db_rollback;
        $this->{LOG}->error("====> Setting docparams ... failed ($@)");
        $$errorref = $@ if($errorref);
        return undef;
    }

    $this->register_modified('docid' => $doc->Id, clear_recursively => 1);
    undef $this->{DB_Error};
    $this->{LOG}->info("====> Setting docparams ... done");
    return 1;

}



########################################################################
#
#       Read and validate all info about doctypes, fieldtypes etc.
#
########################################################################

sub breadth_first {
    my ($tree)=@_;

    my @list=();
    my @process=qw(0);
    my $num;
    while (defined ($num=shift @process)) {
        map { push @process, $_->{id} } @{$tree->{$num}->{children}};
        push @list, $tree->{$num};
    }
    return @list;
}

sub read_doctypes_table {
    my ($this, $make_objects) = @_;

    $this->tracer($make_objects) if ($this->{DEBUG});

    my $set = DBIx::Recordset->SetupObject({ '!DataSource' => $this->{DB},
                                             '!Table'      => 'doctypes',
                                           } );
    $set->Search;
    my %tree=(0=>{id=>0, name=>'META_ROOT'});
    while (my $rec = $set->Next()) {
        my $new=$tree{$rec->{id}} || {};
        map { $new->{$_}=$rec->{$_} } keys(%$rec);
        $new->{children}=[] unless (exists $new->{children});
        $tree{$rec->{id}}=$new unless (exists $tree{$rec->{id}});

        my $parent=$tree{$rec->{parent}} || {};
        $parent->{children}=[] unless (exists $parent->{children});
        push @{$parent->{children}}, $new;
        $tree{$rec->{parent}}=$parent unless (exists $tree{$rec->{parent}});
    }
    my @doctypelist=breadth_first(\%tree);
    shift @doctypelist; # Remove the META_ROOT

    while (my $rec=shift @doctypelist) {
        #$this->log->debug("DocType $rec->{name}/$rec->{id}");

        # Try each doctype in this order:
        #  websiteperlname::DocType::Name
        #  XTRA_TYPES::DocType::Name
        #  MCMS::DocType::Name

        my @types = ( "Obvius::DocType::$rec->{name}" );
        unshift(@types, "$this->{XTRA_TYPES}::DocType::$rec->{name}")
            if ($this->{XTRA_TYPES});
        unshift (@types, $this->config->param('perlname') . "::DocType::$rec->{name}")
            if ($this->config->param('perlname'));

        my $doctype;
        my $tester;
        my $ev_error='';
        for (@types) {
            #$this->log->debug("TESTING $_");

            no strict 'refs';
            $tester = "${_}::VERSION";
            if (defined $$tester) {
                #$this->log->debug("FOUND $_ SUCCESS");
                $doctype = $_;
                last;
            } else {
                #$this->log->debug("LOADING $_");

                eval "use $_";
                $ev_error=$@;

                if ( $@) {
                        # test if this is because a module cannot be found, or something more serious
                        my $fn = $_;
                        $fn =~ s/::/\//g;
                        croak "$_:$@" if $@ !~ /^Can't locate $fn.pm in \@INC/; #'
                }

                if (defined $$tester) {
                    #$this->log->debug("LOADING $_ SUCCESS");
                    $doctype = $_;
                    last;
                }
            }
        }
        # If neither the doctype itself nor the XTRA_TYPES could be found, try the parent:
        # For this to work, we need to handle parents before children:
        unless (defined $$tester) {
            my $parentdoctype=$this->get_doctype_by_id($rec->{parent}) || $rec;
            my $doctypename="Obvius::DocType::$rec->{name}";
            my $parenttypename=ref $parentdoctype;
            $this->log->debug("FALLING BACK TO PARENT $parenttypename");
            my $r=eval "package $doctypename;
                        our \@ISA = ('$parenttypename');
                        our \$VERSION = '0.0.0.0';
                        1;
                        ";
            if (defined $r) {
                $doctype=$doctypename;
            }
            else {
                $this->log->warn(" FALLBACK FAILED: $ev_error");
            }
        }

        if (defined $doctype) {
            if ($make_objects) {
                #$this->log->debug("INSTANTIATING $doctype");
                my $object = $doctype->new($rec);
                $object->param(debug => $this->{DEBUG});
                $this->set_doctype($rec->{id} => $object);
            }
        } else {
            croak "Failed to resolve $rec->{name}\n";
        }
    }
    $set->Disconnect;
}

sub read_fieldtypes_table {
    my ($this, $make_objects) = @_;

    $this->tracer($make_objects) if ($this->{DEBUG});

    my $set = DBIx::Recordset->SetupObject({ '!DataSource' => $this->{DB},
                                             '!Table'      => 'fieldtypes',
                                           } );
    $set->Search;
    while (my $rec = $set->Next()) {
        #print STDERR "FieldType $rec->{name}\n" if ($this->{DEBUG});
        $this->{FIELDTYPES}->[$rec->{id}] = new Obvius::FieldType($rec);
    }
    $set->Disconnect;

    #print STDERR "Fieldtypes: ", Dumper($this->{FIELDTYPES});
}

# read_fieldspecs_table - reads the fieldspecs from the database,
#                         creates objects and plugs them into the
#                         fieldtypes- and doctypes-objects. The
#                         argument make_objects isn't used. Doesn't
#                         return anything. Used internally by
#                         read_type_info().
sub read_fieldspecs_table {
    my ($this, $make_objects) = @_;

    $this->tracer($make_objects) if ($this->{DEBUG});

    my $set = DBIx::Recordset->SetupObject( { '!DataSource' => $this->{DB},
                                              '!Table'      => 'fieldspecs',
                                            } );
    $set->Search;
    while (my $rec = $set->Next()) {
        #print STDERR "FieldSpec $rec->{name}/$rec->{doctypeid} Publish $rec->{publish}\n";
        #    if ($this->{DEBUG});

        croak "Document type $rec->{doctypeid} for fieldspec $rec->{name} not known"
            unless (defined $this->get_doctype($rec->{doctypeid}));
        croak "Field type $rec->{type} for fieldspec $rec->{name}/$rec->{doctypeid} not known"
            unless (defined $this->get_fieldtype($rec->{type}));

        my $fs = new Obvius::FieldSpec($rec);
        $fs->param(fieldtype => $this->get_fieldtype($rec->{type}));
        $this->set_fieldspec($rec->{name}, $rec->{doctypeid}, $fs);

        my $doctype = $this->get_doctype($rec->{doctypeid});
        if ($rec->{publish}) {
            $doctype->publish_field($rec->{name} => $fs);
        } else {
            $doctype->field($rec->{name} => $fs);
        }
    }
    $set->Disconnect;
}

# adjust_doctype_hierarchy - after the doctypes are read from the
#                            database, this function takes care of the
#                            inheritance of fields (normal and
#                            publish) and also of the setting of
#                            sortorder_field_is.
#                            This is done after all doctypes are read
#                            from the database and all the objects
#                            have been created, because doctypes can
#                            inherit from eachother, and they are not
#                            necessarily read parent-first from the
#                            database.
#                            This function is internal, used by
#                            read_type_info only.
sub adjust_doctype_hierarchy {
    my ($this) = @_;

    for my $doctype (@{$this->{DOCTYPES}}) {
        next unless $doctype;
        #print STDERR "Copying to $doctype->{NAME}\n" if ($this->{DEBUG});

        my $ancestor = $this->get_doctype($doctype->Parent);
        while ($ancestor) {
            #print STDERR "\tfrom $ancestor->{NAME}\n" if ($this->{DEBUG});
            # sortorder_field_is is also inherited:
            $doctype->param('sortorder_field_is'=>$ancestor->param('sortorder_field_is'))
                unless ($doctype->param('sortorder_field_is'));
            for ($ancestor->field) {
                #print STDERR "\t\tfield $_\n" if ($this->{DEBUG});

                my $af = $ancestor->field($_);
                my $df = $doctype->field($_);

                my $overwrite=0;
                if (defined $df) {
                    if ($af->Fieldtype->Value_field ne $df->Fieldtype->Value_field) {
                        warn "The value_fields of $_ in $doctype and it's ancestor DO NOT MATCH!\n";
                        $overwrite=1;
                    }
                }

                if (!defined $df or $overwrite) {
                    $this->log->warn("OVERWRITING $_ in $doctype!") if (defined $df and $af->_doctypeid != $df->_doctypeid);
                    $doctype->field($_ => $ancestor->field($_));
                    if (my $fspec=$this->get_fieldspec($_, $ancestor)) {
                        $this->set_fieldspec($_, $doctype->Id, $fspec);
                    }
                }
            }
            for ($ancestor->publish_field) {
                #print STDERR "\t\tpublish_field $_\n" if ($this->{DEBUG});

                my $af = $ancestor->publish_field($_);
                my $df = $doctype->publish_field($_);

                my $overwrite=0;
                if (defined $df) {
                    if ($af->Fieldtype->Value_field ne $df->Fieldtype->Value_field) {
                        warn "The value_fields of $_ in $doctype and it's ancestor DO NOT MATCH!\n";
                        $overwrite=1;
                    }
                }

                if (!defined $df or $overwrite) {
                    $this->log->warn("OVERWRITING $_") if (defined $df and $af->_doctypeid != $df->_doctypeid);
                    $doctype->publish_field($_ => $ancestor->publish_field($_));
                    if (my $fspec=$this->get_fieldspec($_, $ancestor)) {
                        $this->set_fieldspec($_, $doctype->Id, $fspec);
                    }
                }

            }
            $ancestor = $this->get_doctype($ancestor->Parent);
        }
    }
}

sub read_type_info {
    my ($this, $make_objects) = @_;

    $this->tracer() if ($this->{DEBUG});
    
    $this->read_doctypes_table($make_objects);
    $this->read_fieldtypes_table($make_objects);
    $this->read_fieldspecs_table($make_objects);
    $this->adjust_doctype_hierarchy();

    #print STDERR Dumper($this->{DOCTYPES}) if ($this->{DEBUG});
}



########################################################################
#
#       Create a new document or a new version.
#
########################################################################

sub create_new_document {               # RS 20010819 - ok
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
	
	$name = lc $name; # Make sure name is lowercased.
        die "Document name is malformed\n" unless ($name and $name =~ /^[a-zA-Z0-9._-]+$/);

        my $newdoc = $this->get_doc_by_name_parent($name, $parent->param('id'));
        die "Document already exists\n" if ($newdoc);

        my $doctype = $this->get_doctype_by_id($type);
        die "Document type does not exist\n" unless ($doctype);

        if($doctype->UNIVERSAL::can('create_new_version_handler')) {
            my $retval = $doctype->create_new_version_handler($fields, $this);
            die "Doctype specific new_version handler failed\n" unless($retval == OBVIUS_OK);
        }

        die "Language code invalid: $lang\n" unless ($lang and $lang =~ /^\w\w(_\w\w)?$/);

        die "Fields object has no param() method\n"
            unless (ref $fields and $fields->UNIVERSAL::can('param'));

        my %status = $doctype->validate_fields($fields, $this);
        $this->{LOG}->notice("Invalid fields stored anyway: @{$status{invalid}}\n") if ($status{invalid});
        $this->{LOG}->info("Missing fields stored undef: @{$status{missing}}\n") if ($status{missing});
        $this->{LOG}->info("Excess fields not stored: @{$status{excess}}\n") if ($status{excess});

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

    my $ev_error=$@;
    if ($ev_error) {                    # handle error
        my $error_msg = $ev_error;
        ($error_msg) = ($error_msg =~ m/^(.*?)\n/) if $error_msg;
        $this->{DB_Error} = $error_msg;
        $this->db_rollback;
        $this->{LOG}->error("====> Inserting new document ... failed ($error_msg)");
        $$error = $error_msg if ($error_msg and defined($error));
        return wantarray ? () : undef;
    }

    undef $this->{DB_Error};
    $this->{LOG}->info("====> Inserting new document ... done");
    $this->register_modified(docid => $docid);
    $this->register_modified(admin_leftmenu => [$parent->Id]);
    return wantarray ? ($docid, $version) : [$docid, $version];
}

sub create_new_version {
    my ($this, $doc, $type, $lang, $fields) = @_;

    die "User $this->{USER} does not have access to edit the document."
        unless $this->can_create_new_version($doc);

    # Procedure:
    # validate, insert version, insert fields, end.

    # Doctype specific handler will be called after having validated
    # the doctype.

    my $version;

    $this->db_begin;
    eval {
        die "Document object is not an Obvius::Document\n"
            unless (ref $doc and $doc->UNIVERSAL::isa('Obvius::Document'));

        my $docid = $doc->param('id');
        die "Document id is invalid\n"
            unless (defined $docid and $docid =~ /^\d+$/ and $docid > 0);

        my $doctype = $this->get_doctype_by_id($type);
        die "Document type does not exist\n" unless ($doctype);

        if($doctype->UNIVERSAL::can('create_new_version_handler')) {
            my $retval = $doctype->create_new_version_handler($fields, $this);
            die "Doctype specific new_version handler failed" unless($retval == OBVIUS_OK);
        }

        die "Language code invalid: $lang\n" unless ($lang and $lang =~ /^\w\w(_\w\w)?$/);

        die "Fields object has no param() method\n"
            unless (ref $fields and $fields->UNIVERSAL::can('param'));

        my %status = $doctype->validate_fields($fields, $this);
        $this->{LOG}->notice("Invalid fields stored anyway: @{$status{invalid}}\n") if ($status{invalid});
        $this->{LOG}->info("Missing fields stored undef: @{$status{missing}}\n") if ($status{missing});
        $this->{LOG}->info("Excess fields not stored: @{$status{excess}}\n") if ($status{excess});

        my @fields = @{$status{valid}};
        # Equivalent to new_document:
        push @fields, @{$status{invalid}}
            if ($status{invalid});
        # This is necessary for searching; missing fields has to be in the database,
        # but with the undef/NULL value.
        push @fields, @{$status{missing}}
            if ($status{missing});

        $this->{LOG}->info("====> Inserting new version ... insert into versions");
        $version = $this->db_insert_version($docid, $type, $lang);

        $this->{LOG}->info("====> Inserting new version ... insert into vfields");
        $this->db_insert_vfields($docid, $version, $fields, \@fields);

        $this->{LOG}->info("====> Inserting new version ... COMMIT");
        $this->db_commit;
    };

    my $ev_error=$@;
    if ($ev_error) {                    # handle error
        $this->{DB_Error} = $ev_error;
        $this->db_rollback;
        $this->{LOG}->error("====> Inserting new version ... failed ($ev_error)");
        return undef;
    }

    undef $this->{DB_Error};
    $this->{LOG}->info("====> Inserting new version ... done");
    
    $this->register_modified(admin_leftmenu => [$doc->Id, $doc->Parent])  
      if (cache_new_version_p($this, $doc->Id, $lang));

    $this->register_modified( docid => $doc->Id);
    return $version;
}



########################################################################
#
#       Delete a document, rename a document
#
########################################################################

sub delete_document {
    my ($this, $doc) = @_;

    die "User $this->{USER} does not have access to delete the document."
        unless $this->can_delete_document($doc);

    my $docid = $doc->Id;
    my $doctype = $doc->type;
    my $doc_uri=$this->get_doc_uri($doc);
    my $doc_parent_id=$doc->Parent;
    
    $this->db_begin;
    eval {
        die "Document has sub documents\n"
            if ($this->get_docs_by_parent($doc->Id));

        $this->{LOG}->info("====> Deleting fields ... delete from vfields");
        $this->db_delete_vfields($doc->Id);
        $this->{LOG}->info("====> Deleting versions ... delete from versions");
        $this->db_delete_versions($doc->Id);

        # We could delete docparms as well:

        #  print STDERR "====> Deleting document ... delete from docparms\n";
        #  $this->db_delete_docparms($doc->Id);

        # We could delete voters and votes as well:

        #  print STDERR "====> Deleting document ... delete from voters\n";
        #  $this->db_delete_voters($doc->Id);
        #  print STDERR "====> Deleting document ... delete from votes\n";
        #  $this->db_delete_votes($doc->Id);

        $this->{LOG}->info("====> Deleting document ... delete from subscriptions");
        $this->db_delete_subscriptions($doc->Id);

        $this->{LOG}->info("====> Deleting document ... delete from comments");
        $this->db_delete_comments($doc->Id);

        $this->{LOG}->info("====> Deleting document ... delete from document");
        $this->db_delete_document($doc->Id);

        $this->{LOG}->info("====> Deleting document ... COMMIT");
        $this->db_commit;
    };

    my $ev_error=$@;
    if ($ev_error) {                    # handle error
        $this->{DB_Error} = $ev_error;
        $this->db_rollback;
        $this->{LOG}->error("====> Deleting document ... failed ($ev_error)");
        return undef;
    }

    undef $this->{DB_Error};
    $this->{LOG}->info("====> Deleting document ... done");
    # The document doesn't exist any more, so we say the uri of it is
    # modified, and its parent:
    $this->register_modified(uri  => $doc_uri, docid => $docid, clear_leftmenu => 1, doctype => $doctype);
    $this->register_modified(docid => $doc_parent_id, clear_leftmenu => 1);
    $this->register_modified(admin_leftmenu => [$docid, $doc_parent_id]);
    return 1;
}

sub rename_document {
    my ($this, $doc, $new_uri, $errmsg) = @_;

    unless ($this->can_rename_document($doc)) {
        $$errmsg = 'User $this->{USER} does not have access to rename/move the document.' if(defined $errmsg);
    }

    die "User $this->{USER} does not have access to rename/move the document."
        unless $this->can_rename_document($doc);

    $new_uri =~ s/[.]html?$//;
    return undef unless ($new_uri);

    # Split path from name:
    my @new_path=grep {defined $_ and $_ ne ''} split m!/!, $new_uri;
    foreach (@new_path) {
        unless (/^[a-zA-Z0-9._-]+$/) {
            $$errmsg = 'Bad characters in name' if(defined $errmsg);
            $this->log->warn("Bad characters in name");
            return undef;
        }
    }
    my $new_name=pop @new_path;
    my $new_path='/' . join '/', @new_path;

    my $old_uri=$this->get_doc_uri($doc);
    my $old_parent_id=$doc->Parent;

    # Find the new parent:
    my $new_parent=$this->lookup_document($new_path);
    unless ($new_parent) {
        $$errmsg = 'Parent does not exist' if(defined $errmsg);
        warn "Parent does not exist";
        return undef;
    }
    unless ($this->can_rename_document_create($new_parent)) {
        $$errmsg = 'You do not have access to move the document to this location.' if(defined $errmsg);
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
            $$errmsg = "It is not possible to move the document under itself" if(defined $errmsg);
            $this->log->warn("It is not possible to move the document under itself");
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

    my $ev_error=$@;
    if ($ev_error) {                    # handle error
        $this->{DB_Error} = $ev_error;
        $this->db_rollback;
        $this->{LOG}->error("====> Renaming/moving document ... failed ($ev_error)");
        return undef;
    }

    undef $this->{DB_Error};
    $this->register_modified(uri   => $old_uri, clear_leftmenu => 1);
    $this->register_modified(admin_leftmenu => [$old_parent_id, $new_parent->Id, $doc->Id]);

    $this->{LOG}->info("====> Renaming/moving document ... done");
    return 1;
}


########################################################################
#
#       Publish and unpublish versions
#
########################################################################

# Delayed publishing sets the publish fields but does not change the public flag.
# It removes the PUBLISHED field from the list of fields to publish."

sub publish_version {
    my ($this, $vdoc, $error, $delayed_publish) = @_;

    die "User $this->{USER} does not have access to publish the document."
        unless $this->can_publish_version($vdoc);
    
    if($delayed_publish) {
        delete $vdoc->{PUBLISH_FIELDS}->{PUBLISHED};
    }

    # Procedure:
    # validate, update version, insert pfields, end.
    #For the leftmenu cache, check if any
    
    my $related = is_relevant_for_leftmenu_cache($this, $vdoc->Docid, $vdoc);

    $this->db_begin;
    eval {
        my $doctype = $this->get_version_type($vdoc);
        die "Version document type does not exist\n" unless ($doctype);

        my %status = $doctype->validate_publish_fields($vdoc->publish_fields, $this);

        # published is not missing if we are doing a delayed publish.
        if($delayed_publish) {
            my @missing_fields = @{$status{missing} || []};
            @missing_fields = grep {$_ ne 'PUBLISHED'} @missing_fields;
            if(scalar(@missing_fields)) {
                $status{missing} = \@missing_fields;
            } else {
                delete $status{missing};
            }
        }

        die "Missing publish fields: @{$status{missing}}\n" if ($status{missing});
        die "Invalid publish fields: @{$status{invalid}}\n" if ($status{invalid});
        #warn "Excess fields not stored: @{$status{excess}}\n" if ($status{excess});

        my @fields = @{$status{valid}};

        unless($delayed_publish) {
            $this->{LOG}->info("====> Publishing version ... mark public");
            $this->db_update_version_mark_public($vdoc);
        }

        $this->{LOG}->info("====> Publishing version ... publish fields");
        $this->db_insert_vfields($vdoc->DocId, $vdoc->Version, $vdoc->publish_fields, \@fields);

        $this->{LOG}->info("====> Publishing version ... COMMIT");
        $this->db_commit;
    };

    my $ev_error=$@;
    if ($ev_error) {                    # handle error
        $this->{DB_Error} = $ev_error;
        $this->db_rollback;
        $this->{LOG}->error("====> Publishing version ... failed ($ev_error)");
        $$error = chomp $ev_error if (defined($error));

        return undef;
    }

    undef $this->{DB_Error};
    $this->{LOG}->info("====> Publishing version ... done"); 
    $this->register_modified(docid=>$vdoc->Docid, clear_leftmenu => $related);
    if ($related) {
	 my $doc = $this->get_doc_by_id($vdoc->Docid);
	 $this->register_modified(admin_leftmenu => [$doc->Id, $doc->Parent]);
    }

    if($delayed_publish) {
        $this->{LOG}->info("====> Setting 'at' autopublishing job...");

        my $publish_on = $vdoc->{PUBLISH_FIELDS}->{PUBLISH_ON};
        my ($year, $month, $day, $hour, $min) = ($publish_on =~ /^\d\d(\d\d)-(\d\d)-(\d\d) (\d\d):(\d\d)/);
        my $site = $this->{OBVIUS_CONFIG}->{NAME};


        my $command =
                "echo perl -w " .
                $this->config->param('prefix') .
                "/bin/delaypublish.pl --site=$site | at '$hour:$min $month/$day/$year'";

        my $retval = system($command);

        if($retval) {
            $this->{LOG}->error("Error while running at/delaypublish, returncode: $retval");
            return undef;
        }
        $this->{LOG}->info("====> Setting 'at' autopublishing job ... done");
    }
    return 1;
}

# unpublish_version - given a version object, attempts to unpublish
#                     it. If the argument is not an object or if the
#                     user does not have permissions to unpublish the
#                     version a fatal error is triggered.
#
#                     (Unpublishing consists of deleting all publish
#                     vfields and marking the version non-public in
#                     the versions table).
sub unpublish_version {
    my ($this, $vdoc) = @_;

    print STDERR "Unpublishing version\n";
    croak "vdoc not an Obvius::Version\n"
        unless (ref $vdoc and $vdoc->UNIVERSAL::isa('Obvius::Version'));

    die "User $this->{USER} does not have access to hide the document."
        unless $this->can_unpublish_version($vdoc);

    # XXX Should unpublish the public version on the same language as vdoc, if vdoc isn't the public one!!

    $this->db_begin;
    eval {
        my $doctype = $this->get_version_type($vdoc);
        my @fields = $doctype->publish_fields->param;

        $this->{LOG}->info("====> Unpublishing version ... mark unpublic");
        $this->db_update_version_mark_public($vdoc, 0);

        $this->{LOG}->info("====> Unpublishing version ... deleting publish vfields");

        foreach (@fields) {
            if ($vdoc->DocId and $vdoc->Version and $_) {
                $this->db_delete_vfield($vdoc->DocId, $vdoc->Version, $_);
            }
            else {
                die "Trying to delete vfield gave problems";
            }
        }

        $this->{LOG}->info("====> Unpublishing version ... COMMIT");
        $this->db_commit;
    };

    my $ev_error=$@;
    if ($ev_error) {                    # handle error
        $this->{DB_Error} = $ev_error;
        $this->db_rollback;
        $this->{LOG}->error("====> Unpublishing version ... failed ($ev_error)");
        return undef;
    }

    undef $this->{DB_Error};
    $this->{LOG}->info("====> Unpublishing version ... done");
    $this->register_modified(docid=>$vdoc->Docid, clear_leftmenu => 1);
    my $doc = $this->get_doc_by_id($vdoc->Docid);
    $this->register_modified(admin_leftmenu => [$doc->Id, $doc->Parent]);
    return 1;
}


########################################################################
#
#                       Deleting a single version
#
########################################################################

sub delete_single_version {
    my ($this, $vdoc, $errorref) = @_;

    my $doc = $this->get_doc_by_id($vdoc->DocId);

    unless($this->can_delete_single_version($doc)) {
        $$errorref = "User $this->{USER} does not have access to delete versions" if($errorref);
        return undef;
    }

    my $public_version = $this->get_public_version($doc);
    if($public_version) {
        if($public_version->Version eq $vdoc->Version) {
            $$errorref = "Cannot delete public versions" if($errorref);
            return undef;
        }
    } else {
        my $latest_version = $this->get_latest_version($doc);
        if($latest_version and $latest_version->Version eq $vdoc->Version) {
            $$errorref = "Cannot delete latest version when there is no public version" if($errorref);
            return undef;
        }
    }


    $this->db_begin;
    eval {
        $this->{LOG}->info("====> Deleting single version fields ... delete from vfields");
        $this->db_delete_single_version_vfields($vdoc->DocId, $vdoc->Version);
        $this->{LOG}->info("====> Deleting single version ... delete from versions");
        $this->db_delete_single_version($vdoc->DocId, $vdoc->Version, $vdoc->Lang);

        $this->{LOG}->info("====> Deleting single version ... COMMIT");
        $this->db_commit;
    };

    if ($@) {                   # handle error
        $this->{DB_Error} = $@;
        $this->db_rollback;
        $this->{LOG}->error("====> Deleting single version ... failed ($@)");
        return undef;
    }

    undef $this->{DB_Error};
    $this->{LOG}->info("====> Deleting single version ... done");
    return 1;
}



########################################################################
#
#       Registering modifications
#
########################################################################

sub register_modified {
    my ($this, %options)=@_;
    
    if (!$this->{MODIFIED}) {
	 $this->{MODIFIED} = WebObvius::Cache::CacheObjects->new($this);
    }
    $this->{MODIFIED}->add_to_cache($this, %options);
}

sub modified {
    my ($this)=@_;

    return $this->{MODIFIED};
}


########################################################################
########################################################################
#
#       Currently unused code.
#
########################################################################
########################################################################

# get_field - XXX OBSOLETE, to be removed. Don't call.
sub get_field {
    my ($this, $version, $name) = @_;

    carp "Call to OBSOLETE method Obvius::get_field";

    $this->tracer($version, $name) if ($this->{DEBUG});

    return $version->{$name} if (exists $version->{$name});

    my $versiontype = $version->get_version_type();
    if( my $fieldspec = $versiontype->get_fieldspec($name, $versiontype) ) {
        my $value = $version->get_vfield($name);
        $value=$fieldspec->_default_value unless $value;

        $version->{$name} = $value;
        return $value;
    }
    else {
        $this->{LOG}->warn("Asked for field $name, which does not exist in this document-type (ref($versiontype))!");
        return undef;
    }
}


########################################################################
#
#       Class methods
#
########################################################################

# sanity_check - goes through the doctypes and checks if
#                Obvius::DocType::doctypename can be use'd
#                Obsolete method, not called from anywhere.
sub sanity_check {
    my ($this, $config) = @_;

    $this->tracer($config) if ($this->{DEBUG});

    my $set=DBIx::Recordset->SetupObject( {'!DataSource'=>$this->{DB},
                                           '!Table'     =>'doctypes',
                                          } );
    $set->Search();
    while (my $rec=$set->Next()) {
        my $type='Obvius::DocType';
        $type .= "::$rec->{name}";
        eval "require $type" or croak "Couldn't load $type";
    }
    $set->Disconnect;
}



########################################################################
#
#       DocType external methods
#
########################################################################


sub execute_command {
     my ($this, $sql, @args) = @_;

     my $sth = $this->{DB}->DBHdl->prepare($sql);
     
     $sth->execute(@args);
}
     
sub execute_select {
     my ($this, $sql, @args) = @_;

     my $sth = $this->{DB}->DBHdl->prepare($sql);
     
     $sth->execute(@args);
     my @res;

     while (my $row = $sth->fetchrow_hashref) {
	  push @res, $row;
     }
     
     $sth->finish;
     return \@res;
}

sub just_publish_fucking_version {
     my ($this, $docid, $version) = @_;

     $this->execute_command('update versions set public=0 where docid=?', $docid);
     $this->execute_command('update versions set public=1 where docid=? and version=?', $docid, $version);
}
     
sub get_fieldspec_XXX {
    my ($this, $doctype, $name) = @_;

    $this->tracer($doctype, $name) if ($this->{DEBUG});

    my $fieldspecs=$doctype->get_fieldspecs();
    return $fieldspecs->{$name};
}

sub get_fieldspecs_XXX {
    my ($this, $doctype) = @_;

    $this->tracer($doctype) if ($this->{DEBUG});

    return $doctype->{FIELDSPECS} if $doctype->{FIELDSPECS};

    my $set=DBIx::Recordset->SetupObject( {'!DataSource'=>$this->{DB},
                                           '!Table'     =>'fieldspecs',
                                          } );
    my %fieldspecs;
    my $type=$doctype;
    while( $type )
    {
        print "  DOCTYPE: " . $type->_id . ", " . $type->_name . ", " . $type->_parent . "\n" if $this->{DEBUG};
        $set->Search( { typeid=>$type->_id } );
        while( my $rec=$set->Next )
        {
            my $fieldspec= Obvius::FieldSpec->new($rec);
            $fieldspecs{$fieldspec->name}=$fieldspec;
        }
        $type=$this->get_doctype($type->_parent);
    }
    $set->Disconnect;

    $doctype->{FIELDSPECS}=\%fieldspecs;

    return $doctype->{FIELDSPECS};
}

sub get_editpage {
    my ($this, $doctype, $pagename)=@_;

    my $editpages=$this->get_editpages($doctype);
    return (exists $editpages->{$pagename} ? $editpages->{$pagename} : undef);
}

sub get_editpages {
    my ($this, $doctype) = @_;

    $this->tracer($doctype) if ($this->{DEBUG});

    return $doctype->{EDITPAGES} if $doctype->{EDITPAGES};

    my $set=DBIx::Recordset->SetupObject( {'!DataSource'=>$this->{DB},
                                           '!Table'     =>'editpages',
                                          } );
    my $editpages={};
    $set->Search( { doctypeid=>$doctype->Id } );
    while( my $rec=$set->Next ) {
        my $editpage=Obvius::EditPage->new($rec);
        $editpages->{$editpage->Page}=$editpage;
    }
    $set->Disconnect;

    $doctype->{EDITPAGES}=(keys %$editpages ? $editpages : undef);

    return $doctype->{EDITPAGES};
}



# Preview stuff.
package Obvius::Benchmark;

use strict;
use Time::HiRes qw(gettimeofday);

sub new
{
        my ( $self, $id, $filehandle) = @_;
	
        $id = join(':', (caller)[1,2]) unless defined $id;
	open $filehandle, '<', "/tmp/obvius_benchmark" if(!$filehandle);

        return bless [ $id, scalar gettimeofday(), $filehandle, 1 ];
}

sub lap
{
        my ( $self, $id) = @_;

        return unless $self-> [3];

        $id = join(':', (caller)[1,2]) unless defined $id;
	
	my $now  = scalar gettimeofday();
        my $diff = $now - $self->[1];
	my $now_string = scalar localtime;

        printf { $self-> [2] } "$now_string $$ %.3f sec %s %s\n",
                $diff,
                $self-> [0], $id
        if $diff >= 0.01; # who cares otherwise

        $self-> [0] = $id;
        $self-> [1] = $now;
}

sub disable { shift->[3] = 0 }

sub DESTROY { my $self = shift; $self->lap(''); close $self->[2]; }

1;
__END__

=head1 NAME

Obvius - Content Manager, database handling.

=head1 SYNOPSIS

    use Obvius;
    use Obvius::Config;

    my $obvius_config=new Obvius::Config($sitename);

    my $obvius=new Obvius($obvius_config);
    $obvius->connect;

    my $doc=$obvius->lookup_document($path);

    my ($hashref, $arrayref) = $obvius->calc_order_for_query($vdoc);

    $obvius->adjust_doctype_hierarchy(); # Internal.

    $obvius->sanity_check($config); # Obsolete, not used.

    my $vdoc=$obvius->get_version($doc, '2003-04-05 16:27:13');

    my $aref=$obvius->get_public_version($doc);

    my $value=$obvius->get_version_field($vdoc, 'title');

    my $fieldspec=$obvius->get_fieldspec('keyword', $doctype);

=head1 DESCRIPTION

Obvius is the main object for accessing the content manager.

=head1 Obvius::Benchmark

    sub a{
        my $b = Obvius::Benchmark-> new if $this-> {BENCHMARK};
        ... code ...
    }

    sub b{
        my $b = Obvius::Benchmark-> new('sub b') if $this-> {BENCHMARK};
        ....
        $b-> lap('point 1') if $b;
        ....
        $b-> lap('point 2') if $b;
        ....
        undef $b;  # <-- this is also a checkpoint
    }

=head2 EXPORT

None by default.

=head1 AUTHOR

Jørgen Ulrik B. Krag <lt>jubk@magenta-aps.dk<gt>
Peter Makholm <lt>pma@fi.dk<gt>
René Seindal
Adam Sjøgren <lt>asjo@magenta-aps.dk<gt>

=head1 SEE ALSO

L<Obvius::Config>.

=cut
