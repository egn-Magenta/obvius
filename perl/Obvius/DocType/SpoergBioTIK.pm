package Obvius::DocType::SpoergBioTIK;

# $Id$

use strict;
use warnings;

use Obvius;
use Obvius::DocType;

use Obvius::Data;

use Data::Dumper;

use POSIX qw(strftime);

our @ISA = qw( Obvius::DocType );
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

our %accepted_modes = (
                        'welcome'   => 1,
                        'last5'     => 1,
                        'ask'       => 1,
                        'search'    => 1,
                    );

sub action {
    my ($this, $input, $output, $doc, $vdoc, $obvius) = @_;

    # Admin is handled elsewhere.
    return $this->admin_handler($input, $output, $doc, $vdoc, $obvius) if($input->param('IS_ADMIN'));

    my $mode = $input->param('mode') || 'welcome';

    # Default to welcome mode
    $mode = 'welcome' unless($accepted_modes{$mode});

    my $question_doctype = $obvius->get_doctype_by_name('Spoergsmaal');
    my $answer_doctype = $obvius->get_doctype_by_name('Svar');
    my $comment_doctype = $obvius->get_doctype_by_name('SpoergBiotikKommentar');

    if($mode eq 'last5') {

        my @docs;
        my @parents;
        for(1..5) {
            my $where = "type = " . $answer_doctype->Id;
            $where .= " AND (parent NOT IN (" . join(',', @parents) . "))" if(scalar(@parents));
            my $docs = $obvius->search(   ['published'],
                                        $where,
                                        public => 1,
                                        order => 'published DESC',
                                   #append => 'LIMIT 1',
                                        needs_document_fields => ['parent'],
                                );
            if ($docs) {
                my $vdoc = $docs->[0];
                push(@parents, $vdoc->Parent);
                my $parent_doc = $obvius->get_doc_by_id($vdoc->Parent);
                my $parent_vdoc = $obvius->get_public_version($parent_doc) || $obvius->get_latest_version($parent_doc);

                #Fields from the question:
                $obvius->get_version_fields($parent_vdoc, ['spoergsmaal', 'category']);

                my $categories = $parent_vdoc->Category || [];
                my @categories = map { $_->Name } grep { $_->Id =~ /^10 / and $_->Id !~ /(FOL|GYM|UNI)$/ } @$categories;
                push(@categories, 'Ikke angivet') unless(scalar(@categories));
                $categories = join(',', @categories);

                #The url
                my $url = $obvius->get_doc_uri($parent_doc);

                #Number of answers
                my $answers = $obvius->search(
                                            [],
                                            "type = " . $answer_doctype->Id . " AND parent = " . $parent_doc->Id,
                                            public => 1,
                                            notexpired => 1,
                                            needs_document_fields => ['parent']
                                        ) || [];
                my $num_comments = 0;
                for(@$answers) {
                    my $comments = $comment_doctype->get_comments_recursive($obvius, $_->DocId);
                    $num_comments += scalar(@$comments) if($comments);
                }
                $answers = scalar(@$answers) + $num_comments;

                push(@docs, {
                                spoergsmaal => $parent_vdoc->Spoergsmaal,
                                answers => $answers,
                                url => $url,
                                categories => $categories
                            }
                        );
            } else {
                print STDERR "Couldn't find answer with where: '" . $where . "'\n";
            }
        }

        $output->param('last5' => \@docs) if(scalar(@docs));
        $output->param('mode' => 'last5');
    }
    if($mode eq 'ask') {
        $output->param('mode' => 'ask');

        return OBVIUS_OK unless($input->param('submit'));

        my $error;

        my $fields = new Obvius::Data;

        for(keys %{$question_doctype->{FIELDS}}) {
            $fields->param($_ => $question_doctype->{FIELDS}->{$_}->{DEFAULT_VALUE});
        }

        $fields->param(name => $input->param('name') || 'Anonym');
        $fields->param(email => $input->param('email')) if($input->param('email'));
        $fields->param(alder => $input->param('alder') || 0);

        if(my $uddannelse = $input->param('uddannelse')) {
            if($uddannelse =~ /andet/i) {
                $fields->param(uddannelse => $input->param('uddannelseandet') || 'Ikke angivet');
            } else {
                $fields->param(uddannelse => $uddannelse);
            }
        } else {
            $fields->param(uddannelse => 'Ikke angivet');
        }

        if(my $niveau = $input->param('niveau')) {
            my $category_fieldspec = $obvius->get_fieldspec('category');
            my $category_fieldtype = $category_fieldspec->{FIELDTYPE};

            my $category;
            $category = '10 FOL' if($niveau eq 'folkeskole');
            $category = '10 GYM' if($niveau eq 'gymnasium');
            $category = '10 UNI' if($niveau eq 'universitet');

            my $obj;
            $obj = $category_fieldtype->copy_in($obvius, $category_fieldspec, $category) if($category);

            if($obj) {
                $fields->param(category => [ $obj ]);
                $fields->param(niveau => $niveau);
            }
        }

        if(my $spg = $input->param('spoergsmaal')) {
            $fields->param(spoergsmaal => $spg);
        } else {
            $error = 'Du skal angive et spørgsmål';
        }

        if(my $link1 = $input->param('link1')) {
            $fields->param(link1 => $link1) unless($link1 eq 'http://');
        }
        if(my $link2 = $input->param('link2')) {
            $fields->param(link2 => $link2) unless($link2 eq 'http://');
        }
        if(my $link3 = $input->param('link3')) {
            $fields->param(link3 => $link3) unless($link3 eq 'http://');
        }
        if(my $link4 = $input->param('link4')) {
            $fields->param(link4 => $link4) unless($link4 eq 'http://');
        }

        if($error) {
            $output->param(error => $error);
        } else {
            $fields->param(docdate => strftime('%Y-%m-%d 00:00:00', localtime));

            $fields->param(seq => 1.00);

            $fields->param(title => 'Spørgsmål fra ' . $fields->param('name') . ', ' . strftime('%Y-%m-%d', localtime));
            $fields->param(short_title => '');

            my $name = 'spoergsmaal_' . strftime('%Y%m%d%H%M%S', localtime);

            my $parent_path = $obvius->get_version_field($vdoc, 'where');
            my $parent = $obvius->lookup_document($parent_path);
            my $owner = $doc->{OWNER};
            my $group = $doc->{GRP};
            my $lang = $vdoc->{LANG};

            # XXX
            my $backup_user = $obvius->{USER};
            $obvius->{USER} = 'admin';
            my ($docid, $version) = $obvius->create_new_document($parent, $name, $question_doctype->Id, $lang, $fields, $owner, $group);
            $obvius->{USER} = $backup_user;

            if($docid) {
                $output->param('mode' => 'created');
                $output->param('recipient' => $fields->param('email'));
                $output->param('moderator' => $obvius->get_version_field($vdoc, 'email'));
                $output->param('recipient_name' => $fields->param('name'));
                my $new_doc = $obvius->get_doc_by_id($docid);
                my $newdoc_url = $obvius->get_doc_uri($new_doc);
                $output->param('newdoc_url' => $newdoc_url);
            } else {
                $output->param(error => 'Der skete en fejl under oprettelsen af dit spørgsmål. Vi beklager.');
            }
        }
    }
    if($mode eq 'search') {
        $output->param(mode => 'search');
        return OBVIUS_OK unless($input->param('submit'));

        my @fields;
        my $where = 'type = ' . $question_doctype->Id . " AND ";

        if(my $words = $input->param('words')) {
            push(@fields, 'spoergsmaal');
            my @words = split(/\s+/, $words);
            for(@words) {
                $where .= 'spoergsmaal LIKE "%' . $_ . '%" AND ';
            }
        }

        if(my $category = $input->param('category')) {
            push(@fields, 'category');
            $where .= "category = '$category' AND ";
        }

        if(my $niveau = $input->param('niveau')) {
            push(@fields, 'niveau');
            $where .= "niveau = '$niveau'";
        }
        $where =~ s/ AND $//;

        my $limit = '';
        if(my $numhits = $input->param('numhits')) {
            $limit = "LIMIT $numhits" if($numhits =~ /\d+/);
        }
        my $docs = $obvius->search(\@fields, $where, public => 1, notexpired => 1, append => $limit);

        if($docs) {
            my @docs;

            for(@$docs) {
                $obvius->get_version_fields($_, ['spoergsmaal', 'category']);

                my $categories = $_->Category || [];
                my @categories = map { $_->Name } grep { $_->Id =~ /^10 / and $_->Id !~ /(FOL|GYM|UNI)$/ } @$categories;
                push(@categories, 'Ikke angivet') unless(scalar(@categories));
                $categories = join(',', @categories);

                #The url
                my $doc = $obvius->get_doc_by_id($_->DocId);
                my $url = $obvius->get_doc_uri($doc);

                #Number of answers
                my $answers = $obvius->search(
                                            [],
                                            "type = " . $answer_doctype->Id . " AND parent = " . $_->DocId,
                                            public => 1,
                                            notexpired => 1,
                                            needs_document_fields => ['parent']
                                        ) || [];
                $answers = scalar(@$answers);

                push(@docs, {
                                spoergsmaal => $_->Spoergsmaal,
                                answers => $answers,
                                url => $url,
                                categories => $categories

                            });

            }
            use Data::Dumper;
            print STDERR Dumper(\@docs);

            $output->param(result => \@docs);
        } else {
            $output->param(no_results => 1);
        }
    }
    $output->param(mode => $mode) unless($output->param('mode'));
    return OBVIUS_OK;
}

