package Obvius::DocType;

########################################################################
#
# DocType.pm - Document Types
#
# Copyright (C) 2001-2005 Magenta Aps, Denmark (http://www.magenta-aps.dk/)
#                         aparte A/S, Denmark (http://www.aparte.dk/)
#                         FI, Denmark (http://www.fi.dk/)
#
# Authors: Jørgen Ulrik B. Krag (jubk@magenta-aps.dk)
#          Peter Makholm
#          René Seindahl
#          Adam Sjøgren (asjo@magenta-aps.dk)
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

use Obvius;
use Obvius::Data;
use Data::Dumper;
use Obvius::SolrConvRoutines;

#     The object contains two instances of Obvius::Data. Both contain
#     fields associated with the object:
#     FIELDS: Fields which cannot be changed after the object has been
#             created. A new version must be created to change them.
#     PUBLISH_FIELDS: Fields which can be changed without creating a new
#                     version. These fields are usually associated with a
#                     published version of the document and usually
#                     dropped once the document is no longer published.

our @ISA = qw( Obvius::Data );
our $VERSION="1.0";

sub new {
    my ($class, $rec) = @_;

    my $this = $class->SUPER::new($rec);

    $this->{FIELDS} = new Obvius::Data;
    $this->{PUBLISH_FIELDS} = new Obvius::Data;

    return $this;
}

sub mode {
     my ($this, $args) = @_;

     my %modes = ('search' => 'search');
     my ($mode) = $args->{obvius_mode} && $modes{$args->{obvius_mode}};

     return $mode;
}

sub add_js {
     shift;
     return map {"<script type=\"text/javascript\" src=\"$_\"></script>" } @_;
}

sub add_link {
     shift;
     return map {"<link rel=\"stylesheet\" type=\"text/css\" href=\"$_\"></link>" } @_;
}

sub generate_head_html {
     my ($this, $r, $doc, $vdoc, $obvius) = @_;

     my $mode = $this->mode({
                             map { $_ => $r->param($_) || undef }
                             grep {$r->param($_)} $r->param
                            });

     if ($mode && $mode eq 'search') {
          my @header;
          my @search_js = (
              '/scripts/jsutils.js',
              '/scripts/jquery/jquery.ajaxQueue.js'
          );
          my @search_css = ('/style/jquery.autocomplete.css');
          if(!$r->notes('bootstrap')) {
               unshift(@search_js, "//code.jquery.com/ui/1.10.3/jquery-ui.min.js");
               unshift(@search_css,
                       "//code.jquery.com/ui/1.10.3/themes/smoothness/jquery-ui.css");
          }

          push @header, $this->add_js(@search_js);
          push @header, $this->add_link(@search_css);

          return join "\n", @header;
     }

     return '';
}

sub view {
     my ($this, $args) = @_;

     my %views = (search => '/views/search');
     my $view;

     if (my $view_arg = $this->mode($args)) {
          $view = $views{$view_arg};
     }

     if (!defined $view) {
          ($view) = (ref $this) =~ m!::([^:]+$)!;
          $view = "/doctypes/$view";
     }

     return $view;
}

########################################################################
### Methods regarding SOLR usage
########################################################################

########################################################################
# get_solr_fields
# RETURN: A hash-reference where keys are obvius field-names
#         and values are array refs, where:
#         Element 1 (required) = 'f' (VFIELDS fieldname) OR
#                                'd' (dokument fieldname) OR
#                                'v' (version fieldname)
#         Element 2 (required) = SOLR fieldname
#         Element 3 (optional) = CODE reference to subroutine that transforms fieldvalue
#                                indicated by key to value to use for SOLR field.
#                                The subroutine must take one argument (the value) and
#                                return one value.
#                                If not specified, then no tranformation is used - i.e
#                                the field-value is used unmodified
#         Element 4 (optional) = Source of alternative value which is used if elem1 and 2 yields an empty value
#                                'f' (VFIELDS fieldname) OR
#                                'd' (dokument fieldname) OR
#                                'v' (version fieldname)
#         Element 5 (optional) = Alternative SOLR fieldname
########################################################################
sub get_solr_fields  {
    my($self, $obvius) = @_;
    ### To PERL string conversion is only necessary on old_db_model
    my $perlConv = $obvius->can('schema') ? undef : \&Obvius::SolrConvRoutines::toPERL;
    ### Standard fields exported to SOLR
    my $fieldmap = {
	'Id'             => ['d', 'id'],
	'published'      => ['f', 'published', \&Obvius::SolrConvRoutines::toUTCDateTime, 'v', 'Version'],
	'docdate'        => ['f', 'docdate',   \&Obvius::SolrConvRoutines::toUTCDateTime, 'v', 'Version'],
	'content'        => ['f', 'content', $perlConv],
	'teaser'         => ['f', 'teaser', $perlConv],
	'Path'           => ['d', 'path'],
	'title'          => ['f', 'title', $perlConv],
	'Lang'           => ['v', 'lang'],
	'Type'           => ['v', 'type', sub { my $doct = $obvius->{DOCTYPES}->[shift @_];
						return $doct ? $doct->Name(): '' }],
    };
    return $fieldmap;
}

