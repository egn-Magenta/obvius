package WebObvius::Template::MCMS::HTML2MCMS;

########################################################################
#
# WebObvius::Template::MCMS::HTML2MCMS.pm - HTML to MCMS parser.
#
# Copyright (C) 2001 Magenta Aps, Denmark (http://www.magenta-aps.dk/)
#
# Authors: Jørgen Ulrik B. Krag (jubk@magenta-aps.dk)
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

use strict;
use warnings;

our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

use HTML::Parser ();

# html2mcms($html) - converts HTML to the MCMS markup. Returns
#                    the MCMS markup.
sub html2mcms {
    my $html = shift;
    my $parser = new HTML::Parser(
                                    api_version => 3,
                                    start_h => [\&start_tag, "self,tagname,text,attr"],
                                    text_h => [\&text_handler, "self,dtext"],
                                    end_h => [\&end_tag, "self,tagname,text"]
                                );

    $parser->{OUTPUT} = '';
    $parser->{LINK_PROPERTIES} = [];
    $parser->{UNENDED_ANCHORS} = 0;
    $parser->{LAST_TAG} = '';
    $parser->{UNENDED_BULLETS} = 0;
    $parser->{ORDERED_LISTS} = 0;
    $parser->{TABLES} = 0;
    $parser->{TABLE_IMAGES} = [];

    # Mysterious things happens here.
    # Seems like HTML::Parser throws away the last word
    # unless there is a space after it.
    # The parser _should_ ignore extra endlines at end
    # of HTML.
    $html .= "\n";

    $parser->parse($html);

    $parser->{OUTPUT} =~ s/\n(\n*)$/\n/;
    $parser->{OUTPUT} =~ s/>\n+>/>>/g;

    return $parser->{OUTPUT};
}

# comment_tag($text) - dummy function used by the HTML-parser.
#                      Does nothing.
sub comment_tag {
    my ($self, $text) = @_;
}

# start_tag($tag, $text, \%attr) - Handler for start tags in
#           the parser. Returns nothing.
sub start_tag {
    my ($self, $tag, $text, $attr) = @_;

    if($tag eq 'p') {
        # Don't write anything?
    } elsif($tag eq 'br') {
        $self->{OUTPUT} .= "\n";
    } elsif($tag =~ /^(b|strong)$/) {
        $self->{OUTPUT} .= "B<";
    } elsif($tag =~ /^(i|em)$/) {
        $self->{OUTPUT} .= "I<";
    } elsif($tag eq 'u') {
        $self->{OUTPUT} .= "U<";
    } elsif($tag eq 'ul') {
        # do nothing
    } elsif($tag eq 'ol') {
        # Warning. This tag is terminated by an <LI> end tag.
        # It will fail if input is not of the form
        # <OL><LI>text</LI></OL>
        my $start = $attr->{start} || 1;
        $self->{ORDERED_LISTS} += 1;
        $self->{OUTPUT} .= "INDENT<$start. ";
    } elsif($tag eq 'li') {
        unless($self->{ORDERED_LISTS}) {
            $self->{OUTPUT} .= "BULLET<";
            $self->{UNENDED_BULLETS} += 1;
        }
    } elsif($tag =~ /^h([1-6])$/) {
        $self->{OUTPUT} .= "H$1<";
    } elsif($tag eq 'a') {
        # Handle anchors for /path/to/file#anchorname links
        if(! $attr->{href} and $attr->{name}) {
            $self->{OUTPUT} .= "A<" . $attr->{name} . ">";
            $self->{UNENDED_ANCHORS} += 1;
        } else {
            $self->{OUTPUT} .= "L<";
            # Store the needed data on the link properties array
            my $properties = ";" . $attr->{href};
            $properties .= (";" . $attr->{target}) if($attr->{target});
            push(@{$self->{LINK_PROPERTIES}}, $properties);
        }
    } elsif($tag eq 'img') {
        my $src = $attr->{src};
        my $extra = '';
        for(keys %$attr) {
            if(/(alt|align|border|hspace|vspace)/) { # Trying to avoid anything with ; in it
                $extra .= "$_=\"" . $attr->{$_} . "\";";
            }
        }
        $extra =~ s/;$//;
        if($self->{TABLES}) {
            $self->{TABLE_IMAGES}->[ $self->{TABLES} ]->{src} = $src;
            $self->{TABLE_IMAGES}->[ $self->{TABLES} ]->{extra} = $extra;
        } else {
            $self->{OUTPUT} .= "IMG<$src;$extra>";
        }
    } elsif($tag eq 'table') {
        my $from_table='';
        if($attr->{cellpadding}){
            my $val = $attr->{cellpadding} * 2;
            $from_table .= ';hspace="' . $val . '";vspace="' . $val . '"';
        }
        if($attr->{align}) {
            $from_table .= ';align="' . $attr->{align} . '"';
        }
        $from_table =~ s/^;//;
        $self->{TABLES} += 1;
        $self->{TABLE_IMAGES}->[ $self->{TABLES} ] = {
                                                        from_table => $from_table,
                                                        picturetext => ''
                                                    };
    } elsif($tag =~ /^(tr|td|tbody)$/) {
        # Ignore
    } elsif($tag eq 'span') {
        unless($attr->{class} and $attr->{class} eq 'pictext') {
            print STDERR "Warning! Unknown starttag: '$text'\n";
        }
    } else {
        print STDERR "Warning! Unknown starttag: '$text'\n";
    }
}

