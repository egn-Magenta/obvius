package Obvius::DocType::HvadMenerDe;

# $Id$

use strict;
use warnings;

use Obvius;
use Obvius::DocType;

use Data::Dumper;

our @ISA = qw( Obvius::DocType );
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub action {
    my ($this, $input, $output, $doc, $vdoc, $obvius) = @_;

    $obvius->get_version_fields($vdoc, ['start_uri', 'search_phrase', 'storage_folder']);
    my $start_uri = $vdoc->Start_uri;
    my $search_phrase = $vdoc->Search_Phrase;
    my $storage_folder_name = $vdoc->Storage_Folder;

    my $start_doc = $obvius->lookup_document($start_uri);
    unless($start_doc) {
        $output->param(error => 'No start document');
        return OBVIUS_OK;
    }

    my $root_parents = $obvius->search(['title', 'seq'], "parent = " . $start_doc->Id,
                                public => 1,
                                notexpired => 1,
                                nothidden => 1,
                                needs_document_fields => ['parent'],
                                order => 'seq');

    my @result;
    if($root_parents) {
        for(@$root_parents) {
            # Get some info about the root parent
            my $root_parent_title = $obvius->get_version_field($_, 'title');

            # Find the "folder" to search in
            my $parent_doc;
            if($storage_folder_name) {
                # new solution - storage_folder_name is part of the documents title
                my $docs = $obvius->search(
                                            [ 'title' ],
                                            "title LIKE '%" . $storage_folder_name . "%' AND parent = " . $_->DocId,
                                            public => 1,
                                            needs_document_fields => ['parent']
                                    ) || [];
                $parent_doc = $obvius->get_doc_by_id($docs->[0]->DocId) if($docs->[0]);

                # Old solution - storage_folder_name is the URI name..
                #$parent_doc = $obvius->get_doc_by_name_parent($storage_folder_name, $_->DocId);
            }
            next unless($parent_doc);

            #Old sulution - search under the root doc itself - doesn't work.
            #$parent_doc = $obvius->get_doc_by_id($_->DocId) unless($parent_doc);

            # Find the the actual vdoc, we want
            my $vdoc = $obvius->search(
                                        ['title'],
                                        "parent = " . $parent_doc->Id . " AND title LIKE '%" . $search_phrase . "%'",
                                        public => 1,
                                        notexpired => 1,
                                        nothidden => 1,
                                        needs_document_fields => ['parent']);
            next unless($vdoc);


            my $root_parent_doc = $obvius->get_doc_by_id($_->DocId);
            my $root_parent_uri = $obvius->get_doc_uri($root_parent_doc);

            $vdoc = shift(@$vdoc); # Get the first
            my $content = $obvius->get_version_field($vdoc, 'content');
            push(@result, {
                            root_parent_title => $root_parent_title,
                            content => $content,
                            url => $root_parent_uri
                        });
        }
    }
    $output->param(result => \@result);
    return OBVIUS_OK;
}

1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Obvius::DocType::HvadMenerDe - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Obvius::DocType::HvadMenerDe;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Obvius::DocType::HvadMenerDe, created by h2xs. It looks like the
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
