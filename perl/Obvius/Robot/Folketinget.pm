package Obvius::Robot::Folketinget;

########################################################################
#
# Folketinget.pm - Search robot for www.folketinget.dk
#
# Copyright (C) 2000-2004 Magenta Aps, Denmark (http://www.magenta-aps.dk/)
#
# Authors: Jørgen Ulrik B. Krag (jubk@magenta-aps.dk),
#          René Seindal,
#          Adam Sjøgren
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

require Exporter;

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(search_folketinget get_ftdoc_data);
our @EXPORT = qw();
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

use HTML::Parser ();
use URI;
use URI::Escape;
use POSIX qw(strftime);

use Obvius::Robot;

###################################################################
#                                                                 #
#                       Getting the urls                          #
#                                                                 #
###################################################################

sub search_folketinget {
    my (%options) = @_;

    die "Must have a search expression\n" unless($options{search_expression});

    die "
        You must specify a ft_data option.
        It should be a hash containing names for the separate groups and
        ft-doctypes that you want to crawl, eg.:

        {
            Grp1 => 'Group1 name',
            Grp2 => 'Group2 name',

            '1'  => 'Name of doctype 1',
            '2'  => 'Name of doctype 2',
        }

        Doctypes that are not named in this hash will be excluded from the result.
    " unless($options{ft_data});

    my $url = 'http://www.ft.dk/scripts/ftsog/FTSOG2.IDQ?';

    $url .= 'CiMaxRecordsPerPage=300';

    $url .= '&TextRestriction=' . $options{search_expression};

    $url .= '&FMModDate='       . ($options{fmmoddate} || '');

    $url .= '&UdfyldteFelter='  . ($options{udfyldtefelter} || 1);

    $url .= '&FMMod='           . ($options{fmmod} || 'since');

    $url .= '&HTMLQueryForm='   . ($options{htmlqueryform} || '%2Fsystem%2Fsdialog%2Fsogbund.htm');

    $url .= '&CiScope='         . ($options{ciscope} || '%2Fsamling%2C+%2Fbaggrund%2C+%2Fbaggrund');

    $url .= '&SortProperty='    . ($options{sortproperty} || 'Rank');

    $url .= '&SortOrder='       . ($options{sortorder} || '%5Ba%5D');

    $url .= '&SortBy='          . ($options{sortby} || 'Gruppe%5Ba%5D%2C+SortPriority%5Ba%5D%2C+Samling%5Bd%5D%2C+Dato%5Ba%5D%2C+DocTitle%5Ba%5D');

    $url .= '&Grp='             . ($options{grp} || 'Grp2+OR+Grp3+OR+Grp4+OR+Grp5+OR+Grp6+OR+Grp7');

    $url .= '&IkkeMedtaget='    . ($options{ikkemedtaget} || 'Grp0');

    $url .= '&SoegeText=Biotik+specials%F8gning'; # Danish search text description.. Have no effect on result.

    print STDERR "Search url is «$url»\n" if ($options{debug});

    my $text = retrieve_uri($url);
    return undef unless ($text);

    my $parser = new HTML::Parser(
                                    api_version => 3,
                                    start_h => [\&start_tag, "self,tagname,text,attr"],
                                    text_h => [\&text_handler, "self,dtext"]
                                );
    $parser->{KNOWN_DOCS} = $options{known_docs} || {};
    $parser->{DEBUG} = $options{debug};
    $parser->{BASE_URL} = $url;
    $parser->{DOCS} = [];
    $parser->{DOC} = {};

    $parser->parse($text);

    return $parser->{DOCS};

}

