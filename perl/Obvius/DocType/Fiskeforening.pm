package Obvius::DocType::Fiskeforening;

use strict;
use warnings;

use Obvius;
use Obvius::DocType;

our @ISA = qw( Obvius::DocType );
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub action {
    my ($this, $input, $output, $doc, $vdoc, $obvius) = @_;

    my $uri = $obvius->get_doc_uri($doc);
    my $nyheds_uri = $uri . "nyheder/";
    my $arrangement_uri = $uri . "arrangementer/";

    my $nyheder = $this->get_subdocs($obvius, $nyheds_uri);
    $output->param('nyheder'=>$nyheder);

    my $arrangementer = $this->get_subdocs($obvius, $arrangement_uri);
    $output->param('arrangementer'=>$arrangementer);

    return OBVIUS_OK;
}

sub get_subdocs {
    my ($this, $obvius, $url) = @_;

    my @doc = $obvius->get_doc_by_path($url);
    return undef unless @doc;

    my $docid = $doc[-1]->{'ID'};

    my $subdocs = $obvius->search(['title', 'seq', 'docdate'],
				" parent = " . $docid,
				public => 1,
				notexpired => 1,
				nothidden => 1,
				needs_document_fields => ['parent'],
				order => 'docdate desc ');

    my @subdocs;

    for (@$subdocs) {
	my $doc = $obvius->get_doc_by_id($_->DocId);
	my $uri = $obvius->get_doc_uri($doc);
	my $vdoc = $obvius->get_public_version($doc);
	my $picture = $obvius->get_version_field($vdoc, 'picture');
	my $content = $obvius->get_version_field($vdoc, 'content');

	my $image_height = 0;
	my $image_width = 0;
	if ($picture && $picture ne '/') {
	    my @image_doc = $obvius->get_doc_by_path($picture);
	    my $image_vdoc = $obvius->get_public_version($image_doc[-1]);
	    $obvius->get_version_fields($image_vdoc, [qw(height width)]);
	    $image_width = $image_vdoc->Width;
	    $image_height = $image_vdoc->Height;
	}

	push (@subdocs, {
			 url=>$uri,
			 title=>$_->Title,
			 docdate=>$this->format_docdate($_->Docdate),
			 content=>$content,
			 picture=>$picture || '',
			 image_width => $image_width,
			 image_height => $image_height
			}
	     );
    }
    return \@subdocs;
}

sub format_docdate {
    my ($this, $date) = @_;
    $date =~ s!(\d\d\d\d)-(\d\d)-(\d\d).*!$3/$2 - $1!;
    return $date;
}

1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Obvius::DocType::Fiskeforening - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Obvius::DocType::Fiskeforening;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Obvius::DocType::Fiskeforening, created by h2xs. It looks like the
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