sub admin_handler {
    my ($this, $input, $output, $doc, $vdoc, $obvius) = @_;

    my $spg_doctype = $obvius->get_doctype_by_name('Spoergsmaal');
    my $ans_doctype = $obvius->get_doctype_by_name('Svar');

    my $spgs = $obvius->search(
                                [ 'seq' ],
                                "seq > -1000 AND type = " . $spg_doctype->Id
                            ) || [];
    my @unhandled;
    my @unanswered;
    for(@$spgs) {
        my $d = $obvius->get_doc_by_id($_->DocId);
        my $v;
        if($v = $obvius->get_public_version($d)) {
            my $answers = $obvius->search(
                                            [],
                                            "type = " . $ans_doctype->Id . " AND parent = " . $d->Id,
                                            public => 1,
                                            needs_document_fields => [ 'parent' ]);
            next if($answers);

            $v = $obvius->get_latest_version($d);
            my $url = $obvius->get_doc_uri($d);
            push(@unanswered, { title => $obvius->get_version_field($v, 'title'), url => $url });

        } else {
            $v = $obvius->get_latest_version($d);
            my $url = $obvius->get_doc_uri($d);
            push(@unhandled, { title => $obvius->get_version_field($v, 'title'), url => $url });
        }
    }

    $output->param('unhandled' => \@unhandled);
    $output->param('unanswered' => \@unanswered);


    return OBVIUS_OK;
}

1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Obvius::DocType::SpoergBioTIK - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Obvius::DocType::SpoergBioTIK;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Obvius::DocType::SpoergBioTIK, created by h2xs. It looks like the
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
