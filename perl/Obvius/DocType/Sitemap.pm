package Obvius::DocType::Sitemap;

# $Id$

use strict;
use warnings;

use Obvius;
use Obvius::DocType;

our @ISA = qw( Obvius::DocType );
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub action {
    my ($this, $input, $output, $doc, $vdoc, $obvius) = @_;
    my $depth=$obvius->get_version_field($vdoc, 'Levels') || 2;
    $this->tracer($input, $output, $doc, $vdoc, $obvius) if ($this->{DEBUG});

    $output->param(Obvius_DEPENCIES =>1);
    my $top = $obvius->get_root_document();
    $top = $obvius->get_public_version($top);
    $obvius->get_version_fields($top, [ 'title', 'short_title' ]);
    $top->{SHORT_TITLE} = $top->field('short_title');
    $top->{TITLE} = $top->field('title');
    $top->{NAME} = '';
    my $elements= [];

    add_to_sitemap($top, 0, $depth, $obvius, $elements, '');
    $output->param('sitemap' => $elements);
    $output->param('depth' => $depth);
    return OBVIUS_OK;
}

sub add_to_sitemap{
    my ($vdoc, $level, $depth, $obvius, $elements, $url) = @_;

    #$obvius->get_version_fields($vdoc, ['Title', 'Short_title', 'Seq']);
    #return if ($vdoc->Seq < 0);

    my $title= $vdoc->{SHORT_TITLE} || $vdoc->{TITLE};
    my $uri = $url . $vdoc->{NAME} . '/';
    my $seq = $vdoc->{SEQ};

    my $element = {
                    'title' => $title,
                    'url'   => $uri,
                    'level' => $level,
                    'seq'   => $seq,
                };

    push (@$elements, $element) if($level); # Don't include root doc.

    return if ($level++ >= $depth); # HER BLIVER TESTEN UDFØRT

    my $subdocs = $obvius->search(
                                [ 'title', 'short_title', 'seq' ],
                                "(seq >= 0 AND parent = " . $vdoc->DocId . ")",
                                needs_document_fields => [ 'parent', 'name' ],
                                straight_documents_join => 1,
                                public => 1,
                                notexpired => 1,
                                sortvdoc => $vdoc
                            ) || [];

    # XXX modifying the element we have already pushed onto @$elements
    # We can do this because $element is a reference
    $element->{subdocs_marker} = 1 if scalar(@$subdocs);

    for (@$subdocs)
    {
        add_to_sitemap($_, $level, $depth, $obvius, $elements, $uri);
    }
    return;
}


1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Obvius::DocType::Sitemap - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Obvius::DocType::Sitemap;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Obvius::DocType::Sitemap, created by h2xs. It looks like the
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
