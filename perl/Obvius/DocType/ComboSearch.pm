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
our $VERSION="1.0";


sub action {
    my ($this, $input, $output, $doc, $vdoc, $obvius) = @_;

    $this->tracer($input, $output, $doc, $vdoc, $obvius) if ($this->{DEBUG});

    my $session = $input->param('session') || {};
    my $sesdocs = $session->{docs};

    if($sesdocs and scalar(@$sesdocs)) {
        # Carry on session ID
        $output->param('SESSION_ID' => $session->{_session_id}) if($session->{_session_id});

        my $pagesize = $session->{pagesize};
        my $require = $session->{require};
        if($pagesize) {
            my $page = $input->param('p') || 1;
            $this->export_paged_doclist($pagesize, $sesdocs, $output, $obvius,
                                        name=>'kwdocs',
                                        page=>$page,
                                        require=>$require,
                                        include_images=>1,
                                    );
        } else {
            $this->export_doclist($sesdocs,  $output, $obvius,
                                    name=>'kwdocs',
                                    #prefix => $prefix,
                                    require=>$require,
                                    include_images=>1,
                        );
        }

        return OBVIUS_OK;
    }

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

    # Handle overriding repeatable fields
    my %no_repeatable;
    if($program =~ m!^force_no_repeatable=(.*)$!m) {
        my $no_repeatable = $1;
        $no_repeatable =~ s/^\s*//;
        $no_repeatable =~ s/\s*$//;
        for(split(/\s*,\s*/, $no_repeatable)) {
            $no_repeatable{$_} = 1;
        }
    }

    my %extra_search_options;

    # Handle breaking of site root
    if($program =~ m!^break_siteroot!m) {
        $extra_search_options{break_siteroot} = 1;
        $output->param('break_siteroot' => 1);
    }

    $program =~ s/^.*?\@search\b//s;
    $program =~ s/\@end\b.*$//s;

    my $find_all = ($input->param('IS_ADMIN'));

    my $db = $this->{DB};
    my ($where, @fields) = combo_search_parse($program);

    unless ($where) {
	$output->param(error_message=>"Couldn't parse search expression");
	return OBVIUS_OK;
    }

    # Remove version and document fields from the field list
    my %versionfields = (
                            'version' => 1,
                            'doctype' => 1, # Which is mapped to type (the db-fieldname) below
                            'public' => 1,
                            'valid' => 1,
                            'lang' => 1,
                            'path' => 1, # Not exactly a version field, but it is available for searches in newer versions of Obvius
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
    }

    # doctype is actually type:
    $where =~ s/([^\w])doctype(\s?)([^\w]+)(\s?)[\'\"]([^\'\"]+)[\'\"]/$this->doctypemap($1, $2, $3, $4, $5, $obvius)/egi;
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
			      override_repeatable => \%no_repeatable,
			      %extra_search_options,
			     );

    unless ($vdocs) {
        return OBVIUS_OK;
    }

    # If the search was on repeatable fields and the conditions
    # thereupon were negated (NOT IN, !=, NOT LIKE, other?), Obvius::search
    # returns to much.
    #
    # For example: the search X NOT IN (A, B) on:
    #
    #  docid version field value
    #    N      M      X     A
    #    N      M      X     B
    #    N      M      X     C
    #
    # includes (N, M) in the resultset, which is natural given how the
    # database works, but it's not what is expected.
    #
    # How can we fix this? Well, since Obvius::search() gives us all
    # the correct results, plus some extra, we can get the right
    # results by filtering away the false positives.
    #
    # (It could be argued that this should be fixed generally in
    # Obvius::search(), and I tend to agree, but I'd rather start it
    # off here, as we have a nice parsetree to work from, making it
    # much easier to filter here than to parse the where-expression
    # that Obvius::search takes and parsing that to do extra
    # filtering).
    #
    # We only do the filtering if we are searching on at least one
    # repeatable field:
    my $repeatable=scalar(grep {
        my $fspec=$obvius->get_fieldspec($_);
        $fspec ? $fspec->Repeatable : 0 } @search_fields);

    if ($repeatable) {
        my $parser=Obvius::DocType::ComboSearch::Parser->new();
        my $tree = $parser->parse($program);
        my $filtered_vdocs=filter_result($vdocs, $tree, $obvius);

        # We need to keep the ordering, so we use the filtered_docs as
        # a filter (slight sigh):
        if (scalar(@$filtered_vdocs)!=scalar(@$vdocs)) {
            my %still_there=map { $_->Docid . ':' . $_->Version => 1 } @$filtered_vdocs;
            my @new_vdocs=(grep { $still_there{$_->Docid . ':' . $_->Version} } @$vdocs);

            $vdocs=\@new_vdocs;
        }
    }

    # This is handled by search when public is 1!
    #my @vdocs=grep { $obvius->is_public_document($obvius->get_doc_by_id($_->Docid)) } @$vdocs;
    #$vdocs=\@vdocs;

    #my %docopts = $doc->document_options;
    $obvius->get_version_fields($vdoc, ['pagesize', 'require']);
    my $require = $vdoc->field('Require') || '';

    my $pagesize = $vdoc->field('pagesize') || 0;

    if ($pagesize) {
        my $page = $input->param('p') || 1;
        $this->export_paged_doclist($pagesize, $vdocs, $output, $obvius,
                                    name=>'kwdocs', page=>$page,
                                    require=>$require,
                                    include_images=>1,
                                    break_siteroot => $extra_search_options{break_siteroot},
                                );
    } else {
        $this->export_doclist($vdocs,  $output, $obvius,
                                name=>'kwdocs',
                                require=>$require,
                                include_images=>1,
                                break_siteroot => $extra_search_options{break_siteroot},
                            );
    }

    # Store stuff in session
    $session->{docs} = $vdocs;
    $session->{pagesize} = $pagesize;
    $session->{require} = $require;
    $output->param('session' => $session);

    return OBVIUS_OK;
}

