package Obvius::Robot::Rapid;

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
    $text =~ s/ / /g;

    return if($text =~ /^\s+$/s);

    if($self->{state} eq 'get_docdate') {
        $text =~ s/\s+//gs;
        my ($docref, $docdate) = split(/Date:/, $text);
        $docref =~ s/ //g;
        $docdate =~ s/ //g;
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
        $title =~ s/ / /g;

        # Make sure we only have single, normal spaces
        $title =~ s/\s+/ /g;

        # Remove start and end spaces
        $title =~ s/^\s+//;
        $title =~ s/\s+$//;

        # Convert utf8
        $title = utf8($title)->latin1;

        return $title;
    }

    return undef;
}


1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Obvius::Robot::Rapid - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Obvius::Robot::Rapid;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Obvius::Robot::Rapid, created by h2xs. It looks like the
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
