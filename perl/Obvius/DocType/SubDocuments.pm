package Obvius::DocType::SubDocuments;

# $Id$

use strict;
use warnings;

use Obvius;
use Obvius::DocType;

our @ISA = qw( Obvius::DocType );
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub action {
    my ($this, $input, $output, $doc, $vdoc, $obvius) = @_;

    my $prefix = $output->param('PREFIX');
    my $is_admin = $input->param('IS_ADMIN');

    my $subdocs;

    $output->param(Obvius_DEPENCIES => 1);
# Sorting is important:
#    if ($is_admin) {
#	$subdocs=[map { $obvius->get_public_version($_) or
#			$obvius->get_latest_version($_) } @{$obvius->get_docs_by_parent($doc->Id)}];
#    }
#    else {
	$subdocs=$obvius->get_document_subdocs($doc, sortvdoc=>$vdoc);
#    }

    if ($subdocs) {
	if ($obvius->get_version_field($vdoc, 'pagesize')) {
	    my $page = $input->param('p') || 1;
	    $this->export_paged_doclist($vdoc->Pagesize, $subdocs, $output, $obvius,
				    	name=>'subdocs', page=>$page,
				    	prefix => $prefix,
				    	require=>'fullinfo',
				       );
    	} else {
	    $this->export_doclist($subdocs,  $output, $obvius,
				  name=>'subdocs',
				  prefix => $prefix,
				  require=>'fullinfo',
				 );
	}
    }

    return OBVIUS_OK;
}

sub alternate_location {
    my ($this, $doc, $vdoc, $obvius) = @_;

    $this->tracer($doc, $vdoc, $obvius) if ($this->{DEBUG});

    $obvius->get_version_fields($vdoc);

    my $url = $vdoc->field('url');
    return undef unless ($url);

    my $content = $vdoc->field('content');
    return (defined $content and length($content) == 0) ? $url : undef;
}

1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Obvius::DocType::SubDocuments - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Obvius::DocType::SubDocuments;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Obvius::DocType::SubDocuments, created by h2xs. It looks like the
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
