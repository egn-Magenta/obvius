package Obvius::DocType::VKOversigtsSide;

# $Id$

use strict;
use warnings;

use Obvius;
use Obvius::DocType;

our @ISA = qw( Obvius::DocType );
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub action {
    my ($this, $input, $output, $doc, $vdoc, $obvius) = @_;

    my $prodforside_doctype = $obvius->get_doctype_by_name('VKProduktForside');

    my $result;

    my $kategori = $obvius->get_version_field($vdoc, 'kategori') || '';

    $result = {};

    my $standard_doctype = $obvius->get_doctype_by_name('Standard');
    my $link_doctype = $obvius->get_doctype_by_name('Link');

    my $serier = $obvius->search(
                                ['title', 'seq'],
                                "type IN (" . $standard_doctype->Id . ", " . $link_doctype->Id . ") AND parent = " . $doc->Id,
                                needs_document_fields => ['parent'],
                                public => 1,
                                notexpired => 1,
                                straight_documents_join => 1,
                                order => 'seq, title'
                            ) || [];
    for my $s_vdoc (@$serier) {
        $result->{$s_vdoc->Title} ||= [];
        my $docs = $obvius->search(
                                ['title', 'seq'],
                                "type = " . $prodforside_doctype->Id . " AND parent = " . $s_vdoc->DocId,
                                needs_document_fields => ['parent'],
                                public => 1,
                                notexpired => 1,
                                straight_documents_join => 1,
                                order => 'seq, title'
                        );
        if($docs) {
            $result->{$s_vdoc->Title} = $docs;
        } else {
            delete($result->{$s_vdoc->Title});
        }
    }

    $output->param('result' => $result);

    return OBVIUS_OK;
}

1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Obvius::DocType::VKOversigtsSide - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Obvius::DocType::VKOversigtsSide;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Obvius::DocType::VKOversigtsSide, created by h2xs. It looks like the
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
