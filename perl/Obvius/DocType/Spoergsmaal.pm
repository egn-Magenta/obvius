package Obvius::DocType::Spoergsmaal;

# $Id$

use strict;
use warnings;

use Obvius;
use Obvius::DocType;

use POSIX qw(strftime);

our @ISA = qw( Obvius::DocType );
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

our %niveau_hash = (
                    ikkeangivet => 'Ikke angivet',
                    folkeskole => 'Folkeskoleniveau',
                    gymnasium   => 'Gymnasieniveau',
                    universitet => 'Universitetsniveau'
                );

sub action {
    my ($this, $input, $output, $doc, $vdoc, $obvius) = @_;

    my $expert_doctype = $obvius->get_doctype_by_name('Expert');
    my $answer_doctype = $obvius->get_doctype_by_name('Svar');

    my $mode = $input->param('mode') || '';
    if($mode eq 'login') {
        $output->param(mode => 'login');
        return OBVIUS_OK unless($input->param('submit'));

        my $email = $input->param('email');
        my $password = $input->param('password');

        my $where = 'type = ' . $expert_doctype->Id;
        $where .= " AND email = '$email'";
        $where .= " AND password = '$password'";

        my $experts = $obvius->search(['email', 'password'], $where, public => 1, notexpired => 1);
        if($experts) {
            if($input->param('remember_password')) {
                $output->param('Obvius_COOKIES' => { 'Spoerg_BioTIK_pw' => {
                                                            value => $password,
                                                            expires => '+1y',
                                                        }
                                                    });
            } else {
                # expire the cookie
                $output->param('Obvius_COOKIES' => { 'Spoerg_BioTIK_pw' => {
                                                            value => $password,
                                                            expires => '-1y',
                                                        }
                                                    });
            }
            $output->param(mode => 'answer');
            $output->param(email => $email);
            $output->param(password => $password);
        } else {
            $output->param(mode => 'login');
            $output->param(login_failed => 1);
        }
    }
    if($mode eq 'answer') {
        return OBVIUS_OK unless($input->param('submit'));

        my $email = $input->param('email');
        my $password = $input->param('password');

        my $where = 'type = ' . $expert_doctype->Id;
        $where .= " AND email = '$email'";
        $where .= " AND password = '$password'";

        my $experts = $obvius->search(['email', 'password'], $where, public => 1, notexpired => 1);

        if($experts) {
            my $expert_vdoc = $experts->[0];
            my $expert_doc = $obvius->get_doc_by_id($expert_vdoc->DocId);
            my $expert_path = $obvius->get_doc_uri($expert_doc);

            my $fields = new Obvius::Data;

            for(keys %{$answer_doctype->{FIELDS}}) {
                $fields->param($_ => $answer_doctype->{FIELDS}->{$_}->{DEFAULT_VALUE});
            }

            $fields->param(expert => $expert_path);

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

            $fields->param(svar => $input->param('answer'));

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

            $fields->param(docdate => strftime('%Y-%m-%d 00:00:00', localtime));

            $fields->param(seq => -1.00);

            my $expert_name = $obvius->get_version_field($expert_vdoc, 'name');
            $fields->param(title => $expert_name . "'s svar på spørgsmål " . $doc->Id);
            $fields->param(short_title => '');

            my $name = 'svar_' . strftime('%Y%m%d%H%M%S', localtime);

            my $owner = $doc->{OWNER};
            my $group = $doc->{GRP};
            my $lang = $vdoc->{LANG};

            # XXX
            my $backup_user = $obvius->{USER};
            $obvius->{USER} = 'admin';
            my ($docid, $version) = $obvius->create_new_document($doc, $name, $answer_doctype->Id, $lang, $fields, $owner, $group);
            $obvius->{USER} = $backup_user;

            $output->param(mode => 'thank');
            if($docid) {
                my $new_doc = $obvius->get_doc_by_id($docid);
                my $newdoc_url = $obvius->get_doc_uri($new_doc);
                $output->param('newdoc_url' => $newdoc_url);

                my $new_vdoc = $obvius->get_latest_version($new_doc);

                my $publish_error;

                # Start out with som defaults
                $obvius->get_version_fields($new_vdoc, 255, 'PUBLISH_FIELDS');

                # Set published
                my $publish_fields = $new_vdoc->publish_fields;
                $publish_fields->param(PUBLISHED => strftime('%Y-%m-%d %H:%M:%S', localtime));

                my $backup_user = $obvius->{USER};
                $obvius->{USER} = 'admin'; # XXX Don't try this at home
                $obvius->publish_version($new_vdoc, \$publish_error);
                $obvius->{USER} = $backup_user;

                if($publish_error) {
                    $output->param(error => "Vi kunne ikke offentliggøre dit svar på grund af følgende fejl: $publish_error");
                } else {
                    # Set fields for sending email to the asker.
                    $output->param('recipient' => $obvius->get_version_field($vdoc, 'email'));

                    $obvius->get_version_fields($new_vdoc, ['svar', 'expert', 'link1', 'link2', 'link3', 'link4']);
                    $output->param('svar' => $new_vdoc->field('svar'));
                    my @links;
                    for(1..4) {
                        push(@links, $new_vdoc->field("link$_")) if($new_vdoc->field("link$_"));
                    }
                    $output->param('links' => \@links);


                    my $exp_doc = $obvius->lookup_document($new_vdoc->Expert);
                    my $exp_vdoc = $obvius->get_public_version($exp_doc) || $obvius->get_latest_version($exp_doc);
                    $obvius->get_version_fields($exp_vdoc, ['title', 'email', 'institution']);
                    $output->param('ekspert' => $exp_vdoc->field('title'));
                    $output->param('ekspert_email' => $exp_vdoc->field('email'));
                    $output->param('institution' => $exp_vdoc->field('institution'));
                }
            } else {
                $output->param(error => 'Der skete en fejl under oprettelsen af dit svar. Vi beklager.');
            }


        } else {
            $output->param(mode => 'login');
            $output->param(login_failed => 1);
        }
    }

    if($mode eq 'comment') {
        $output->param('mode' => 'comment');

        my $docid = $input->param('commenton');
        my $doc;
        $doc = $obvius->get_doc_by_id($docid) if($docid);
        my $vdoc;
        $vdoc = $obvius->get_public_version($doc) if($doc);
        my $text;
        $text = $obvius->get_version_field($vdoc, 'kommentar') if($vdoc);
        $text = $obvius->get_version_field($vdoc, 'svar') if($vdoc and ! $text);
        $output->param('text' => $text) if($text);
        my $title;
        $title = $obvius->get_version_field($vdoc, 'title') if($vdoc);
        $title ||= '';
        $title = 'Re: ' . $title unless($title =~ /^\s*Re:/i);
        $output->param('title' => $title );

        if($input->param('go')){
            $output->param('go' => 1);

            my $commenton = $input->param('commenton');
            my $parent;
            $parent = $obvius->get_doc_by_id($commenton) if($commenton);

            return OBVIUS_OK unless($parent);

            my $fields = new Obvius::Data;

            my $comment_doctype = $obvius->get_doctype_by_name('SpoergBiotikKommentar');

            for(keys %{$comment_doctype->{FIELDS}}) {
                $fields->param($_ => $comment_doctype->{FIELDS}->{$_}->{DEFAULT_VALUE});
            }

            $fields->param('seq' => '-1.00');
            $fields->param(docdate => strftime('%Y-%m-%d 00:00:00', localtime));


            if(my $title = $input->param('title')) {
                $fields->param('title' => $title);
            } else {
                $output->param('error' => 'Du skal angive en titel');
            }

            if(my $name = $input->param('name')) {
                $fields->param('name' => $name);
            } else {
                $output->param('error' => 'Du skal angive dit navn');
                return OBVIUS_OK;
            }

            if(my $email = $input->param('email')) {
                if($email =~ /^[^@]+@[^@]+\.\w+$/) {
                    $fields->param('email' => $email);
                    $output->param('sender_email' => $email);
                } else {
                    $output->param('error' => 'Den angivne emailadresse er ikke korrekt formateret');
                    return OBVIUS_OK;
                }
            } else {
                $output->param('error' => 'Du skal angive din emailadresse');
                return OBVIUS_OK;
            }

            if(my $kommentar = $input->param('kommentar')) {
                $fields->param('kommentar' => $kommentar);
            } else {
                $output->param('error' => 'Du skal angive en kommentar');
                return OBVIUS_OK;
            }

            my $link1 = $input->param('link1');
            $fields->param('link1' => $link1) if($link1 and $link1 ne 'http://');

            my $link2 = $input->param('link2');
            $fields->param('link2' => $link2) if($link2 and $link2 ne 'http://');

            my $link3 = $input->param('link3');
            $fields->param('link3' => $link3) if($link3 and $link3 ne 'http://');

            my $link4 = $input->param('link4');
            $fields->param('link4' => $link4) if($link4 and $link4 ne 'http://');

            my $name = strftime('k%Y%m%d%H%M%S', localtime);

            my $create_error;

            my $tmpuser = $obvius->{USER};
            $obvius->{USER} = 'admin';
            my ($new_docid, $new_version) = $obvius->create_new_document($parent, $name, $comment_doctype->Id, 'da', $fields, $doc->Owner, $doc->Grp, \$create_error);
            $obvius->{USER} = $tmpuser;

            if($create_error) {
                $output->param('error' => 'Der opstod en fejl ved oprettelsen af din kommentar: '. $create_error);
            } else {
                my $new_doc = $obvius->get_doc_by_id($new_docid);
                $output->param('new_doc_url' => $obvius->get_doc_uri($new_doc));
                $output->param('created' => 1);
            }


        }

    }

    my $is_admin = $input->param('IS_ADMIN');
    $this->admin_handler($input, $output, $doc, $vdoc, $obvius) if($is_admin);


    unless($output->param('mode')) {
        my $comment_doctype = $obvius->get_doctype_by_name('SpoergBiotikKommentar');

        my $categories = $obvius->get_version_field($vdoc, 'category') || [];
        my @categories = map { $_->Name } grep { $_->Id =~ /^10 / and $_->Id !~ /(FOL|GYM|UNI)$/ } @$categories;
        push(@categories, 'Ikke angivet') unless(scalar(@categories));

        my @answers;
        my $answers = $obvius->search([],
                                    "type = " . $answer_doctype->Id . " AND parent = " . $doc->Id,
                                    public => 1,
                                    notexpired => 1,
                                    needs_document_fields => ['parent']
                                ) || [];
        for my $answer (@$answers) {
            my $data;

            $obvius->get_version_fields($answer, ['expert', 'svar', 'niveau', 'category', 'link1', 'link2', 'link3', 'link4']);
            my $expert_path = $answer->Expert;
            my $expert_doc = $obvius->lookup_document($expert_path);
            my $expert_vdoc = $obvius->get_public_version($expert_doc) || $obvius->get_latest_version($expert_doc);

            my $expert = $obvius->get_version_field($expert_vdoc, 'title');

            $data->{expert} = $expert;
            $data->{svar} = $answer->Svar;
            my @links;
            push(@links, $answer->Link1) if($answer->field('link1'));
            push(@links, $answer->Link2) if($answer->field('link2'));
            push(@links, $answer->Link3) if($answer->field('link3'));
            push(@links, $answer->Link4) if($answer->field('link4'));
            $data->{links} = \@links if(scalar(@links));

            $data->{niveau} = $niveau_hash{$answer->Niveau} || 'Ikke angivet';

            $data->{categories} = join(',', @categories);

            $data->{docid} = $answer->DocId;

            my $comments = $comment_doctype->get_comments_recursive($obvius, $answer->DocId, 1);

            $data->{comments} = $comments if($comments);

            push(@answers, $data);

        }

        use Data::Dumper;
        print STDERR Dumper(\@answers);

        $output->param(answers => \@answers) if(scalar(@answers));
        $output->param(nr_answers => scalar(@answers));
    }

    return OBVIUS_OK;
}