# end_tag($tag, $text) - Handler for end tags in the parser.
#                       Returns nothing.
sub end_tag {
    my ($self, $tag, $text) = @_;

    if($tag eq 'p') {
        # Write a paragraph as a block of text followed by two endlines
        $self->{OUTPUT} .= "\n\n";
    } elsif($tag =~ /^(b|strong|i|em|u)$/) {
        # End 'em when they end
        $self->{OUTPUT} .= ">";
    } elsif($tag =~ /^(li|h[1-6])$/) {
        #output these folowed by an endline to make result look good
        $self->{OUTPUT} .= ">\n";
        $self->{UNENDED_BULLETS} -= 1 if($tag eq 'li');
    } elsif($tag eq 'ol') {
        $self->{ORDERED_LISTS} -= 1 if($self->{ORDERED_LISTS} > 0);
    } elsif($tag eq 'ul') {
        my $bullets = $self->{UNENDED_BULLETS};
        for(1..$bullets){
            $self->{OUTPUT} .= ">\n";
        }
        $self->{UNENDED_BULLETS} = 0;
    } elsif($tag eq 'a') {
        if($self->{UNENDED_ANCHORS} > 0) {
            $self->{UNENDED_ANCHORS} -= 1;
        } else {
            my $properties = pop(@{$self->{LINK_PROPERTIES}});
            $self->{OUTPUT} .= "$properties>";
        }
    } elsif($tag eq 'table') {
        if($self->{TABLES}) {
            my $img = $self->{TABLE_IMAGES}->[ $self->{TABLES} ];
            $self->{OUTPUT} .= 'IMG<' . $img->{src} . ';' . $img->{extra} . ';' . $img->{from_table} . ';picturetext="' . $img->{picturetext} . '">';
            $self->{TABLE_IMAGES}->[ $self->{TABLES} ] = {};
            $self->{TABLES} -= 1;
        }
    } elsif($tag =~ /^(tr|td|tbody)$/) {
        # Ignore
    } elsif($tag eq 'span') {
        # We have to ignore since we can't check the attrs.
    } else {
        print STDERR "Warning! Unknown endtag: '$text'\n";
    }
    $self->{LAST_TAG} = $tag;
}

# text_handler($origtext) - Text-handler for the HTML-parser.
#                          Returns nothing.
sub text_handler {
    my ($self, $origtext) = @_;
    $origtext =~ s/\r//g;
    if($origtext and $origtext !~ /^\n+$/) {
	$origtext =~ s/\n//g; # We don't want linebreaks in normal text in MCMS codes
        if($self->{TABLES}) {
            $self->{TABLE_IMAGES}->[ $self->{TABLES} ]->{picturetext} .= $origtext;
        } else {
            # Just write the text
            $self->{OUTPUT} .= $origtext;
        }
    }

}

1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

WebObvius::Template::MCMS::HTML2MCMS - HTML parser for converting
HTML to MCMS-markup.

=head1 SYNOPSIS

  use WebObvius::Template::MCMS::HTML2MCMS;

  my $mcms_markup = WebObvius::Template::MCMS::HTML2MCMS::html2mcms($html);

=head1 DESCRIPTION

  A HTML parser translating HTML to MCMS markup.

=head2 EXPORT

  None by default.


=head1 AUTHOR

Jørgen Ulrik B. KragE<lt>jubk@magenta-aps.dkE<gt>

=head1 SEE ALSO

L<Obvius>,
L<WebObvius>.

=cut