########################################################################
### Should be used by subclasses to insert entries in solr fields hashref
########################################################################
sub set_solr_field {
    my($self, $fieldhash, $key, $spec) = @_;
    if ( $fieldhash && $key && $spec ) {
	if ( exists $fieldhash->{$key} ) {
	    $fieldhash->{'*' . $key . '*'} = $spec;
	} else {
	    $fieldhash->{$key} = $spec;
	}
    }
}

# action - the action method in the document type is called by Obvius
#          when a document perform its function. Obvius provides data
#          for the document type to use on the input-object and the
#          document type is supposed to leave relevant outgoing data
#          on the output-object. This is then used by the template
#          system to display what ever is relevant, to the user.
sub action {
    my ($this, $input, $output, $doc, $vdoc, $obvius) = @_;

    $this->tracer($input, $output, $doc, $vdoc, $obvius) if ($this->{DEBUG});

    return 1; # OBVIUS_OK
}

# is_cacheable - should return true if the document type in general is
#                cachable and false if not.
sub is_cacheable { return 1; }

# alternate_location - if this method returns a string, Obvius
#                      redirects to the location given in the
#                      string. Return undef to avoid redirection.
sub alternate_location { return undef; }

# internal_redirect - 	if the document should serve the contents of a local
#			static file residing inside the document root this
#			method should return the uri of that file. Will be
#			called after alternate_location and before
#			raw_document_data. Arguments are:
#			$doc, $vdoc, $obvius, $req, $output
sub internal_redirect { return undef; }


# raw_document_data - if this document returns binary data, this
#                     method must return a list with the mimetype, the
#                     raw data (as a string) an optionally a
#                     filename. If the document is a "normal"
#                     document, this method must return undef.
sub raw_document_data { return undef; }

# handle_path_info - return true if the document type wants to handle
#                    excess $path_info itself. Return undef otherwise.
sub handle_path_info { return undef; }

# # create_new_version_handler - if a document type provides a create_new_version_handler
# #                              method, it is called with the fields (an Obvius::Data object)
# #                              and the $obvius object. If the handler returns OBVIUS_OK
# #                              the creation continues, otherwise it is aborted.
# #                              If special action needs to be taken when a new version of
# #                              a specific document type is needed, it can be plugged in
# #                              here.
# #                              Note that this method is called before both language-check
# #                              and before verification of field-values, so the creation
# #                              of the version can fail on those accounts after this method
# #                              has been called. (The actual database-calls can fail too,
# #                              obviusly.)
# sub create_new_version_handler {
#     my ($this, $fields, $obvius)=@_;
#
#     # ...
#
#     return OBVIUS_OK;
# }

#########################################################################
#
# Utility: map doctypename to number, for use in searches (Combo and DB):
#
#########################################################################


sub doctypemap {
    my ($this, $a, $b, $c, $d, $doctypename, $obvius)=@_;

    my $doctypeid;
    # XXX Should check translations as well...
    if (my $doctype=$obvius->get_doctype_by_name($doctypename)) {
	$doctypeid=$doctype->Id;
	#warn "DOCTYPE $doctypename has id $doctypeid!";
    }
    else {
	warn "Couldn't determine id for doctype $doctypename. Defaulting to 1.";
	$doctypeid=1;
    }

    return $a . 'type' . $b . $c . $d . "'" . $doctypeid . "'";
}

