# $Id$

package WebObvius::Site::Magenta;

use 5.006;
use strict;
use warnings;

use WebObvius::Site;

our @ISA = qw( WebObvius::Site );
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

use WebObvius::Template::MCMS;
use WebObvius::Template::Provider;

sub make_provider {
    my $this = shift;
    return new WebObvius::Template::Provider(@_);
}

sub make_template {
    my $this = shift;
    return new WebObvius::Template::MCMS(@_);
}

our %doctype_to_legacy_operation = ( Standard => 'view',
				     HTML => 'view',
				     KeywordsSearch => 'keywords',
				     OrderForm => 'mail_order',
				     CreateDocument => 'mail_data',
				   );

sub create_output_object {
    my ($this, $req, $doc, $vdoc, $doctype, $obvius) = @_;

    my $path = $this->{TEMPLATES};
    my $trace = ($req->connection->remote_ip =~ /^(127|192\.168)\./) ? 4 : 0;
    my $tracefile = sprintf('%s/template.%s',
			    $this->{CACHE_DIRECTORY} || '/tmp',
			    ($this->{SUBSITE} ? 'out' : 'sub')
			   );

    my $output = $this->make_template(path=>$path, cache=>1, debug=>$this->{DEBUG},
				      trace=>$trace, tracefile=>$tracefile);

    $output->param(SERVER_NAME => $req->server->server_hostname);
    $output->param(PREFIX => $req->notes('prefix'));
    $output->param(URI => $req->uri);
    $output->param(PATH_INFO => $req->path_info);
    $output->param(NOW => $req->notes('now'));

    my $op = $doctype->Name;

    if (exists $doctype_to_legacy_operation{$op}) {
	$op = $doctype_to_legacy_operation{$op};
    } elsif ($op =~ /[a-z][A-Z]/) {
	$op =~ s/([a-z])([A-Z])/$1_$2/g;
    }
    $op = lc $op;

    $output->param("MCMS_\U$op\E" => 1);
    $output->param(MCMS_OPERATION => $op);
    $op =~ tr/_/-/;
    $output->param(MCMS_OPERATION_HYPHEN => $op);

    $output->{PROVIDER} = $this->make_provider(site => $this,
					       request => $req,
					       document => $doc,
					       version => $vdoc,
					       doctype => $doctype,
					       obvius => $obvius,
					      );

    return $output;
}

sub expand_output {
    my ($this, $site, $output) = @_;



    my $s = $output->expand('dispatch.html', $output->{PROVIDER});
    print STDERR ">>>>>>>>>>>>>>>>\n$s\n<<<<<<<<<<<<<<<<\n" if ($this->{DEBUG});
    return $s;
}



########################################################################
#
#	Helpers
#
########################################################################


