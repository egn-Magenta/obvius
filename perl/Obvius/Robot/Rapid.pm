package Obvius::Robot::Rapid;

########################################################################
#
# Rapid.pm - robot for fetching news from Rapid
#
# Copyright (C) 2004 Magenta Aps, Denmark (http://www.magenta-aps.dk/)
#
# Authors: J¯rgen Ulrik B. Krag (jubk@magenta-aps.dk)
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

use HTML::Parser ();
use Obvius::Robot;
use Unicode::String qw(utf8 latin1);

our @ISA = qw(Exporter);
our @EXPORT = qw(parse_document_list set_lang_and_links retrieve_real_title);

our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub start_tag {
    my ($self, $tag, $text, $attr) = @_;

    return unless ($tag =~ /^(td|a)$/);

    if($self->{state} eq 'look_for_title') {
        if($tag eq 'a' and $attr->{class} and $attr->{class} eq 'docSel-titleLink') {
            $self->{state} = 'get_title';
            if($attr->{href}) {
                $attr->{href} =~ s/\s+//gs;
                $self->{doc}->{globalurl} = "http://europa.eu.int/rapid/" . $attr->{href};
            }
        }
    } elsif($self->{state} eq 'get_html_links' or $self->{state} eq 'get_pdf_links') {
        if($tag eq 'a' and $attr->{href}) {
            my $link = $attr->{href};
            $link =~ s/\s+//gs;
            $self->{tmp_link} = "http://europa.eu.int/rapid/" . $link;
        }
    } else {
        if($tag eq 'td' and $attr->{class} and $attr->{class} eq 'bluetext11') {
            $self->{state} = 'get_docdate';
        }
    }

    return;
}

sub end_tag {
    my ($self, $tag, $text) = @_;

    return unless ($tag eq 'a');

    if($self->{state} eq 'get_title') {
        if($tag eq 'a') {
            $self->{state} = 'look_for_html_links';
            return;
        }
    }

    return;

}

sub text_handler {
    my ($self, $text) = @_;

    return unless($text);

    # Convert nobreakspaces to normal spaces.
    $text =~ s/†/ /g;

    return if($text =~ /^\s+$/s);

    if($self->{state} eq 'get_docdate') {
        $text =~ s/\s+//gs;
        my ($docref, $docdate) = split(/Date:/, $text);
        $docref =~ s/†//g;
        $docdate =~ s/†//g;
        $self->{doc}->{docref} = $docref;
        $self->{doc}->{docdate} = $docdate;
        $self->{state} = 'look_for_title';

    } elsif($self->{state} eq 'look_for_html_links') {
        # Remove any spaces
        $text =~ s/\s+//sg;
        if($text eq 'HTML:') {
            $self->{state} = 'get_html_links';
        }
    } elsif($self->{state} eq 'get_html_links') {
        # Remove any spaces
        $text =~ s/\s+//sg;
        if($text eq 'PDF:') {
            $self->{state} = 'get_pdf_links';
        } else {
            if(my $link = $self->{tmp_link}) {
                $self->{doc}->{html_links}->{$text} = $link;
                $self->{tmp_link} = '';
            }
        }
    } elsif($self->{state} eq 'get_pdf_links') {
        # Remove any spaces
        $text =~ s/\s+//sg;
        if($text eq 'DOC:') {
            # Document ends here:
            store_document($self);
            $self->{state} = '';
        } else {
            if(my $link = $self->{tmp_link}) {
                $self->{doc}->{pdf_links}->{$text} = $link;
                $self->{tmp_pdf_link} = '';
            }
        }
    } elsif($self->{state} eq 'get_title') {
        $text =~ s/\n/ /gs;
        $text =~ s/^\s+//;
        $text =~ s/\s+$//;

        if($self->{doc}->{title}) {
            $self->{doc}->{title} .= ", " . $text;
        } else {
            $self->{doc}->{title} = $text;
        }

    }

    return;
}


sub store_document {
    my $self = shift;

    # No URI, no document..
    if (defined($self->{doc}->{globalurl})) {
        print(STDERR "\nSAVING ", $self->{doc}->{globalurl}, "\n\n")
            if ($self->{debug});

        push(@{ $self->{eu_docs} }, $self->{doc});
    }

    # Initialize new document
    $self->{doc} = {};
}