sub store_document {
    my $self = shift;

    # Uden URL, intet dokument
    return unless($self->{DOC}->{url});

    my $doc = $self->{DOC};

    if(ref $self->{KNOWN_DOCS} eq 'HASH') {
        my $existing_doc = $self->{KNOWN_DOCS}->{$doc->{url}};
        if($existing_doc) {
            if($doc->{size} != $existing_doc->{size} or $doc->{timestamp} ne $existing_doc->{timestamp}) {
                $doc->{action} = 'new_version';
            } else {
                print STDERR "Already know '" . $doc->{url} . "', skipping\n" if($self->{DEBUG} > 1);
                $self->{DOC} = {};
                return;
            }
        } else {
            $doc->{action} = 'new_document';
        }
    }

    # Gem dokumentet så vi ikke får fat i det igen..
    $self->{KNOWN_DOCS}->{$doc->{url}} = $doc;

    print(STDERR "\nSAVING ", $doc->{url}, "\n") if ($self->{DEBUG} > 1);

    $self->{DOC}->{title} =~ s/\s+/ /g;
    $self->{DOC}->{title} =~ s/^\s+//;
    $self->{DOC}->{title} =~ s/\s+$//g;


    push(@{ $self->{DOCS} }, $self->{DOC});

    # Initialiser nyt document
    $self->{DOC} = {};
}

sub comment_tag {
    my ($self, $text) = @_;
}

# start_tag - called by the HTML::Parser when the start of a tag is
#             encountered.
#             On a-tags the href-attribute is checked for a specific
#             javascript-link ("HopTil") and such ones are stored in
#             the URL-field. The state is set to get_title.
#             On font-tags with the attribute size set to -1, the
#             state is set to get_size_and_date for processing
#             elsewhere.
sub start_tag {
    my ($self, $tag, $text, $attr) = @_;

    if($tag eq 'a') {
        if($attr and $attr->{href} and $attr->{href} =~ /^javascript:HopTil\('(.*)'\)$/) {
            $self->{STATE} = "get_title";
            $self->{DOC}->{url} = 'http://www.folketinget.dk' . $1;
        } else {
            return;
        }
    } elsif($tag eq 'font') {
        if($attr and $attr->{size} and $attr->{size} eq  '-1') {
            $self->{STATE} = "get_size_and_date";
        } else {
            return;
        }
    } else {
        return;
    }
}

sub text_handler {
    my ($self, $origtext) = @_;

    my $state = $self->{STATE};
    return unless($state);

    if($state eq 'get_title') {

        $self->{DOC}->{title} = $origtext;
        $self->{STATE} = undef;

    } elsif($state eq 'get_size_and_date') {

        my ($size, $day, $month, $year, $hour, $min, $sec) = ($origtext =~ /Størrelse ([0-9\.]+) bytes - D\. (\d\d)-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d)/);

        $size =~ s/\.//;
        $year = ($year < 50) ? "20" . $year : "19" . $year;

        $self->{DOC}->{timestamp} = "$year-$month-$day $hour:$min:$sec";
        $self->{DOC}->{size} = $size;

        store_document($self);

        $self->{STATE} = undef;
    } else {
        return;
    }
}

###################################################################
#                                                                 #
#                       Getting the rest                          #
#                                                                 #
###################################################################

sub get_ftdoc_data {
    my($doc, %options) = @_;

    die "No document given for get_ftdoc_data\n" unless($doc and $doc->{url});

    my $url = $doc->{url};
    my $text = retrieve_uri($url);

    my $parser = new HTML::Parser(
                                    api_version => 3,
                                    start_h => [\&data_start_tag, "self,tagname,text,attr"],
                                    end_h => [\&data_end_tag, "self,tagname,text"],
                                    text_h => [\&data_text_handler, "self,text"]
                                );
    $parser->{DEBUG} = $options{debug};
    $parser->{FT_DATA} = $options{ft_data};
    $parser->{BASE_URL} = $url;
    $parser->{DOC} = $doc;
    $parser->{FONT_TAGS} = 0;
    $parser->{DOC}->{html} = '';
    $parser->{INDENT} = 0;
    $parser->{LAST_TEXT} = "\n";

    $parser->parse($text);
}


