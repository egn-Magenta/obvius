package Obvius::DocType::Forside;

########################################################################
#
# Forside.pm - Forside Document Type
#
# Copyright (C) 2001 Magenta Aps, Denmark (http://www.magenta-aps.dk/)
#
# Author: Adam Sjøgren (asjo@magenta-aps.dk)
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

use strict;
use warnings;

use Obvius;
use Obvius::DocType;

use POSIX qw(strftime);

our @ISA = qw( Obvius::DocType );
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub action {
    my ($this, $input, $output, $doc, $vdoc, $obvius) = @_;

    $obvius->get_version_fields($vdoc, 64);

    my $nyhed_doctype=$obvius->get_doctype_by_name("Nyhed");
    my $artikel_doctype=$obvius->get_doctype_by_name("Artikel");

    my @already_added;

    my $nowdate = strftime('%Y-%m-%d 00:00:00', localtime);
    my $where = "(type=" . $nyhed_doctype->Id . " or type=" . $artikel_doctype->Id . ") and docdate <= \'" . $nowdate . "\'",
    my %search_options =    (
			     notexpired=>1,
			     nothidden=>1,
			     order => 'docdate DESC',
			     public=>1,
			     append=>'limit 10'
			    );

    my $all_docs = $obvius->search([qw(docdate)], 
				 $where,
				 %search_options);

    # den tværgående nyhed
    if (defined $vdoc->Big_news and $vdoc->Big_news ne '/') {
	my $linktop_doc = $obvius->lookup_document($vdoc->Big_news);
	my $linkvdoc;
	$linkvdoc = $obvius->get_public_version($linktop_doc) || $obvius->get_latest_version($linktop_doc) if($linktop_doc);
	$obvius->get_version_fields($linkvdoc, [qw (short_title title teaser content picture author docdate)]);
	
	my $linktop_hash_doc = { 
				title => $linkvdoc->Short_Title ? $linkvdoc->Short_Title : $linkvdoc->Title,
				teaser => $linkvdoc->Teaser || '',
				content => $linkvdoc->Content || '',
				docdate => &convert_date($linkvdoc->DocDate),
				url => $vdoc->Big_news,
				author => (defined $linkvdoc->field('author') ? $linkvdoc->field('author') : ''),
				picture => (defined $linkvdoc->field('picture') ? $linkvdoc->field('picture') : '')
			       };
	$output->param(top_vdoc=>$linktop_hash_doc);
	push (@already_added, $linktop_doc->Id);
    }

    # find nyhederne til venstre på siden
    my @left_news;
    my $already_pushed = 0;
    if (defined $vdoc->News_1 and $vdoc->News_1 ne '/') {
	push_news_item($vdoc->News_1, \@left_news, \@already_added, $obvius);
    } else {
	push_news_item($$all_docs[$already_pushed], \@left_news, \@already_added, $obvius);
	$already_pushed++;
    }

    if (defined $vdoc->News_2 and $vdoc->News_2 ne '/') {
	push_news_item($vdoc->News_2, \@left_news, \@already_added, $obvius);
    } else {
	push_news_item($$all_docs[$already_pushed], \@left_news, \@already_added, $obvius);
	$already_pushed++;
    }

    if (defined $vdoc->News_3 and $vdoc->News_3 ne '/') {
	push_news_item($vdoc->News_3, \@left_news, \@already_added, $obvius);
    } else {
	push_news_item($$all_docs[$already_pushed], \@left_news, \@already_added, $obvius);
	$already_pushed++;
    }

    if (defined $vdoc->News_4 and $vdoc->News_4 ne '/') {
	push_news_item($vdoc->News_4, \@left_news, \@already_added, $obvius);
    } else {
	push_news_item($$all_docs[$already_pushed], \@left_news, \@already_added, $obvius);
	$already_pushed++;
    }

    if (defined $vdoc->News_5 and $vdoc->News_5 ne '/') {
	push_news_item($vdoc->News_5, \@left_news, \@already_added, $obvius);
    } else {
	push_news_item($$all_docs[$already_pushed], \@left_news, \@already_added, $obvius);
    }

    # sørg for at fylde left_news op
    for (my $i = 0; scalar @left_news < 5; $i++) {
	push_news_item($$all_docs[$i], \@left_news, \@already_added, $obvius);
    }

    $output->param(left_news=>\@left_news);



    # find de nyeste nyheder
    my $news_docs = $obvius->search([qw(docdate)], 
				  "type = " . $nyhed_doctype->Id . " and docdate <= \'" . $nowdate . "\'",, 
				  %search_options);

    $news_docs = [] unless ($news_docs);

    my @right_news;
    for (@$news_docs) {
	$obvius->get_version_fields($_, [qw(title short_title teaser content)]);
	my $docid = $_->DocId || '';
	my $already_added_test = \@already_added;
	unless(is_already_added($already_added_test, $docid)) {
	    my $doc = $obvius->get_doc_by_id($_->DocId);
	    my $url = $obvius->get_doc_uri($doc);
	    push(@right_news, {
			       title => $_->Short_Title ? $_->Short_Title : $_->Title,
			       docdate => &convert_date($_->DocDate),
			       url => $url
			      }
		);
	}
    }

    $output->param(right_news=>\@right_news);

    # find de nyeste artikler
    my $article_docs = $obvius->search([qw(docdate)], 
				     "type = " . $artikel_doctype->Id . " and docdate <= \'" . $nowdate . "\'",, , 
				     %search_options);

    $article_docs = [] unless($article_docs);
    my @right_articles;
    for (@$article_docs) {
	my $docid = $_->DocId || '';
	my $already_added_test = \@already_added;
	unless(is_already_added($already_added_test, $docid)) {
	    $obvius->get_version_fields($_, [qw(title short_title teaser content)]);
	    my $doc = $obvius->get_doc_by_id($_->DocId);
	    my $url = $obvius->get_doc_uri($doc);
	    push(@right_articles, {
				   title => $_->Short_Title ? $_->Short_Title : $_->Title,
				   docdate => &convert_date($_->DocDate),
				   url => $url
				  }
		);
	}
    }

    $output->param(right_articles=>\@right_articles);

    return OBVIUS_OK;
}





