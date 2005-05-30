package Obvius::DocType::Forside;

########################################################################
#
# Forside.pm - Forside Document Type
#
# Copyright (C) 2001-2004 aparte A/S, Denmark (http://www.aparte.dk/)
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

    return OBVIUS_OK;
}


sub get_news {
    my ($this, $vdoc, $obvius)=@_;

    my $doctype=$obvius->get_doctype_by_name("Nyhed");
    $obvius->get_version_fields($vdoc, [qw(news_1 news_2)]);

    return $this->get_em($vdoc, $doctype, [$vdoc->News_1, $vdoc->News_2], $obvius);
}

sub get_articles {
    my ($this, $vdoc, $obvius)=@_;

    my $doctype=$obvius->get_doctype_by_name("Artikel");
    $obvius->get_version_fields($vdoc, [qw(news_3 news_4)]);

    return $this->get_em($vdoc, $doctype, [$vdoc->News_3, $vdoc->News_4], $obvius);
}

sub get_em {
    my ($this, $vdoc, $doctype, $fields, $obvius)=@_;

    my %search_options = (
                          notexpired=>1,
                          nothidden=>1,
                          order => 'docdate DESC',
                          public=>1,
                          append=>'limit 13'
                         );

    my $nowdate = strftime('%Y-%m-%d 00:00:00', localtime);

    # find de nyeste
    my $vdocs = $obvius->search([qw(docdate)],
                              "type = " . $doctype->Id . " and docdate <= \'" . $nowdate . "\'",, ,
                              %search_options) || [];

    # XXX Handle big_news exclusion:

    # fields:
    foreach my $field_value (@$fields) {
        unshift @$vdocs, ($obvius->get_public_version($obvius->lookup_document($field_value))) if (defined $field_value and $field_value ne '/' and $obvius->lookup_document($field_value) and $obvius->get_public_version($obvius->lookup_document($field_value)));
    }

    my %already_added=();
    my @list=();
    for (@$vdocs) {
	my $docid = $_->DocId;
	unless($already_added{$docid}) {
	    $obvius->get_version_fields($_, [qw(title short_title teaser content author docdate)]);
	    my $doc = $obvius->get_doc_by_id($_->DocId);
	    my $url = $obvius->get_doc_uri($doc);
	    push(@list, {
                         title => $_->field('short_title') ? $_->Short_Title : $_->Title,
                         teaser => $_->field('teaser') || '',
                         author => $_->field('author') || '',
                         picture => $_->field('picture') || '',
                         docdate => &convert_date($_->DocDate),
                         content => $_->field('content') || '',
                         url => $url
                        }
                );
            $already_added{$docid}=1;
	}
    }

    my @top=();
    for(my $i=scalar(@top); $i<2; $i++) {
        push @top, shift @list;
    }
    @list=@list[0..9] if (scalar(@list)>10);

    return (\@top, \@list);
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

sub get_big_news {
    my ($this, $vdoc, $obvius)=@_;

    $obvius->get_version_fields($vdoc, [qw(big_news)]);

    # den tværgående nyhed
    if (defined $vdoc->Big_news and $vdoc->Big_news ne '/') {
	my $linktop_doc = $obvius->lookup_document($vdoc->Big_news);
	my $linkvdoc;
	$linkvdoc = $obvius->get_public_version($linktop_doc) || $obvius->get_latest_version($linktop_doc) if($linktop_doc);
	$obvius->get_version_fields($linkvdoc, [qw (short_title title teaser content picture author docdate header)]);
	
	my $linktop_hash_doc = {
				title => $linkvdoc->field('short_title') ? $linkvdoc->Short_Title : $linkvdoc->Title,
                                header => $linkvdoc->field('header') || '',
				teaser => $linkvdoc->field('teaser') || '',
				content => $linkvdoc->Content || '',
				docdate => &convert_date($linkvdoc->DocDate),
				url => $vdoc->Big_news,
				author => (defined $linkvdoc->field('author') ? $linkvdoc->field('author') : ''),
				picture => (defined $linkvdoc->field('picture') ? $linkvdoc->field('picture') : '')
			       };
	#$output->param(top_vdoc=>$linktop_hash_doc);
        return $linktop_hash_doc;
    }

    return undef;
}


1;
__END__

=head1 NAME

Obvius::DocType::Forside - Perl extension for the Sportsfiskeren frontpage.

=head1 SYNOPSIS

    use'd automatically.

=head1 DESCRIPTION

Provide functions for the Mason-components to call (so each part can
be cached separately).

=head2 EXPORT

None by default.


=head1 AUTHOR

Mads Kristensen,
Adam Sjøgren <asjo@aparte-test.dk>

=head1 SEE ALSO

L<Obvius>.

=cut