# parse_document_list - runs the HTML::Parser defined by this module
#                       on the text-parameter, optionally with debug
#                       turned on, and returns an array-ref with the
#                       eu_docs collected. Each collected document is
#                       a hash-ref.
sub parse_document_list {
    my ($text, $debug) = @_;

    my $parser = new HTML::Parser(
                                    api_version => 3,
                                    start_h => [\&start_tag, "self,tagname,text,attr"],
                                    text_h  => [\&text_handler, "self,dtext"],
                                    end_h   => [\&end_tag, "self,tagname,text"],
                                );
    $parser->{eu_docs} = [];

    $parser->{state} = '';
    $parser->{doc} = {};
    $parser->{debug} = $debug;

    $parser->parse($text);

    return $parser->{eu_docs};
}

sub set_lang_and_links {
    my ($obj, $lang_pref) = @_;

    my $selected_link;
    my $selected_lang;
    my $selected_weight = 0;

    my $links = $obj->{html_links} || {};

    for(keys %$links) {
        my $lang = lc($_);
        if(my $new_weight = $lang_pref->{$lang}) {
            if($new_weight > $selected_weight) {
                $selected_link = $links->{$_};
                $selected_lang = $lang;
                $selected_weight = $new_weight;
            }
        }
    }

    if($selected_link) {
        $obj->{real_link} = $selected_link;
        $obj->{lang} = $selected_lang;
    } else {
        $obj->{lang} = 'da';
    }


    # same for PDFs
    $links = $obj->{pdf_links} || {};
    $selected_weight = 0;
    $selected_link = '';

    for(keys %$links) {
        my $lang = lc($_);
        if(my $new_weight = $lang_pref->{$lang}) {
            if($new_weight > $selected_weight) {
                $selected_link = $links->{$_};
                $selected_weight = $new_weight;
            }
        }
    }

    if($selected_link) {
        $obj->{pdf_link} = $selected_link;
    }


}

# Methods for getting the title from a doc:

sub find_title {
    my ($self, $tag, $attr) = @_;

    return unless ($tag eq 'td');

    if($attr->{class} and $attr->{class} eq 'bluetitle14') {
        $self->handler(text => sub {
                        my $self = shift;
                        $self->{new_title} .= shift;
                    }, 'self,dtext');
        $self->handler(end => sub {
                        my ($self, $tag) = @_;
                        $self->eof if ($tag eq 'td');
                    }, 'self,tagname');
    }
}

sub retrieve_real_title {
    my ($doc, $debug) = @_;

    # $doc = [ titel, uri, lang, docref, docdate ]

    my $doctext = retrieve_uri($doc->{real_link});
    return unless ($doctext);

    my $parser = new HTML::Parser(api_version => 3,
                                  start_h => [\&find_title, "self,tagname,attr"],
                                 );
    $parser->parse($doctext);

    print(STDERR "New title: ", $parser->{new_title}, "\n") if ($debug);
    if (defined($parser->{new_title})) {

        my $title = $parser->{new_title};

        # Replace nobreakspaces with normal spaces:
        $title =~ s/†/ /g;

        # Make sure we only have single, normal spaces
        $title =~ s/\s+/ /g;

        # Remove start and end spaces
        $title =~ s/^\s+//;
        $title =~ s/\s+$//;

        # Convert utf8
        $title = utf8(narrow_unicode_utf8($title))->latin1;

        return $title;
    }

    return undef;
}

# narrow_unicode_utf8 - convert commonly used unicode-sequences to the
#                       similar ones in latin1.
sub narrow_unicode_utf8 {
    my ($text)=@_;

    $text=~s/Äô/\'/g;
    $text=~s/Ç¨/euro/g;
    $text=~s/Äú/\"/g;
    $text=~s/Äù/\"/g;

    return $text;
}

1;
__END__

=head1 NAME

Obvius::Robot::Rapid - robot for fetching news from Rapid

=head1 SYNOPSIS

  use Obvius::Robot::Rapid;

=head1 DESCRIPTION

=head2 EXPORTS

 parse_document_list
 set_lang_and_links
 retrieve_real_title

=head1 AUTHOR

J¯rgen Ulrik B. Krag E<lt>jubk@magenta-aps.dkE<gt>

=head1 SEE ALSO

L<Obvius::Robot>.

=cut
