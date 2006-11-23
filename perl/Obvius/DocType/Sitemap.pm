package Obvius::DocType::Sitemap;

# $Id$

use strict;
use warnings;

use Obvius;
use Obvius::DocType;

our @ISA = qw( Obvius::DocType );
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub action
{
	my ( $this, $input, $output, $doc, $vdoc, $obvius) = @_;

	$this-> tracer($input, $output, $doc, $vdoc, $obvius) if $this->{DEBUG};

	my $depth      = $obvius-> get_version_field( $vdoc, 'levels') || 2;
	my $public     = $obvius-> get_version_field( $vdoc, 'show_unpublished') ? 0 : 1;
	my $notexpired = $obvius-> get_version_field( $vdoc, 'show_expired')     ? 0 : 1;
	my $nothidden  = $obvius-> get_version_field( $vdoc, 'show_hidden')      ? 0 : 1;
	my $root       = $obvius-> get_version_field( $vdoc, 'root');

	my $top;
	if ( $root and $root ne '/') {
		$top = $obvius-> lookup_document( $root);
		chop $root;
	} else {
		$top = $obvius-> get_root_document();
		$root = ''; # Needed if $root was /
	}
	$top = $obvius-> get_public_version( $top);

	unless ( $top) {
		# Something is wrong with $top, tell the user
		$output-> param( message => 'INVALID_ROOT');
		return OBVIUS_ERROR;
	}

	$obvius-> get_version_fields($top, [ qw(title short_title) ]);
	$top-> {SHORT_TITLE} = $top->field('short_title');
	$top-> {TITLE}       = $top->field('title');
	$top-> {NAME}        = '';

	my $root_map = add_to_sitemap( 
		$top, 0, $depth, $obvius, $root, 
		$public, $notexpired, $nothidden
	);

	$output-> param( sitemap => $root_map-> {down} || [] ); # skip the root itself
	$output-> param( depth   => $depth);

	return OBVIUS_OK;
}

sub add_to_sitemap
{
	my ($vdoc, $level, $depth, $obvius, $url, $public, $notexpired, $nothidden) = @_;

	my $uri = $url . $vdoc->{NAME} . '/';

	my $ret = {
		title => $vdoc-> {SHORT_TITLE} || $vdoc-> {TITLE},
		url   => $uri,
		seq   => $vdoc-> {SEQ},
	};
	
	return $ret if $level++ >= $depth;

	my $subdocs = $obvius-> search(
		[ qw(title short_title seq) ],
		"parent = " . $vdoc-> DocId,
		needs_document_fields   => [ qw(parent name) ],
		straight_documents_join => 1,
		public                  => $public,
		notexpired              => $notexpired,
		nothidden               => $nothidden,
		sortvdoc                => $vdoc
	);

	$ret-> {down} = [ map {
		add_to_sitemap( $_, $level, $depth, $obvius, $uri, $public, $notexpired, $nothidden)
	} @$subdocs ] if $subdocs;

	return $ret;
}

1;
