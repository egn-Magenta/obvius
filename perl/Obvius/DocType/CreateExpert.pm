package Obvius::DocType::CreateExpert;

########################################################################
#
# CreateExpert.pm - BioTIK expert creation
#
# Copyright (C) 2002 aparte, Denmark (http://www.aparte.dk/)
#
# Author: Jørgen Ulrik Balslev Krag <jubk@magenta-aps.dk>
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

use Data::Dumper;

use Image::Size;

use Digest::MD5 qw(md5_hex);
use Image::Magick;

use POSIX qw(strftime);

our @ISA = qw( Obvius::DocType );
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;


our $signup_data = {
                        stamdata => {
                                        title => '.+',
                                        name => '.+',
                                        institution => '.+',
                                        road => '.+',
                                        zipcode => '^\d\d\d\d$',
                                        town => '.+',
                                        phone => '\d\d.?\d\d.?\d\d.?\d\d',
                                        fax => '',
                                        email => '^.*@.*$',
                                        picture => 'special',
                                    },
                        ekspertise => {
                                        'category' => 'special',
                                        'area_other' => '',
                                        'level_extra' => '^[0123]$',
                                        'level_EOF' => '^[0123]$',
                                        'level_ERV' => '^[0123]$',
                                        'level_ETI' => '^[0123]$',
                                        'level_FRE' => '^[0123]$',
                                        'level_FOD' => '^[0123]$',
                                        'level_IND' => '^[0123]$',
                                        'level_JUR' => '^[0123]$',
                                        'level_LAN' => '^[0123]$',
                                        'level_MIL' => '^[0123]$',
                                        'level_SAO' => '^[0123]$',
                                        'level_SOC' => '^[0123]$',
                                        'level_SUN' => '^[0123]$',
                                        'level_TEO' => '^[0123]$',
                                    },
                        services => {
                                        expert_db => 'special',
                                        ask_the_experts => 'special',
                                        lectures_db => 'special'
                                    },
                        expert_db => {
                                        research_area => '.+',
                                        link1 => 'special',
                                        link2 => 'special',
                                        link3 => 'special',
                                        link1_desc => 'special',
                                        link2_desc => 'special',
                                        link3_desc => 'special'
                                    },
                        ask_the_experts => {}, # Nothing.. Just a confirmation
                        ekspertsem => {}, # Ditto
                        lectures_db => {
                                        category => 'special',
                                        title => '\w+',
                                        content => '\w+',
                                        country_part => 'special',
                                        fee => ''
                                    }
                };