sub admin_handler {
    my ($this, $input, $output, $doc, $vdoc, $obvius) = @_;

    $output->param('is_admin' => 1);

    my $mode = $input->param('mode');
    if($mode eq 'afvis') {
        $output->param('mode' => 'afvis');
    }
    if($mode eq 'afvis_search') {
        unless(my $searchstring = $input->param('searchstring')) {
            $output->param('mode' => 'afvis');
        } else {
            $output->param('mode' => 'afvis_search');
            my $docs = $obvius->search(
                                        ['title', 'spoergsmaal'],
                                        "type = " . $this->Id . " AND (title LIKE '%$searchstring%' OR spoergsmaal LIKE '%$searchstring%')",
                                        public => 1,
                                        notexpired => 1
                                );
            $output->param('results' => $docs) if($docs);
        }
    }
    if($mode eq 'afvis_send') {
        $output->param('mode' => 'afvis_send');

        # Get all fields from current version
        $obvius->get_version_fields($vdoc, 255);

        my $docfields = $vdoc->fields;

        # Hide it good away
        $docfields->param('seq' => -1000);

        # Make sure it doesn't show up where it shoudln't
        $docfields->param('eksperter' => []);

        #make sure there is no public version of the question:
        if(my $v = $obvius->get_public_version($doc)) {
            my $backup_user = $obvius->{USER};
            $obvius->{USER} = 'admin';
            $obvius->unpublish_version($v);
            $obvius->{USER} = $backup_user;
        }

        # create a new version
        my $backup_user = $obvius->{USER};
        $obvius->{USER} = 'admin';
        my $version = $obvius->create_new_version($doc, $vdoc->Type, $vdoc->Lang, $docfields);
        $obvius->{USER} = $backup_user;
        unless($version) {
            $output->param('error' => 'Fejl under oprettelse af ny version af spørgsmålsdokumentet');
        } else {
            my @link_ids = map { s/^afvis_//i; $_ } grep { /afvis_\d+/i } $input->param;
            my @links;
            for(@link_ids) {
                my $d = $obvius->get_doc_by_id($_);
                push(@links, $obvius->get_doc_uri($doc));
            }
            $output->param('links' => \@links) if(scalar(@links));
            $output->param('reason' => $input->param('reason'));

            $obvius->get_version_fields($vdoc, ['name', 'email']);
            $output->param('spoerger' => $vdoc->field('name'));
            $output->param('spoerger_email' => $vdoc->field('email'));
        }
    }


    # Godkend modes
    if($mode eq 'tilknyteksperter') {
        $output->param('mode' => 'tilknyteksperter');
    }
    if($mode eq 'tilknyteksperter2') {
        my @expertgroups = map { s/^ekspertgroup_//i; $_ } grep { /^ekspertgroup_/i } $input->param;
        $output->param('mode' => 'tilknyteksperter2');

        my @selected;
        for(@expertgroups) {
            my $experts = $obvius->get_expertgroup($_) || [];
            push(@selected, @$experts);
        }

        my $expert_doctype = $obvius->get_doctype_by_name('Expert');
        my $experts = $obvius->search(
                                        ['title', 'email', 'ask_the_experts'],
                                        "type = " . $expert_doctype->Id . " AND ask_the_experts > 0",
                                        public => 1,
                                        notexpired => 1
                                    ) || [];
        my @experts;
        for my $exp (@$experts) {
            my $d = $obvius->get_doc_by_id($exp->DocId);
            my $url = $obvius->get_doc_uri($d);
            my $data;
            $data->{name} = $exp->Title;
            $data->{email} = $exp->Email;
            $data->{docid} = $exp->DocId;
            $data->{url} = $url;
            $data->{checked} = 1 if(grep {$_ == $exp->DocId} @selected);
            push(@experts, $data);
        }
        $output->param('experts' => \@experts);
    }
    if($mode eq 'sendtileksperter') {
        $output->param('mode' => 'sendtileksperter');
        my @expert_docids = map { s/^ekspert_//i; $_ } grep { /^ekspert_\d+/i } $input->param;

        unless(scalar(@expert_docids)) {
            $output->param('error' => 'Du har ikke valgt nogen eksperter');
            return OBVIUS_OK;
        }

        my $expert_doctype = $obvius->get_doctype_by_name('Expert');
        my $where = "type = " . $expert_doctype->Id;
        $where .= " AND docid IN (" . join(", ", @expert_docids) . ")";
        my $experts = $obvius->search(
                                        ['title', 'email'],
                                        $where,
                                        public => 1,
                                        notexpired => 1
                                ) || [];

        unless(scalar(@$experts)) {
            $output->param('error' => 'Kunne ikke finde nogen af de angivne eksperter');
            return OBVIUS_OK;
        }

        my @expertlist = map { $_->Email } @$experts;

        # Create a new version with the expertlist and publish it.

        # Get all fields from current version
        $obvius->get_version_fields($vdoc, 255);

        my $docfields = $vdoc->fields;

        # Make sure it's not hidden
        $docfields->param('seq' => 1);

        # Make sure it doesn't show up where it shoudln't
        $docfields->param('eksperter' => \@expertlist);

        # create a new version
        my $backup_user = $obvius->{USER};
        $obvius->{USER} = 'admin';
        my $version = $obvius->create_new_version($doc, $vdoc->Type, $vdoc->Lang, $docfields);
        $obvius->{USER} = $backup_user;
        unless($version) {
            $output->param('error' => 'Fejl under oprettelse af ny version af spørgsmålsdokumentet');
        } else {
            # Publish the version
            my $new_vdoc = $obvius->get_version($doc, $version);

            my $publish_error;

            # Start out with som defaults
            $obvius->get_version_fields($new_vdoc, 255, 'PUBLISH_FIELDS');

            # Set published
            my $publish_fields = $new_vdoc->publish_fields;
            $publish_fields->param(PUBLISHED => strftime('%Y-%m-%d %H:%M:%S', localtime));

            my $backup_user = $obvius->{USER};
            $obvius->{USER} = 'admin'; # XXX Don't try this at home
            $obvius->publish_version($new_vdoc, \$publish_error);
            $obvius->{USER} = $backup_user;

            if($publish_error) {
                $output->param(error => "Vi kunne ikke offentliggøre dit svar på grund af følgende fejl: $publish_error");
            } else {
                # Good the new version is created and published without errors.
                # Now let's tell the experts, that they should write their answers

                my @experts;
                for my $exp(@$experts) {
                    push(@experts, {name => $exp->Title, email => $exp->Email});
                }

                $output->param('experts_to_mail' => \@experts);

                # Get these for the email to the experts
                $obvius->get_version_fields($vdoc, [ 'link1', 'link2', 'link3', 'link4' ]);
                my @links;
                push(@links, $vdoc->Link1) if($vdoc->field('link1'));
                push(@links, $vdoc->Link2) if($vdoc->field('link2'));
                push(@links, $vdoc->Link3) if($vdoc->field('link3'));
                push(@links, $vdoc->Link4) if($vdoc->field('link4'));
                $output->param('links' => \@links) if(scalar(@links));
            }
        }

    }
}

1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Obvius::DocType::Spoergsmaal - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Obvius::DocType::Spoergsmaal;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Obvius::DocType::Spoergsmaal, created by h2xs. It looks like the
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
