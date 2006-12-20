package Obvius::DocType::DocStats;

# $Id$

use strict;
use warnings;

use Obvius;
use Obvius::DocType;

our @ISA = qw( Obvius::DocType );
our ( $VERSION ) = '$Id$ ' =~ /\$Revision:\s+([^\s]+)/;

sub action
{
	my ( $this, $input, $output, $doc, $vdoc, $obvius) = @_;

	$this-> tracer( $input, $output, $doc, $vdoc, $obvius) if $this->{DEBUG};

	my $dbh = $obvius-> dbh;

	my $all    = $dbh-> selectrow_array( 
		"SELECT count(*) FROM documents" 
	);
	my $public = $dbh-> selectrow_array( 
		"SELECT count(*) FROM versions WHERE public = 1" 
	);
	my $en     = $dbh-> selectrow_array( 
		"SELECT count(*) FROM versions WHERE public = 1 AND lang = ?", {}, 'en');
	my $da     = $dbh-> selectrow_array( 
		"SELECT count(*) FROM versions WHERE public = 1 AND lang = ?", {}, 'da'
	);

	$output-> param( count_all    => $all);
	$output-> param( count_public => $public);
	$output-> param( count_en     => $en);
	$output-> param( count_da     => $da);

	return OBVIUS_OK;
}


1;

=pod

=head1 NAME

Obvius::DocType::DocStats - collect and display count of documents by various criteria

=cut