sub data_start_tag {
    my ($self, $tag, $text, $attr) = @_;

    if($tag eq 'meta') {

        my $name = $attr->{name};
        if($name eq 'Samling') {
            $self->{DOC}->{samling} = $attr->{content};
        } elsif($name eq 'Gruppe') {
            my $group = $self->{FT_DATA}->{$attr->{content}};
            if($group) {
                $self->{DOC}->{gruppe} = $group;
            } else {
                print STDERR "Rejecting '" . $self->{DOC}->{url} . "': incorrect group " . $attr->{content} . "\n" if($self->{DEBUG} > 1);
                $self->{DOC}->{action} = 'reject';
                $self->eof;
            }
        } elsif($name eq 'SortPriority') {
                $self->{DOC}->{ft_sortorder} = $attr->{content};
        } elsif($name eq 'Dato') {
            my($year, $month, $day) = ($attr->{content} =~ /^(\d\d\d\d)(\d\d)(\d\d)$/);
            $self->{DOC}->{docdate} = "$year-$month-$day 00:00:00";
        }

    } elsif($tag eq 'script') {

        $self->{STATE} = 'get_sagref';

    } elsif($tag eq 'noscript') {

        $self->eof; # End when we get here!

    } elsif($tag eq 'title') {
        $self->{STATE} = 'get_title';
    } else {

        if($tag eq 'font') {
            $self->{FONT_TAGS}++;
            $self->{STATE} = 'get_html';
        }

        if($self->{FONT_TAGS}) {
            $self->{P_TAG} = 1 if($tag eq 'p');
            my $indent = "  " x $self->{INDENT};
            $self->{DOC}->{html} .= "$indent$text\n";
            $self->{INDENT}++ unless($tag eq 'br');
        }

    }
}

sub data_end_tag {
    my ($self, $tag, $text) = @_;

    if($self->{FONT_TAGS}) {
        $self->{INDENT}--;

        if($self->{P_TAG} and ($tag eq 'td' or $tag eq 'tr')) {
            $self->{INDENT}--;
            $self->{P_TAG} = undef;
        }

        my $indent = "  " x $self->{INDENT};
        $self->{DOC}->{html} .= "$indent$text\n";
    }

    if($tag eq 'font') {
        $self->{FONT_TAGS}--;
        $self->eof if($self->{STATE} and defined($self->{FONT_TAGS}) and $self->{FONT_TAGS} == 0);
        $self->{STATE} = 0 unless($self->{FONT_TAGS});
    } elsif($tag eq 'title') {
        $self->{STATE} = undef;
    }
}

sub data_text_handler {
    my ($self, $text) = @_;

    my $state = $self->{STATE};
    return unless($state);

    if($state eq 'get_sagref') {

        my ($temp) = ($text =~ /top\.SagRef\[1\] = "([^"]*)"/);
        $self->{DOC}->{sagsref} = $temp if($temp);
        $self->{STATE} = 0;

    } elsif($state eq 'get_title') {
        if(! $self->{DOC}->{title} and $text) {
            $text =~ s/[\n\r]//g;
            $self->{DOC}->{title} .= $text;
        }
    } else {

        if($self->{FONT_TAGS}) {
            # skip empty lines
            return if($text =~ /^\s*\n$/ and $self->{LAST_TEXT} =~ /^\s*\n$/);

            my $indent = "  " x $self->{INDENT};
            # Trying to do make the output a litle nicer
            $text =~ s/^[\n\s]*/$indent/;
            $text =~ s/[\n\s]+$//;
            $text =~ s/\n/\n$indent/mg;
            $self->{DOC}->{html} .= "$text\n";
            $self->{LAST_TEXT} = "$text\n";
        }

    }
}

1;
__END__

=head1 NAME

Obvius::Robot::Folketinget - Search robot for www.folketinget.dk

=head1 SYNOPSIS

  use Obvius::Robot::Folketinget;

=head1 DESCRIPTION

=head2 EXPORT

None by default.

=head1 AUTHOR

Jørgen Ulrik B. Krag E<lt>jubk@magenta-aps.dkE<gt>
René Seindal
Adam Sjøgren E<lt>asjo@magenta-aps.dkE<gt>

=head1 SEE ALSO

L<Obvius::Robot>.

=cut
