package Obvius::UriCache;

use strict;
use warnings;

our $VERSION="1.0";


sub remove_from_uricache {
    my ($this, $doc) = @_;

    my $set=DBIx::Recordset->SetupObject(
                                            {
                                                '!DataSource' => $this->{DB},
                                                '!Table'     => 'uri_cache',
                                            }
                                        );
    $set->Delete({docid => $doc->Id});

}

sub add_to_uricache {
    my ($this, $doc) = @_;

    my $set=DBIx::Recordset->SetupObject(
                                            {
                                                '!DataSource' => $this->{DB},
                                                '!Table'     => 'uri_cache',
                                            }
                                        );

    my $uri = $this->get_doc_uri($doc, break_siteroot => 1);

    my $uri_copy = $uri;

    my ($path1, $path2, $path1_id, $path2_id);

    # Get first part of the URI
    if($uri_copy =~ s!^/([^/]+)!!) {
        $path1 = $1;

        my $path1doc = $this->lookup_document("/$path1/", break_siteroot => 1);
        $path1_id = $path1doc->Id;


        # Get second part of the URI
        if($uri_copy =~ s!^/([^/]+)!!) {
            $path2 = $1;

            my $path2doc = $this->lookup_document("/$path1/$path2/", break_siteroot => 1);
            $path2_id = $path2doc->Id;
        }
    }

    $set->Insert(
                    {
                        docid => $doc->Id,
                        uri => $uri,
                        path_part1 => $path1,
                        path_part2 => $path2,
                        path_part1_id => $path1_id,
                        path_part2_id => $path2_id
                    }
                );
}

sub search_uricache {
    my ($this, $where) = @_;

    my $set=DBIx::Recordset->SetupObject(
                                            {
                                                '!DataSource' => $this->{DB},
                                                '!Table'     => 'uri_cache',
                                            }
                                        );

    $set->Search($where);

    my @result;

    while(my $rec = $set->Next) {
        push(@result, $rec);
    }

    return \@result;
}

sub rebuild_uricache {
    my($this) = @_;

    my $docs = $this->get_docs_by();
    for(@$docs) {
        $this->remove_from_uricache($_);
        $this->add_to_uricache($_);
    }
}

sub rebuild_uricache_for_uri {
    my ($this, $uri) = @_;

    my $entries = $this->search_uricache( {uri => $uri} ) || [];

    for(@$entries) {
        my $doc = $this->get_doc_by_id($_->{docid});
        $this->rebuild_uricache_for_doc($doc) if($doc);
    }

}

sub rebuild_uricache_for_uri_recursive {
    my ($this, $uri) = @_;

    my $entries = $this->search_uricache("uri LIKE '$uri\%'") || [];

    for(@$entries) {
        my $doc = $this->get_doc_by_id($_->{docid});
        $this->rebuild_uricache_for_doc($doc) if($doc);
    }

}

sub rebuild_uricache_for_doc {
    my ($this, $doc) = @_;

    $this->remove_from_uricache($doc);
    $this->add_to_uricache($doc);

}
1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Obvius::UriCache - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Obvius::UriCache;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Obvius::UriCache, created by h2xs. It looks like the
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
