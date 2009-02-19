package Obvius::DocType::DBSearch;
# $Id$

use strict;
use warnings;

use Obvius;
use Obvius::Data;
use Obvius::DocType;

use Carp;

our @ISA = qw( Obvius::DocType );
our $VERSION="1.0";

sub action {
    my ($this, $input, $output, $doc, $vdoc, $obvius) = @_;

    $output->param(Obvius_SIDE_EFFECTS => 1);
    my $session = $input->param('SESSION');

    unless ($session->{docs} and @{$session->{docs}}) {

        my $op = $input->param('op');
        unless($op and $op eq 'dbsearch') {
	    $output->param('start'=>1);
	    return OBVIUS_OK;
	}

        #OK, now start out with an empty session
        $session = {};

        my %how_map = (
                    'equal' => '=',
                    'not-equal' => '!=',
                    'less-than' => '<',
                    'greater-than' => '>',
                    'less-than-equal' => '<=',
                    'greater-than-equal' => '<=',
                    'like' => 'LIKE',
                    'not-like' => 'NOT LIKE',
                    'prefix' => [ 'LIKE', '%s%%' ],
                    'not-prefix' => [ 'NOT LIKE', '%s%%' ],
                    'contain' => [ 'LIKE', '%%%s%%' ],
                    'not-contain' => [ 'NOT LIKE', '%%%s%%' ],
                    );
        my %sort_map = (
                    'docdate' => 'docdate DESC',
                    'version' => 'version DESC',
                    'title' => 'title'
                    );

        my $where = '';
        my @fields;

        for my $i (1..9) {
            my $data = $input->param("data$i");
            if (defined($data) and $data ne '') {
                my $line;

                my $op = uc($input->param("op$i") || '');
                my $how = $input->param("how$i") || 'equal';
                my $field = $input->param("field$i") || 'title';

                if (defined $how_map{$how}) {
                    $how = $how_map{$how};
                    if (ref $how) {
                        $data = sprintf($how->[1], $data);
                        $how = $how->[0];
                    }
                } elsif ($how eq 'one-of') {
                    my $list = $input->param("data$i");
                    $list = [ "$list" ] unless(ref($list) eq 'ARRAY');
                    $data = "(\'" . join("\',\'", @$list) . "\')";
                    $how = 'IN';
                } else {
                    warn "Unknown how$i: \"$how\", skipping $i";
                    next;
                }

                $op = '' unless ($where);

                unless($how eq 'IN'){
                    $data =~ s/'/\\'/g;
                    $data = "\'" . $data . "\'"
                }

                # $field can be a list of fields, where either one of them can match:
                my @field_list=split /\s*,\s*/, $field;
                foreach (@field_list) {
                    my $fieldspec=$obvius->get_fieldspec($_);
                    if ($fieldspec) {
                        # If it is optional, add a '~', meaning "use
                        # left join".  I wonder why Obvius::search
                        # can't figure this out for itself...
                        push(@fields, ($fieldspec->Optional ? '~' : '') . $_);
                    }
                }
                # XXX Had to add an extra space here (before
                # $how). Guess something is wrong with some regexps in
                # $obvius->search():
                my $where_list=join " OR ", (map { "($_  $how $data)" } @field_list);
                $where = "(" . $where . "$op ( $where_list ) ) ";
            }
        }

        my $sortorder = $input->param('sortorder');

        my $sort_sql = $sort_map{$sortorder} || $sortorder;

        push(@fields, $sortorder) if($sort_sql
                                    and ! grep{$_ eq $sortorder} @fields
                                    and $obvius->get_fieldspec($sortorder));

        my $is_admin = $input->param('IS_ADMIN');

	# Remove version and document fields from the field list
	my @versionfields = (
			     'version',
			     'doctype', # Which is mapped to type (the db-fieldname) below
			     'public',
			     'valid',
			     'lang',
			    );

	# This is duplicated from Combosearch:
	my @search_fields;
	for my $field (@fields) {
	    unless(grep { lc($field) eq lc($_) } @versionfields) {
		push(@search_fields, $field);
	    }
	}

	# doctype is actually type:
	#print STDERR "WHERE1: $where\n";
	$where =~ s/([^\w])doctype(\s?)([^\w]+)(\s?)['\"]([^\'\"]+)['\"]/$this->doctypemap($1, $2, $3, $4, $5, $obvius)/egi;
       #print STDERR "WHERE2: $where\n";

	if ($where) {
	    $output->param(Obvius_DEPENCIES => 1);
	    $session->{docs} = $obvius->search(\@search_fields, $where,
					     'order' => $sort_sql,
					     'public' => !$is_admin,
					     'notexpired' => !$is_admin,
					     'nothidden' => 0); # !$is_admin
	}

	# This is handled by search when public is 1!
	#my @vdocs=grep { $obvius->is_public_document($obvius->get_doc_by_id($_->Docid)) } @{$session->{docs}};
	#$session->{docs}=\@vdocs;

        if($session->{docs}) {
            my $format = $input->param('format');
            $session->{require} = ($format eq 'long') ? 'teaser' : '';
            $session->{pagesize} = $input->param('pagesize');

            #save the session on the output object
            $output->param('SESSION' => $session);

        } else {
            $output->param('no_results' => 1);

            #Maintain form state
            my @params = $input->param;
            @params = [] unless(@params);
            for(grep { $_ !~ /^obvius/i } @params) {
                $output->param($_ => $input->param($_));
            }
            return OBVIUS_OK;
        }
    }

    # We should always have a session here, either from the input object
    # or the one we made during the search (the search should return if
    # if found nothing.
    croak("No session in Obvius::DocType::DBSearch\n") unless($session);

    if ($session->{docs} and $session->{pagesize}) {
        my $page = $input->param('p') || 1;
        $this->export_paged_doclist($session->{pagesize}, $session->{docs}, $output, $obvius,
                                    name=>'kwdocs', page=>$page,
                                    #prefix => $prefix,
                                    require=>$session->{require},
                                );
    } else {
        $this->export_doclist($session->{docs},  $output, $obvius,
                            name=>'kwdocs',
                            #prefix => $prefix,
                            require=>$session->{require},
                        );
    }

    #make sure we have a session_id
    $output->param('SESSION_ID' => $session->{_session_id}) if($session->{_session_id});

    return OBVIUS_OK;
}

1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Obvius::DocType::DBSearch - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Obvius::DocType::DBSearch;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Obvius::DocType::DBSearch, created by h2xs. It looks like the
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