########################################################################
#
#	Export lists of documents (modified from WebObvius::Site::Magenta)
#
########################################################################

use constant REQUIRE_THRESHOLDS => {
				    default => 32,
				    teaser => 64,
				    fullinfo => 128,
				    'full-info' => 128,
				    content => 128,
				    binary => 192,
				   };


use POSIX qw(strftime);

# Return document list to an Output object
# vdoclist is really an array of Obvius::Version objects
#
# XXX These are legacy functions for the aging Magenta::Template-system:
sub export_doclist {
    my ($this, $vdoclist, $output, $obvius, %options) = @_;

    $this->tracer($vdoclist, $output, %options) if ($this->{DEBUG});

    return undef unless (@$vdoclist);

    # Ok, we have a vdoclist, declare depencies:
    $output->param(Obvius_DEPENCIES => 1);

    # The configfile might tell us to just export the vdocs
    # "return_vdoclist" option also forces this behavior
    if($obvius->config->param('searchdocs_exports_vdocs') || $options{'return_vdoclist'}) {
        $output->param($options{name} || 'subdocs', $vdoclist);
        return $vdoclist;
    }


    # my $req = $output->request;
    # my $obvius = $output->obvius;

    my $active = $options{active};
    # $req->notes('prefix') ||
    my $prefix = $options{prefix} || '';
    my $require = ($options{require} and REQUIRE_THRESHOLDS->{$options{require}})
	|| REQUIRE_THRESHOLDS->{default}
	    || 0;
    # $req->notes('now') ||
    my $now = $options{now} || strftime('%Y-%m-%d %H:%M:%S', localtime);

    my $last_date = '**';
    my $last_title = '**';

    my @docdata;

    for (@$vdoclist) {
	my $fields = $obvius->get_version_fields($_, $require);
	my $doc = $obvius->get_doc_by_id($_->Docid);

	unless ($options{include_images}) {
	    # Elide images
	    my $vdoctype=$obvius->get_version_type($_);
	    next if ($vdoctype->Name eq "Image");
	}

	my $new_date = ($last_date ne $fields->Docdate);
	$last_date = $fields->Docdate;

	my $first_letter = uc(substr($fields->Title, 0, 1));
	my $new_title = ($last_title ne $first_letter) ? $first_letter : '';
	$last_title = $first_letter;

        my $data;

        if($options{use_vdoc_data}) {
            $data = $_;
            $data->param('id' => $doc->Id);
            $data->param('name' => $doc->Name);
            $data->param('url' => $prefix . $obvius->get_doc_uri($doc, break_siteroot => $options{break_siteroot}));
            $data->param('new_date' => $new_date);
            $data->param('new_title' => $new_title);
        } else {
	    $data = {
			id		=> $doc->Id,
			name	=> $doc->Name,
			url		=> $prefix . $obvius->get_doc_uri($doc, break_siteroot => $options{break_siteroot}),

			version	=> $_->Version,
			public	=> ($_->Public > 0),

			active	=> (defined($active) and $_->Docid == $active->param('id')),

			expires	=> $fields->Expires,
			expired	=> ($fields->Expires lt $now),

			new_date	=> $new_date,
			new_title	=> $new_title,

			# Compat
			extern_url	=> $fields->param('url'),
		   };
        }

	for my $f ($fields->param) {
	    $data->{lc $f} ||= $fields->param($f);
	}
	push(@docdata, $data);
    }

    $output->param($options{name} || 'subdocs', \@docdata);
    return (@docdata ? \@docdata : undef);
}



########################################################################
#
#	Export paged lists of documents
#
########################################################################