sub push_news_item {
    my ($news_item, $left_news, $already_added, $obvius) = @_;
    my $linkvdoc = undef;
    my $url = $news_item;

    if (ref $news_item eq 'Obvius::Version') {
	$linkvdoc = $news_item;
	my $doc = $obvius->get_doc_by_id($linkvdoc->DocId);
	$url = $obvius->get_doc_uri($doc);
    } else {
	my $linkdoc = $obvius->lookup_document($news_item);
	$linkvdoc= $obvius->get_public_version($linkdoc) || $obvius->get_latest_version($linkdoc) if($linkdoc);
    }

    unless(is_already_added($already_added, $linkvdoc->Docid)) {
	push (@$already_added, $linkvdoc->Docid);
	$obvius->get_version_fields($linkvdoc, [qw (short_title title teaser docdate picture author content)]);
	



	push (@$left_news, { 
			    title => $linkvdoc->Short_Title ? $linkvdoc->Short_Title : $linkvdoc->Title,
			    teaser => $linkvdoc->field('teaser') || '',
			    docdate => &convert_date($linkvdoc->DocDate),
			    url => $url,
			    author => (defined $linkvdoc->field('author') ? $linkvdoc->field('author') : ''),
			    picture => (defined $linkvdoc->field('picture') ? $linkvdoc->field('picture') : ''),
			    content=> $linkvdoc->field('content') || ''
			   }
	     );
    }
}
# convert_date ($date)
# - Convert $date from yyyy-mm-dd to dd-mm-yyyy
#
sub convert_date {
    my ($year, $mon, $day, undef) = split /-|\s/, shift;
    return $day . "-" . $mon . "-" . $year;
}

sub is_already_added  {
    my ($already_added, $docid) = (shift, shift);
    for (@$already_added) {
	if ($_ == $docid) {
	    return 1;
	}
    }
    return 0;
}


#    sub get_image_properties {
#	my $imageurl = shift;

#	my  @path = $obvius->get_doc_by_path($imageurl);
#	my $image_doc;
#	$image_doc = $path[-1] if (@path);

#	my $image_vdoc;
#	$image_vdoc = $obvius->get_public_version($image_doc) if (defined $image_doc);
#	$obvius->get_version_fields($image_vdoc, [qw(width height)]) if (defined $image_vdoc);

#	my $height=$image_vdoc->Height;
#	my $width = $image_vdoc->Width;

#	if ($width > 150) {
#	    my $cut = $width - 150;
#	    my $cut_percentage = ($cut/$width);
#	    $height = int($height*(1-$cut_percentage));
#	    $width = int($width*(1-$cut_percentage));
#	}

#	if ($height > 150) {
#	    my $cut = $height - 150;
#	    my $cut_percentage = ($cut/$height);
#	    $height = int($height*(1-$cut_percentage));
#	    $width = int($width*(1-$cut_percentage));
#	}
#
#	return {width=>$width, height=>$height}
#    }



1;
__END__
    # Below is stub documentation for your module. You better edit it!

=head1 NAME

Obvius::DocType::Forside - Perl extension for blah blah blah

=head1 SYNOPSIS

    use Obvius::DocType::Forside;
blah blah blah

=head1 DESCRIPTION

Stub documentation for Obvius::DocType::Forside, created by h2xs. It looks like the
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
