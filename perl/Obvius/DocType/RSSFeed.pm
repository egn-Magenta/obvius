package Obvius::DocType::RSSFeed;

########################################################################
#
# RSSFeed.pm - Document type for creating RSS feeds in Obvius
#
# Copyright (C) 2005 Magenta Aps, Denmark (http://www.magenta-aps.dk/)
#
# Author: Martin Skøtt (martin@magenta-aps.dk)
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2, or (at your option)
# any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software Foundation,
# Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
#
########################################################################

# $Id$

use 5.006;
use strict;
use warnings;

use Obvius;
use Obvius::Data;
use Obvius::DocType;
use Obvius::DocType::ComboSearch;

use XML::RSS;
use Unicode::String qw(utf8 latin1);

our @ISA = qw( Obvius::DocType );
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;;

# raw_document_data - Returns raw XML data plus the correct mimetype
sub raw_document_data {
    my ($this, $doc, $vdoc, $obvius, $input) = @_;

	my $rss = new XML::RSS (version => '1.0');
	my $sitename = "http://" . $obvius->{OBVIUS_CONFIG}->param('sitename');

	$rss->channel(link => $sitename);
	#Mapping of $vdoc fields to RSS equivalents
	my %field_map = (
				   'title' => 'title',
				   'teaser' => 'description'
				   );

	$obvius->get_version_fields($vdoc, [keys(%field_map)]);
	foreach my $field (keys(%field_map)) {
		$rss->channel($field_map{$field} => $vdoc->field($field));
	}

	#Put Dublin core information on the feed itself...
	my %dc_field_map = (
						'docdate' => 'date',
						'teaser' => 'description'
						);

	$obvius->get_version_fields($vdoc, [keys (%dc_field_map)]);
	my %feed_dc;
	foreach my $field (keys(%dc_field_map)) {
		$feed_dc{ $dc_field_map{$field}} = $vdoc->field($field);
	}
	$feed_dc{'lang'} = $vdoc->param('lang') || 'da';
	$rss->channel(dc => \%feed_dc);

	#Fetch items using the ComboSearch doctype
	my $doctype = $obvius->get_version_type($vdoc);
	my $fake_output = new Obvius::Data;
	my $fake_input = new Obvius::Data;	
	my $search = $obvius->get_doctype_by_name('ComboSearch');

	$search->action($fake_input,$fake_output,$doc,$vdoc,$obvius);

	#Insert search results into RSS feed
	foreach my $result_vdoc (@{$fake_output->{SESSION}->{docs}}) {
		my $result_doc = $obvius->get_doc_by_id($result_vdoc->DocId);
		my $url = $sitename . $obvius->get_doc_uri($result_doc);
		$obvius->get_version_fields($result_vdoc, [qw (teaser docdate)]);

		#Construct item DC information
		$obvius->get_version_fields($result_vdoc, [keys(%dc_field_map)]);
		my %item_dc;
		foreach my $field (keys(%dc_field_map)) {
			$item_dc{ $dc_field_map{$field}} = $result_vdoc->field($field);
		}
		$item_dc{'lang'} = $result_vdoc->param('lang') || 'da';
		
		$rss->add_item(
					   title => $result_vdoc->field('title'),
					   link => $url,
					   description => $result_vdoc->field('teaser'),
					   dc => \%item_dc
					   );
	}

	my $rss_string = latin1($rss->as_string)->utf8;
	return ('text/xml; charset=utf-8', $rss_string);
}


1;
__END__

=head1 NAME

Obvius::DocType::RSSFeed - Perl module for the RSSFeed doctype

=head1 SYNOPSIS

  use Obvius::DocType::RSSFeed;
  blah blah blah

=head1 DESCRIPTION

This is the perl module of the document type RSSFeed. The document type enables you to 
provide RSS feeds from your Obvius site.

Blah blah blah.

=head2 EXPORT

None by default.


=head1 AUTHOR

Martin Skøtt, E<lt>martin@magenta-aps.dkE<gt>

=head1 SEE ALSO

L<perl>.

=cut
