package WebObvius::Template::MCMS::HTML2MCMS;

use strict;
use warnings;

use HTML::Parser ();

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

sub comment_tag {
    my ($self, $text) = @_;
}

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

WebObvius::Template::Obvius::HTML2Obvius - Perl extension for blah blah blah

=head1 SYNOPSIS

  use WebObvius::Template::Obvius::HTML2Obvius;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for WebObvius::Template::Obvius::HTML2Obvius, created by h2xs. It looks like the
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