# Return pages of subdocs to a Output object
sub export_paged_doclist {
    my ($this, $pagesize, $doclist, $output, $obvius, %options) = @_;

    $this->tracer($pagesize, $doclist, $output, $obvius, %options) if ($this->{DEBUG});

    # default is first page
    my $page = $options{page} || 1;
    return undef unless (defined($page) and $page > 0);

    # map from 1 based to zero based
    $page--;
    # print STDERR ("PAGE SIZE $pagesize PAGE $page\n");

    # max number of pages available
    my $page_max = int(($#$doclist+$pagesize)/$pagesize);
    # print STDERR ("PAGE MAX $page_max\n");
    return undef if ($page >= $page_max); # out of range

    # calculate document range to use
    my $doc_total = $#$doclist+1;
    my $doc_first = $page * $pagesize;
    my $doc_last = ($page+1) * $pagesize - 1;
    $doc_last = $#$doclist if ($doc_last > $#$doclist);
    # print STDERR ("DOCS $doc_first..$doc_last TOTAL $doc_total\n");

    # slice out the relevant parts of the document list
    my @subdocs = @$doclist[$doc_first .. $doc_last];

    my $doc_index = $doc_first;
    my $docdata = $this->export_doclist(\@subdocs, $output, $obvius, %options);
    map { $_->{doc_index} = $doc_index++ } @$docdata;


    my $page_first = $page - 5;
    $page_first = 0 if ($page_first < 0);

    my $page_last = $page_first + 10;
    $page_last = $page_max-1 if ($page_last >= $page_max);

    $page_first = $page_last - 10;
    $page_first = 0 if ($page_first < 0);

    $output->param(page=>$page+1);
    $output->param(page_next=>$page+2) if ($page_max-$page > 1);
    $output->param(page_prev=>$page) if ($page != 0);
    $output->param(page_max=>$page_max);

    $output->param(page_list=> [ map { ({
				       page=>$_+1,
				       active=>($page == $_),
				      })
				 } ($page_first .. $page_last)
			     ]);

    $output->param(doc_first=>$doc_first+1);
    $output->param(doc_last=>$doc_last+1);
    $output->param(doc_total=>$doc_total);

    return $docdata;
}


########################################################################
#
#	Convenience
#
########################################################################

sub fields_names {
    my ($this, $type) = @_;
    $type=$type || 'FIELDS';
    return [keys %{$this->fields($type)}];
}

sub fields {
    my ($this, $type) = @_;
    $type=$type || 'FIELDS';
    return $this->{$type};
}

sub field {
    my ($this, $name, $value, $type) = @_;
    $type=$type || 'FIELDS';
    return $this->{$type}->param($name => $value);
}

# publish_fields_names ()
#  - Returns a list with the names of the fields in the PUBLISH_FIELDS
sub publish_fields_names {
    my ($this) = @_;
    return $this->fields_names('PUBLISH_FIELDS');
}

# publish_fields ()
#   - Returns the PUBLISH_FIELDS Obvius::Data object for the document.
sub publish_fields {
    my ($this) = @_;
    return $this->fields('PUBLISH_FIELDS');
}

# publish_field ($name, $value)
# - Add a field with the name $name and value $value to PUBLISH_FIELDS
#   Returns $value
sub publish_field {
    my ($this, $name, $value) = @_;
    return $this->field($name => $value, 'PUBLISH_FIELDS');
}

sub default_fields_common {
    my ($this, $fields) = @_;
    return new Obvius::Data(map { $_ => $fields->param($_)->param('default_value'); } $fields->param);
}

sub default_fields {
    my ($this) = @_;
    return $this->default_fields_common($this->{FIELDS});
}

sub default_publish_fields {
    my ($this) = @_;
    return $this->default_fields_common($this->{PUBLISH_FIELDS});
}

sub type_map {
    my ($this, $fields) = @_;
    return { map { $_ => $fields->param($_)->param('fieldtype'); } $fields->param };
}

sub field_type_map {
    my ($this) = @_;
    return $this->type_map($this->{FIELDS});
}

sub publish_type_map {
    my ($this) = @_;
    return $this->type_map($this->{PUBLISH_FIELDS});
}

########################################################################
#
#	Validation methods
#
########################################################################

sub validate {
    my ($this, $vdoc, $obvius) = @_;
    return 1;
}

sub validate_data {
    my ($this, $type_fields, $fields, $obvius) = @_;

    $this->tracer($fields, $obvius) if ($this->{DEBUG});

    $fields = new Obvius::DocType::HashParam($fields) if ((ref $fields || '') eq 'HASH');

    my @valid = ();
    my @invalid = ();

    for ($type_fields->param) {
	next unless (defined $fields->param($_));

	my $fspec = $type_fields->param($_);
	my $ftype = $fspec->FieldType;

	my $value = $fields->param($_);

        # An empty array for a repeatable field which is not optional,
        # is set to "missing"/not defined:
        #
        # Note: This could be slightly problematic; how do you empty
        # such a field? I.e. if you're put some entries in it, you
        # can't remove all of them! But if it's optional, it can't be
        # empty. In reality our definition of non-optional is lax, so
        # it could actually be a problem, even though it shouldn't. Be.
        #
        if ($fspec->Repeatable and !$fspec->Optional and ref $value and scalar(@$value)==0) {
            $fields->delete($_); # undef it, so it's picked up in the missing-array below
            next;
        }

	my $ok;

	if ($fspec->Repeatable) {
	    if (ref $value) {
		$ok = not scalar(grep {
		    not defined $ftype->validate($obvius, $fspec, $_, $fields)
		} @$value);
	    } else {
		$ok = defined $ftype->validate($obvius, $fspec, $value, $fields);
	    }
	} else {
	    $ok = defined $ftype->validate($obvius, $fspec, $value, $fields);
	}

	if ($fspec->Optional) {
	    $ok = ($ok || ($value eq ''));
	}

	if ($ok) {
	    #print STDERR "VALID $_ = «$value»\n";
	    push(@valid, $_);
	} else {
	    #print STDERR "INVALID $_ = «$value»\n";
	    push(@invalid, $_);
	}
    }

    my @excess  = grep { not defined $type_fields->param($_) } $fields->param
	if (wantarray);
    my @missing = grep { not ( defined $fields->param($_)
			       or $type_fields->param($_)->Optional) } $type_fields->param;

    #local $, = ', ';
    #print STDERR "VALIDATE: valid: @valid\n";
    #print STDERR "VALIDATE: invalid: @invalid\n";
    #print STDERR "VALIDATE: excess: @excess\n";
    #print STDERR "VALIDATE: missing: @missing\n";

    return (wantarray
	    ? ( valid	 => (scalar(@valid)   ? \@valid   : undef),
		invalid	 => (scalar(@invalid) ? \@invalid : undef),
		missing	 => (scalar(@missing) ? \@missing : undef),
		excess	 => (scalar(@excess)  ? \@excess  : undef),
		dummy    => 0
	      )
	    : (scalar(@invalid) == 0 and scalar(@missing) == 0)
	   );
}

sub validate_fields {
    my $this = shift;
    $this->tracer(@_) if ($this->{DEBUG});
    return $this->validate_data($this->fields, @_);
}

sub validate_publish_fields {
    my $this = shift;
    $this->tracer(@_) if ($this->{DEBUG});
    return $this->validate_data($this->publish_fields, @_);
}


# XXX I'm not sure why this is here, perhaps it predates Obvius::Data,
# perhaps there is a reason:

package Obvius::DocType::HashParam;

sub new {
    my ($class, $hashref) = @_;
    bless { PARAMS => $hashref }, $class;
}

sub param {
    my $this = shift;
    my $name = shift;

    return keys %{ $this->{PARAMS} } unless (defined $name);

    my $value = shift;
    return $this->{PARAMS}->{$name} unless (defined $value);
    return $this->{PARAMS}->{$name} = $value;
}

sub delete {
    my ($this, $name)=@_;
    delete $this->{PARAMS}->{$name};
}

1;
__END__

=head1 NAME

Obvius::DocType - container for the specific Obvius document type classes.

=head1 SYNOPSIS

  use Obvius::DocType;

  # Usage of convenience functions
  $obj->publish_fields_names() # Returns [name1, name2, ...]

  $obj->publish_fields() # Returns Obvius::Data object

  %obj->publish_field(field_name, field_value) #Returns field_value

=head1 DESCRIPTION

This module basically defines defaults for document types. The
stub-methods here define the interface that Obvius::DocType::* have.

 * alternate_location
 * action
 * raw_document_data
 * handle_path_info
 * is_cacheable
 * create_new_version_handle

=head1 AUTHOR

 Jørgen Ulrik B. Krag E<lt>jubk@magenta-aps.dkE<gt>
 Peter Makholm
 René Seindahl
 Adam Sjøgren E<lt>asjo@magenta-aps.dkE<gt>

=head1 SEE ALSO

L<Obvius::DocType::Standard>, L<Obvius::DocType::Link>, L<Obvius::DocType::Upload>.

=cut
