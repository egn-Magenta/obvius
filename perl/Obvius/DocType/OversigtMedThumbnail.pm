package Obvius::DocType::OversigtMedThumbnail;

# $Id$

use strict;
use warnings;

use Obvius;
use Obvius::DocType;

our @ISA = qw( Obvius::DocType );
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub action {
    my ($this, $input, $output, $doc, $vdoc, $obvius) = @_;

    my $docid = $doc->Id;

    my $thumbsfrom = $obvius->get_version_field($vdoc, 'thumbsfrom') || 'logo';

    my $docs = $obvius->search(
                                ['title', 'teaser', $thumbsfrom, 'url'],
                                "parent = $docid and $thumbsfrom > 0",
                                public => 1,
                                notexpired => 1,
                                nothidden => 1,
                                needs_document_fields => ['parent', 'name'],
                                sortvdoc => $vdoc
                            ) || [];
    my @result;
    for(@$docs) {
        my $pic_docid;
        if($thumbsfrom eq 'logo') {
            $pic_docid = $_->Logo;
        } else {
            $pic_docid = $_->Picture;
        }
        my $picture = $obvius->get_doc_uri($obvius->get_doc_by_id($pic_docid));
        my $url = $_->Url;
        $url =~ s/^www\./http:\/\/www./;
        push(@result, {
                        title => $_->Title,
                        teaser => $_->Teaser,
                        picture => $picture,
                        doclink => $_->Name . '/',
                        link => $url

                    });
    }

    $output->param(result => \@result) if(scalar(@result));

    my $thumbsize = $obvius->get_version_field($vdoc, 'thumbsize') || '24x15';

    my ($thumbwidth, $thumbheight) = split(/x/, $thumbsize);
    $output->param(thumbwidth => $thumbwidth);
    $output->param(thumbheight => $thumbheight);

    return OBVIUS_OK;
}

1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Obvius::DocType::OversigtMedThumbnail - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Obvius::DocType::OversigtMedThumbnail;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Obvius::DocType::OversigtMedThumbnail, created by h2xs. It looks like the
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