sub split_multipart_data {
    my ($this, $field, $value) = @_;

    return undef unless ($field and $value);

    my %vars = ( $field => '', __order => [] );
    my $current = \$vars{$field};

    for (split("\n", $value)) {
	if (/^\[(\w+)\]$/) {
	    $vars{$1} = '';
	    $current = \$vars{$1};
	    push(@{$vars{__order}}, $1);
	} else {
	    substr($_, 0, 1) = '' if (/^\[\[/);
	    $$current .= "$_\n";
	}
    }
    for (keys %vars) {
	$vars{$_} =~ s/\n+$//s;
    }

    return \%vars;
}


#######################################################################
#
#	Export lists of documents
#
#######################################################################

use constant REQUIRE_THRESHOLDS => {
				    default => 32,
				    teaser => 64,
				    fullinfo => 128,
				    'full-info' => 128,
				    content => 128,
				    binary => 192,
				   };

use POSIX qw(strftime);

# Return document list to a Template object
# vdoclist is really an array of Obvius::Version objects
sub export_doclist {
    my ($this, $vdoclist, $template, %options) = @_;

    $this->tracer($vdoclist, $template, %options) if ($this->{DEBUG});

    return undef unless (@$vdoclist);

    my $req = $template->request;
    my $obvius = $template->obvius;

    my $active = $options{active};
    my $prefix = $req->notes('prefix') || $options{prefix} || '';
    my $require = ($options{require} and REQUIRE_THRESHOLDS->{$options{require}})
	|| REQUIRE_THRESHOLDS->{default} 
	    || 0;
    my $now = $req->notes('now') || $options{now} || strftime('%Y-%m-%d %H:%M:%S', localtime);

    my $last_date = '**';
    my $last_title = '**';

    my @docdata;

    for (@$vdoclist) {
	my $fields = $obvius->get_version_fields($_, $require);
	my $doc = $obvius->get_doc_by_id($_->Docid);

	# Elide images
	next if (substr(($fields->param('mimetype') || ''), 0, 6) eq 'image/' );

	my $new_date = ($last_date ne $fields->Docdate);
	$last_date = $fields->Docdate;

	my $first_letter = uc(substr($fields->Title, 0, 1));
	my $new_title = ($last_title ne $first_letter) ? $first_letter : '';
	$last_title = $first_letter;

	my $data = {
		    id		=> $doc->Id,
		    name	=> $doc->Name,
		    url		=> $prefix . $obvius->get_doc_uri($doc),

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

	for my $f ($fields->param) {
	    $data->{lc $f} ||= $fields->param($f);
	}
	push(@docdata, $data);
    }

    $template->param($options{name} || 'subdocs', \@docdata);
    return \@docdata;
}



########################################################################
#
#	Export paged lists of documents
#
########################################################################

# Return pages of subdocs to a Template object
sub export_paged_doclist {
    my ($this, $pagesize, $doclist, $template, %options) = @_;

    $this->tracer($pagesize, $doclist, $template, %options) if ($this->{DEBUG});

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
    my $docdata = $this->export_doclist(\@subdocs, $template, %options);
    map { $_->{doc_index} = $doc_index++ } @$docdata;


    my $page_first = $page - 5;
    $page_first = 0 if ($page_first < 0);

    my $page_last = $page_first + 10;
    $page_last = $page_max-1 if ($page_last >= $page_max);

    $page_first = $page_last - 10;
    $page_first = 0 if ($page_first < 0);

    $template->param(page=>$page+1);
    $template->param(page_next=>$page+2) if ($page_max-$page > 1);
    $template->param(page_prev=>$page) if ($page != 0);
    $template->param(page_max=>$page_max);

    $template->param(page_list=> [ map { ({ 
				       page=>$_+1,
				       active=>($page == $_),
				      })
				 } ($page_first .. $page_last) 
			     ]);

    $template->param(doc_first=>$doc_first+1);
    $template->param(doc_last=>$doc_last+1);
    $template->param(doc_total=>$doc_total);

    return $docdata;
}




########################################################################
#
#	Export lists of sub-documents
#
########################################################################

# Return subdocs info to a Template object
sub export_subdocs {
    my ($this, $doc, $prefix, $template, %options) = @_;

    $this->tracer($doc, $prefix, $template, %options) if ($this->{DEBUG});

    my $obvius = $template->obvius;

    my $subdocs = $obvius->get_document_subdocs($doc, order=>$options{sortorder});
    return $this->export_doclist($subdocs, $template, %options);
}

# Return pages of subdocs to a Template object
sub export_paged_subdocs {
    my ($this, $doc, $prefix, $template, %options) = @_;

    $this->tracer($doc, $prefix, $template, %options) if ($this->{DEBUG});

    my $obvius = $template->obvius;
    my $vdoc = $obvius->get_public_version($doc);

    my $pagesize = $vdoc->field('pagesize');
    return $this->export_subdocs($doc, $prefix, $template, %options)
	unless (defined $pagesize and $pagesize > 0);

    my $subdocs = $obvius->get_document_subdocs($doc, order=>$options{sortorder});
    return undef unless ($subdocs);

    return $this->export_paged_doclist($pagesize, $subdocs, $template, %options);
}


#######################################################################
#
#	Export lists of categories and keywords
#
#######################################################################

sub export_categories {
    my ($this, $doc, $template) = @_;

    my $db = $this->{DB};
    $template->export_arraydata(categories =>
				list Magenta::NormalMgr::Category($doc->id, $db),
				[ qw(name id) ]
			       );
}

sub export_keywords {
    my ($this, $doc, $template) = @_;

    my $db = $this->{DB};
    $template->export_arraydata(keywords =>
				list Magenta::NormalMgr::Keyword($doc->id, $db),
				[ qw(name id) ]
			       );
}





1;
__END__
# Below is the stub of documentation for your module. You better edit it!

=head1 NAME

NormalMgr - Perl extension for blah blah blah

=head1 SYNOPSIS

  use NormalMgr;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for NormalMgr was created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head1 AUTHOR

A. U. Thor, a.u.thor@a.galaxy.far.far.away

=head1 SEE ALSO

perl(1).

=cut



1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

WebObvius::Site::Magenta - Perl extension for blah blah blah

=head1 SYNOPSIS

  use WebObvius::Site::Magenta;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for WebObvius::Site::Magenta, created by h2xs. It looks like the
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
