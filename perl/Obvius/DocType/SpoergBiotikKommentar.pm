package Obvius::DocType::SpoergBiotikKommentar;

# $Id$

use strict;
use warnings;

use Obvius;
use Obvius::DocType;

use POSIX qw (strftime);

our @ISA = qw( Obvius::DocType );
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub action {
    my ($this, $input, $output, $doc, $vdoc, $obvius) = @_;

    if($input->param('IS_ADMIN')) {
        $output->param('admin' => 1);

        if($obvius->get_public_version($doc)) {
            $output->param('godkendt' => 1);
        } else {
            if($input->param('godkendt')) {
                my $new_vdoc=$obvius->get_latest_version($doc);
                $obvius->get_version_fields($new_vdoc, 255, 'PUBLISH_FIELDS');
                my $publish_fields = $new_vdoc->publish_fields;
                $publish_fields->param(PUBLISHED => strftime('%Y-%m-%d %H:%M:%S', localtime));

                my $publish_error;
                # XXX
                my $tmpuser = $obvius->{USER};
                $obvius->{USER} = 'admin';
                $obvius->publish_version($new_vdoc, \$publish_error);
                $obvius->{USER} = $tmpuser;
                if($publish_error) {
                    print STDERR "Problems publishing document: $publish_error\n";
                    $output->param('publish_error' => $publish_error);
                } else {
                    my $maildata = $this->get_emails_reversed($obvius, $doc->Id);
                    $output->param('emails' => $maildata->{emails});
                    $output->param('answer_title' => $maildata->{answer_title});
                    $output->param('question_title' => $maildata->{question_title});
                    $output->param('url' => $maildata->{url});
                    $output->param('send_mails' => 1);

                    $output->param('godkendt' => 1);
                }
            }
        }
    }

    return OBVIUS_OK;
}

sub get_comments_recursive {
    my ($this, $obvius, $docid, $getall) = @_;

    my $doctypeid = $this->Id;

    my $pending = $obvius->search(
                                                        [ 'docdate' ],
                                                        "type = $doctypeid AND parent = $docid",
                                                        public => 1,
                                                        needs_document_fields => [ 'parent' ],
                                                        order => 'docdate DESC'
                                                  ) || [];

    for(@$pending) {
        $_->{LEVEL} = 1;
    }


    my @results;

    while(my $vdoc = shift(@$pending)) {

        my $level = $vdoc->{LEVEL};

        if($getall) {
            $obvius->get_version_fields($vdoc, ['title', 'name', 'email', 'kommentar', 'link1', 'link2', 'link3', 'link4', ]);
            push(@results, {
                            title => $vdoc->field('title'),
                            name => $vdoc->field('name'),
                            email => $vdoc->field('email'),
                            kommentar => $vdoc->field('kommentar'),
                            link1 => $vdoc->field('link1'),
                            link2 => $vdoc->field('link2'),
                            link3 => $vdoc->field('link3'),
                            link4 => $vdoc->field('link4'),
                            level => $level,
                            docid => $vdoc->DocId
                        });
        } else {
            push(@results, $vdoc);
        }

        my $subdocs = $obvius->search(
                                        [ 'docdate' ],
                                        "type = $doctypeid AND parent = " . $vdoc->DocId,
                                        public => 1,
                                        needs_document_fields => [ 'parent' ],
                                        order => 'docdate DESC'
                                    ) || [];
        for(@$subdocs) {
            $_->{LEVEL} = $level + 1;
        }

        unshift(@$pending, @$subdocs);
    }

    return (scalar(@results) ? \@results : undef);
}

sub get_emails_reversed {
    my ($this, $obvius, $docid) = @_;


    my $answer_doctype = $obvius->get_doctype_by_name('Svar');
    my $question_doctype = $obvius->get_doctype_by_name('Spoergsmaal');

    my $answer_type = $answer_doctype->Id;
    my $question_type = $question_doctype->Id;
    my $comment_type = $this->Id;

    my $dont_stop = 1;

    my @emails;
    my $answer_title;
    my $question_title;

    my $url;

    my $doc = $obvius->get_doc_by_id($docid);

    while($dont_stop) {
        $doc = $obvius->get_doc_by_id($doc->Parent);

        my $vdoc = $obvius->get_public_version($doc);

        if($vdoc) {
            my $type = $vdoc->Type;
            if($type == $comment_type) {
                push(@emails, $obvius->get_version_field($vdoc, 'email'));
            } elsif($type == $answer_type) {
                my $expert = $obvius->get_version_field($vdoc, 'expert');
                my $e_doc;
                $e_doc = $obvius->lookup_document($expert) if($expert);
                my $e_vdoc;
                $e_vdoc = $obvius->get_public_version($e_doc) if($e_doc);
                my $email;
                $email = $obvius->get_version_field($e_vdoc, 'email') if($e_vdoc);
                push(@emails, $email) if($email);

                $answer_title = $obvius->get_version_field($vdoc, 'title');
            } elsif($type == $question_type) {
                $question_title = $obvius->get_version_field($vdoc, 'title');
                my $email = $obvius->get_version_field($vdoc, 'email');
                push(@emails, $email) if($email);

                $url = $obvius->get_doc_uri($doc);
            }
        } else {
            $dont_stop = 0;
        }
    }

    return { emails => \@emails, answer_title => $answer_title, question_title => $question_title, url => $url };
}

1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Obvius::DocType::SpoergBiotikKommentar - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Obvius::DocType::SpoergBiotikKommentar;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Obvius::DocType::SpoergBiotikKommentar, created by h2xs. It looks like the
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
