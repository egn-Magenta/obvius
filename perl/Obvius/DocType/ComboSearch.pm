package Obvius::DocType::ComboSearch;

use 5.006;
use strict;
use warnings;

use Obvius;
use Obvius::DocType;

use Obvius::DocType::ComboSearch::Parser qw(combo_search_parse);
#use Magenta::NormalMgr::Util::ComboSearch qw(combo_search_parse);

#use Data::Dumper;

our @ISA = qw( Obvius::DocType );
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;


sub action {
    my ($this, $input, $output, $doc, $vdoc, $obvius) = @_;

    $this->tracer($input, $output, $doc, $vdoc, $obvius) if ($this->{DEBUG});

    my $is_admin = $input->param('IS_ADMIN');

    $obvius->get_version_fields($vdoc);
    $obvius->get_version_fields($vdoc, [ 'search_expression' ]);

    my $program = $vdoc->Search_expression;
    $program =~ s/\r//g;
    unless ($program) {
	$output->param(error_message=>'Empty search expression');
	return OBVIUS_OK;
    }

    $obvius->log->debug("ComboSearch: >>>$program<<<<");

    $program =~ s/^.*?\@search\b//s;
    $program =~ s/\@end\b.*$//s;

    my $find_all = ($input->param('IS_ADMIN'));

    my $db = $this->{DB};
    my ($where, @fields) = combo_search_parse($program);

    unless ($where) {
	$output->param(error_message=>"Couldn't parse search expression");
	return OBVIUS_OK;
    }

    my %extra_search_options;

    # Remove version and document fields from the field list
    my %versionfields = (
                            'version' => 1,
                            'doctype' => 1, # Which is mapped to type (the db-fieldname) below
                            'public' => 1,
                            'valid' => 1,
                            'lang' => 1,
                        );
    my %parentfields = (
                            'id' => 1,
                            'parent' => 1,
                            'owner' => 1,
                            'grp' => 1
                        );

    my @needed_parent_fields;

    my @search_fields;
    for my $field (@fields) {
        unless($versionfields{lc($field)}) {
            if($parentfields{lc($field)}) {
                push(@needed_parent_fields, $field);
            } else {
                push(@search_fields, $field);
            }
        }
    }

    if(scalar(@needed_parent_fields)) {
        # Add the document fields to the search
        $extra_search_options{needs_document_fields} = \@needed_parent_fields;
        # If we are searching on something in documents it's a good idea to use straight_documents_join
        $extra_search_options{straight_documents_join} = 1;
    }

    # doctype is actually type:
    #print STDERR "WHERE1: $where\n";
    $where =~ s/([^\w])doctype(\s?)([^\w]+)(\s?)['\"]([^'\"]+)['\"]/$this->doctypemap($1, $2, $3, $4, $5, $obvius)/egi;
    $obvius->log->debug("ComboSearch: WHERE2: $where");

    # Doublecheck search_fields. Make sure we actually have a vfield for each.
    for(@search_fields) {
        unless($obvius->get_fieldspec($_)) {
            $output->param(error_message=>"Invalid search on nonexistent vfield $_");
            return OBVIUS_OK;
        }
    }

    $output->param(Obvius_DEPENCIES => 1);
    # nothidden, notexpired, public
    my $vdocs = $obvius->search(\@search_fields, $where,
			      sortvdoc=>$vdoc,
			      notexpired=>!$is_admin,
			      public=>!$is_admin,
			      %extra_search_options
			     );

    #print STDERR "vdoc: " . Dumper($vdoc);
    #print STDERR "search-result: " . Dumper($vdocs);
    unless ($vdocs) {
        return OBVIUS_OK;
    }

    # This is handled by search when public is 1!
    #my @vdocs=grep { $obvius->is_public_document($obvius->get_doc_by_id($_->Docid)) } @$vdocs;
    #$vdocs=\@vdocs;

    #my %docopts = $doc->document_options;
    $obvius->get_version_field($vdoc, 'pagesize');
    my $require = ($obvius->get_version_field($vdoc, 'require') ? $vdoc->Require : '');

    if ($vdoc->Pagesize) {
	my $page = $input->param('p') || 1;
	$this->export_paged_doclist($vdoc->Pagesize, $vdocs, $output, $obvius,
				    name=>'kwdocs', page=>$page,
				    #prefix => $prefix,
				    require=>$require,
                                    include_images=>1,
				   );
    } else {
	$this->export_doclist($vdocs,  $output, $obvius,
			      name=>'kwdocs',
			      #prefix => $prefix,
			      require=>$require,
                              include_images=>1,
			     );
    }

    return OBVIUS_OK;
}


1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Obvius::DocType::ComboSearch - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Obvius::DocType::ComboSearch;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Obvius::DocType::ComboSearch, created by h2xs. It looks like the
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