sub action {
    my ($this, $input, $output, $doc, $vdoc, $obvius) = @_;

    $output->param('disable_tilbage' => 1);
    $output->param('disable_print' => 1);

    # Handle popup stuff in mason
    if($input->param('bare') and $input->param('popup')) {
        $output->param('popup' => 1);
        return OBVIUS_OK;
    }

    # Handle admin page
    return $this->admin_action($input, $output, $doc, $vdoc, $obvius) if($input->param('IS_ADMIN'));

    # Session handling
    $output->param(Obvius_SIDE_EFFECTS => 1);
    my $session = $input->param('SESSION') || {};
    if($session->{_session_id}) {
        $output->param('SESSION_ID' => $session->{_session_id});
    }

    my $page = $input->param('page') || '';

    # Go directly to stamdata;
    $page ||= 'stamdata';

    $output->param(page => $page);

    if($page eq 'stamdata') {
        return OBVIUS_OK unless($input->param('submit'));

        # Good we have submitted data, now validate it.

        # Handle special field: picture
        if(my $picture = $input->param('_incoming_picture')) {
            $session->{picture} = $picture;
        }

        # handle other fields
        my ($invalid_fields, $missing_fields) = $this->validate_page_data($input, $page);
        if(scalar(@$invalid_fields) or scalar(@$missing_fields)) {
            $output->param(invalid_fields => $invalid_fields);
            $output->param(missing_fields => $missing_fields);
            # put the input back in the form
            for(keys %{$signup_data->{$page}}) {
                $output->param($_ => $input->param($_));
            }
        } else {
            # Save the input data on the session
            for(keys %{$signup_data->{$page}}) {
                $session->{document}->{$_} = $input->param($_);
            }
            # now go on to the 'ekspertise' page
            $input->param(submit => '');
            $page = 'ekspertise';
            $output->param(page => $page);

            # Save the session unless it is already set
            unless($session->{_session_id}){
                $output->param('SESSION' => $session);
            }
        }
    }
    if($page eq 'ekspertise') {
        return OBVIUS_OK unless($input->param('submit'));

        # Start out with validating the fields:
        my @invalid_fields;
        my ($invalid_fields, $missing_fields) = $this->validate_page_data($input, $page);
        if(scalar(@$invalid_fields) or scalar(@$missing_fields)) {
            $output->param(invalid_fields => $invalid_fields);
            $output->param(missing_fields => $missing_fields);
            # put the input back in the form
            for(keys %{$signup_data->{$page}}) {
                $output->param($_ => $input->param($_));
            }
        } else {
            # save the data..
            my $category_fieldspec = $obvius->get_fieldspec('category');
            my $category_fieldtype = $category_fieldspec->{FIELDTYPE};

            my @categories;
            for(keys %{$signup_data->{$page}}) {
                my $value = $input->param($_);
                $session->{document}->{$_} = $value;
                # If we have expertise in some area add it the documents categories
                if($value and /^level_(...)$/) {
                    $_ = 'SAØ' if($_ eq 'SAO');
                    $_ = 'FØD' if($_ eq 'FOD');
                    my $id = "10 $1";
                    my $obj = $category_fieldtype->copy_in($obvius, $category_fieldspec, $id);
                    push(@categories, $obj) if($obj);
                }
            }
            $session->{document}->{category} = \@categories if(scalar(@categories));

            #Go on to the next page
            $input->param(submit => '');
            $page = 'services';
            $output->param(page => $page);

            # Make session notice the changes to ->{document}
            $session->{document} = $session->{document};
        }
    }
    if($page eq 'services') {
        return OBVIUS_OK unless($input->param('submit'));

        # Just save a list of the pages we need to go to next.
        my @pages_to_go;
        if($input->param('expert_db')) {
            $session->{document}->{expert_db} = 1;
            push(@pages_to_go, 'expert_db');
        }
        if($input->param('ask_the_experts')) {
            $session->{document}->{ask_the_experts} = 1;
            push(@pages_to_go, 'ask_the_experts');
        }
        if($input->param('ekspertsem')) {
            $session->{document}->{ekspertsem} = 1;
            push(@pages_to_go, 'ekspertsem');
        }
        if($input->param('lectures_db')) {
            $session->{document}->{lectures_db} = 1;
            push(@pages_to_go, 'lectures_db');
        }

        # On to the next page
        $input->param(submit => '');
        $page = shift(@pages_to_go) || 'final';
        $session->{pages_to_go} = \@pages_to_go;
        $output->param(page => $page);

        # Make session notice the changes to ->{document}
        $session->{document} = $session->{document};
    }
    if($page eq 'expert_db') {
        return OBVIUS_OK unless($input->param('submit'));

        my @invalid_fields;
        my $area_value = $input->param('research_area');
        my $regexp = $signup_data->{expert_db}->{research_area};
        if($area_value and $area_value =~ /$regexp/) {
            $session->{document}->{'research_area'} = $area_value;
        } else {
            push(@invalid_fields, 'research_area');
        }
        if(scalar(@invalid_fields)) {
            $output->param(invalid_fields => \@invalid_fields);
            # put the input back in the form
            for(keys %{$signup_data->{$page}}) {
                $output->param($_ => $input->param($_));
            }
        } else {

            for( ('link1', 'link2', 'link3') ) {
                if(my $value = $input->param($_)) {
                    $value = 'http://' . $value if($value !~ /^http:\/\//);
                    my $desc = $input->param($_ . '_desc') || $value;
                    $session->{document}->{$_} = $value;
                    $session->{document}->{$_ . '_desc'} = $desc;
                }
            }

            # On to the next page
            $input->param(submit => '');
            $page = shift(@{$session->{pages_to_go}}) || 'final';
            $session->{pages_to_go} = $session->{pages_to_go}; # #¤%"#¤& Bloody session
            $output->param(page => $page);

            # Make session notice the changes to ->{document}
            $session->{document} = $session->{document};
        }
    }
    if($page eq 'ask_the_experts') {
        return OBVIUS_OK unless($input->param('submit'));

        # Don't do anything, just go on

        # On to the next page
        $input->param(submit => '');
        $page = shift(@{$session->{pages_to_go}}) || 'final';
        $session->{pages_to_go} = $session->{pages_to_go};
        $output->param(page => $page);
    }
    if($page eq 'ekspertsem') {
        return OBVIUS_OK unless($input->param('submit'));

        # Don't do anything, just go on

        # On to the next page
        $input->param(submit => '');
        $page = shift(@{$session->{pages_to_go}}) || 'final';
        $session->{pages_to_go} = $session->{pages_to_go};
        $output->param(page => $page);
    }
    if($page eq 'lectures_db') {
        return OBVIUS_OK unless($input->param('submit') || $input->param('submit_continue'));

        if($input->param('submit')) {
            # do failcheck
            my ($invalid_fields, $missing_fields) = $this->validate_page_data($input, $page);
            if(scalar(@$invalid_fields) or scalar(@$missing_fields)) {
                $output->param(invalid_fields => $invalid_fields);
                $output->param(missing_fields => $missing_fields);
                # put the input back in the form
                for(keys %{$signup_data->{$page}}) {
                    $output->param($_ => $input->param($_));
                }
                for( ('folkeskole', 'gymnasium', 'universitet',
                      'country_part_jylland', 'country_part_fyn',
                      'country_part_sjaelland') ) {
                    $output->param($_ => $input->param($_));
                }
            } else {
                # Add to list of lectures
                my $country_part_fieldspec = $obvius->get_fieldspec('country_parts');
                my $country_part_fieldtype = $country_part_fieldspec->{FIELDTYPE};
                my $category_fieldspec = $obvius->get_fieldspec('category');
                my $category_fieldtype = $category_fieldspec->{FIELDTYPE};

                my @country_parts;
                my @categories;

                push(@country_parts, $country_part_fieldtype->copy_in($obvius, $country_part_fieldspec, 'jylland')) if($input->param('country_part_jylland'));
                push(@country_parts, $country_part_fieldtype->copy_in($obvius, $country_part_fieldspec, 'fyn')) if($input->param('country_part_fyn'));
                push(@country_parts, $country_part_fieldtype->copy_in($obvius, $country_part_fieldspec, 'sjælland')) if($input->param('country_part_sjaelland'));

                push(@categories, $category_fieldtype->copy_in($obvius, $category_fieldspec, '10 FOL')) if($input->param('folkeskole'));
                push(@categories, $category_fieldtype->copy_in($obvius, $category_fieldspec, '10 GYM')) if($input->param('gymnasium'));
                push(@categories, $category_fieldtype->copy_in($obvius, $category_fieldspec, '10 UNI')) if($input->param('universitet'));

                my $lecture;
                $lecture->{title} = $input->param('title');
                $lecture->{content} = $input->param('content');
                $lecture->{fee} = $input->param('fee');
                $lecture->{country_parts} = \@country_parts if(scalar(@country_parts));
                $lecture->{category} = \@categories if(scalar(@categories));

                # make sure we have an array
                $session->{lectures} = [] unless($session->{lectures});

                # Add the lecture
                push(@{$session->{lectures}}, $lecture);
                $session->{lectures} = $session->{lectures};

                # If we can still add lectures tell how many we have got until now...
                if(scalar(@{$session->{lectures}}) < 3) {
                    my @lecture_names;
                    for(@{$session->{lectures}}) {
                        push(@lecture_names, $_->{title});
                    }
                    $output->param(existing_lectures => \@lecture_names);
                } else {
                    # We have all the lectures we can have, go on..
                    $input->param(submit_continue => 1);
                }
            }

        }
        if($input->param('submit_continue')) {
            # go on to final page..
            $input->param(submit => '');
            $page = 'final';
            $output->param(page => $page);
        }
    }
    if($page eq 'final') {
        unless($input->param('submit')) {
            # Create temp image for viewing...
            if($session->{picture}) {
                my $img_name = md5_hex($session->{picture}->param('data')) . '.gif';
                my $image = Image::Magick->new;

                # Read picture from data blob
                $image->BlobToImage($session->{picture}->param('data'));

                my $imagesize = '100x140';

                # Resize image to fit in a 100x140 frame
                $image->Resize(geometry=>$imagesize, filter=>'Bessel', blur=> 0.01);

                # Make an transparent fra, sized 100x140
                my $transparent = Image::Magick->new();
                $transparent->Set(size=>$imagesize);
                $transparent->ReadImage('xc:white');
                $transparent->Transparent(color=>'white');

                # Add the original image inside the transparent frame
                $transparent->CompositeImage(compose=>'Over', image=>$image, geometry=>$imagesize, gravity=>'Center', Opague=>1);

                # Write it out to a temp file
                $transparent->Write("/home/httpd/www.biotik.dk/docs/tmp/$img_name");

                # Save the new resized image back to the session.
                $session->{picture}->param(data => $transparent->ImageToBlob());
                $session->{picture}->param(width => '100');
                $session->{picture}->param(height => '140');
                $session->{picture}->param(mimetype => 'image/gif');
                my ($imgsize) = $transparent->Get('filesize');
                $session->{picture}->param(size => $imgsize);

                #Make the session notice the change
                $session->{picture} = $session->{picture};

                $output->param('tmp_img_filename' => '/tmp/' . $img_name);
            }

            $output->param('document' => $session->{document});
            $output->param('lectures' => $session->{lectures}) if($session->{lectures});
        } else {
            #Procedure:
            # Create image
            # Create Expert
            # Move Image below Expert.
            # Add lectures under Expert

            # Set up some stuff we need globally
            my @errors;
            my @lecture_docids;
            my $name = $session->{document}->{title} . ' ' . $session->{document}->{name};
            $name = lc($name);
            $name =~ s/æ/ae/g;
            $name =~ s/ø/oe/g;
            $name =~ s/å/aa/g;
            $name =~ s/[^a-z0-9]/_/g;
            print STDERR "Document name: $name\n";
            my $owner = $doc->{OWNER};
            my $group = $doc->{GRP};
            my $create_error;
            # Password
            my @chars = (0..9, 'A'..'Z', 'a'..'z');
            my $password = '';
            $password .= $chars[rand 62] for (1..8);


            # XXX you didn't see me do this!!!
            my $user_backup = $obvius->{USER};
            $obvius->{USER} = 'admin';

            # Image stuff
            my $image_doctype = $obvius->get_doctype_by_name('Image');
            my $image_docid;
            my $image_doc;
            my $image_path;

            my $parent = $obvius->get_version_field($vdoc, 'where');
            $parent = $obvius->lookup_document($parent);

            if($session->{picture}) {
                my $image_fields = $session->{picture};

                # Get default values
                for(keys %{$image_doctype->{FIELDS}}) {
                    $image_fields->param($_ => $image_doctype->{FIELDS}->{$_}->{DEFAULT_VALUE});
                }

                $image_fields->param(title => 'Billede af ' . $session->{document}->{name});
                $image_fields->param(docdate => strftime('%Y-%m-%d 00:00:00', localtime));
                $image_fields->param(align => 'right');
                $image_fields->param(seq => '-10.00');
                my ($pic_docid, $pic_version) = $obvius->create_new_document($parent, $name . '_picture.gif', $image_doctype->Id, 'da', $image_fields, $owner, $group, \$create_error);
                if($create_error) {
                    print STDERR "Error creating picture for expert: $create_error\n";
                    $create_error = undef;
                } else {
                    $image_doc = $obvius->get_doc_by_id($pic_docid);
                    $image_path = $obvius->get_doc_uri($image_doc);

                    # Publish it
                    my $new_vdoc = $obvius->get_version($image_doc, $pic_version);
                    $obvius->get_version_fields($new_vdoc, 255, 'PUBLISH_FIELDS');
                    # Set published
                    my $publish_fields = $new_vdoc->publish_fields;
                    $publish_fields->param(PUBLISHED => strftime('%Y-%m-%d %H:%M:%S', localtime));
                    my $publish_error;
                    $obvius->publish_version($new_vdoc, \$publish_error);
                    if($publish_error) {
                        print STDERR "Error publishing picture: $publish_error\n";
                    }
                }
            }

            # Expert stuff
            my $expert_docid;
            my $expert_doctype = $obvius->get_doctype_by_name('Expert');

            my $expert_fields = new Obvius::Data;
            # Set default values
            for(keys %{$expert_doctype->{FIELDS}}) {
                $expert_fields->param($_ => $expert_doctype->{FIELDS}->{$_}->{DEFAULT_VALUE});
            }

            # Set values from session
            for(keys %{$session->{document}}) {
                $expert_fields->param($_ => $session->{document}->{$_});
            }

            # Do some title magic
            $expert_fields->param('person_title' => $expert_fields->param('title'));
            $expert_fields->param('title' => $expert_fields->param('person_title') . ' ' . $expert_fields->param('name'));
            $expert_fields->param('short_title' => $expert_fields->param('title'));

            # Image stuff
            if($image_doc) {
                $expert_fields->param('picture' => $image_path);
            } else {
                $expert_fields->param('picture' => '');
            }

            # Password
            $expert_fields->param('password' => $password);

            # Other stuff
            $expert_fields->param(docdate => strftime('%Y-%m-%d 00:00:00', localtime));
            $expert_fields->param(sortorder => '+title');
            $expert_fields->param(subscribeable => 'none');
            if($session->{document}->{expert_db}) {
                $expert_fields->param(seq => '1.00');
            } else {
                $expert_fields->param(seq => '-1.00');
            }

            # Try to create the document
            my ($exp_docid, $expt_version) = $obvius->create_new_document($parent, $name, $expert_doctype->Id, 'da', $expert_fields, $owner, $group, \$create_error);
            if($create_error) {
                push(@errors, $create_error);
            } else {

                my $exp_doc = $obvius->get_doc_by_id($exp_docid);

                # Move picture below expert
                if($image_doc) {
                    my $path = $obvius->get_doc_uri($exp_doc);
                    my $new_pic_path = $path . $name . '_picture.gif';
                    $obvius->rename_document($image_doc, $new_pic_path);
                }

                my $lecture_doctype = $obvius->get_doctype_by_name('Lecture');


                for my $lecture (@{$session->{lectures} || []}) {
                    my $lecture_fields = new Obvius::Data;
                    # Set default values
                    for(keys %{$lecture_doctype->{FIELDS}}) {
                        $lecture_fields->param($_ => $lecture_doctype->{FIELDS}->{$_}->{DEFAULT_VALUE});
                    }

                    for(keys %$lecture) {
                        $lecture_fields->param($_ => $lecture->{$_});
                    }

                    $lecture_fields->param(docdate => strftime('%Y-%m-%d 00:00:00', localtime));
                    $lecture_fields->param(sortorder => '+title');
                    $lecture_fields->param(subscribeable => 'none');
                    $lecture_fields->param(seq => '1.00');


                    my $lecture_name = lc($lecture_fields->param('title'));
                    $lecture_name =~ s/æ/ae/g;
                    $lecture_name =~ s/ø/oe/g;
                    $lecture_name =~ s/å/aa/g;
                    $lecture_name =~ s/[^a-z0-9]/_/g;
                    my ($lec_docid, $lec_version) = $obvius->create_new_document($exp_doc, $lecture_name, $lecture_doctype->Id, 'da', $lecture_fields, $owner, $group, \$create_error);
                    if($create_error) {
                        push(@errors, $create_error);
                    } else {
                        push(@lecture_docids, $lec_docid);
                    }
                }

                $output->param(expert_path => $obvius->get_doc_uri($exp_doc));
            }

            $page = 'thanks';
            $output->param(page => $page);

            my @lectures = map { $obvius->get_doc_uri($obvius->get_doc_by_id($_)) } @lecture_docids;
            $output->param('lecture_docids' => \@lecture_docids);
            $output->param('expert_docid' => $exp_docid);
            $output->param(lectures => \@lectures) if(scalar(@lectures));
            $output->param(errors => \@errors) if(scalar(@errors));

            $obvius->{USER} = $user_backup;
        }
    }
    return OBVIUS_OK;
}

sub admin_action {
    my ($this, $input, $output, $doc, $vdoc, $obvius) = @_;

    return OBVIUS_OK;
}

sub validate_page_data {
    my ($this, $input, $page) = @_;

    my @failed_fields;
    my @missing_fields;

    for(keys %{$signup_data->{$page}}) {
        my $regexp = $signup_data->{$page}->{$_};
        if($regexp) {
            if($regexp ne 'special') {
                my $value = $input->param($_);
                $value = '' unless(defined($value));
                if(length($value) == 0) {
                    push(@missing_fields, $_);
                } else {
                    if($value !~ /$regexp/) {
                        push(@failed_fields, $_);
                    }
                }
            }
        }
    }

    return (\@failed_fields, \@missing_fields);
}
1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Obvius::DocType::CreateExpert - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Obvius::DocType::CreateExpert;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Obvius::DocType::CreateExpert, created by h2xs. It looks like the
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