# filter_result - given an array-ref to version-objects and an
#                 array-ref to a combosearch parse-tree, performs an
#                 extra pruning of the version-objects handling some
#                 of the the parse-tree restrictions that
#                 Obvius::search can't ("negative" operations on
#                 repeatable fields).
sub filter_result {
    my ($vdocs, $tree, $obvius)=@_;

    my @all_vdocs=@$vdocs;

    return do_filter_result(\@all_vdocs, $tree, $obvius);
}

sub do_filter_result {
    my ($result, $tree, $obvius)=@_;

    my $op=shift @$tree;
    if ($op eq 'OR') {
        return or_result($result, $tree, $obvius);
    }
    elsif ($op eq 'AND') {
        return and_result($result, $tree, $obvius);
    }
    else {
        my ($field, $arg)=@$tree;

        my $fieldspec=$obvius->get_fieldspec($field);
        if (!defined $fieldspec) {
            # No fieldspec, assuming non-repeatable; don't care:
            return $result
        }
        if (defined $fieldspec and !$fieldspec->Repeatable) {
            # Not repeatable, we don't care about it:
            return $result;
        }

        # HANDLE some ops manually when the field is repeatable:
        #  NOT IN and != are handled, the others are ignored:
        #  (> and < do not make a whole lot of sense for repeatables...)
        if ($op eq 'LIKE' or $op eq 'IN' or $op eq '=' or $op eq '>' or $op eq '<') {
            # op is a boring op, we don't care:
            return $result;
        }
        elsif ($op eq 'NOT IN') {
            return not_in($result, $field, $arg, $obvius);
        }
        elsif ($op eq '!=') {
            return not_in($result, $field, $arg, $obvius);
        }
        # XXX TODO: handle 'NOT LIKE'
        else {
            print STDERR "ComboSearch::do_filter_result: unknown op $op; fix me!\n";
            return $result;
        }
    }
}

sub not_in_test {
    my ($arg, $value)=@_;

    my %not=map { $_=>1 } split /\|/, $arg;
    my $res=grep { $not{$_->Id} } @$value;

    return ($res ? 0 : 1);
}

sub not_in {
    my ($vdocs, $field, $arg, $obvius)=@_;

    my @new_result=();
    foreach my $vdoc (@$vdocs) {
        my $value=$obvius->get_version_field($vdoc, $field);
        push @new_result, $vdoc if (not_in_test($arg, $value));
    }

    return \@new_result;
}

sub or_result {
    my ($result, $tree, $obvius)=@_;

    my %new_result=();
    foreach my $node (@$tree) {
        my $node_result=do_filter_result($result, $node, $obvius);
        foreach my $vdoc (@$node_result) {
            $new_result{$vdoc->Docid . ':' . $vdoc->Version}=$vdoc;
        }
    }

    return [ map { $new_result{$_} } keys %new_result ];
}

sub and_result {
    my ($result, $tree, $obvius)=@_;

    my %objects=();
    my %count=();
    my $numnodes=0;
    foreach my $node (@$tree) {
        $numnodes++;
        my $node_result=do_filter_result($result, $node, $obvius);
        foreach my $vdoc (@$node_result) {
            # Check node_result-type!
            # http://euo.rovereto.magenta-aps.dk/euo_ensubjects/consumer-health/
            $objects{$vdoc->Docid . ':' . $vdoc->Version}=$vdoc;
            $count{$vdoc->Docid . ':' . $vdoc->Version}++;
        }
    }

    return [ map { $objects{$_} } grep { $count{$_}==$numnodes } keys %count ];
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
