package Obvius::DocType::Ekspertseminar;

########################################################################
#
# Ekspertseminar.pm - Seminar of experts
#
# Copyright (C) 2002 aparte, Denmark (http://www.aparte.dk/)
#
# Author: Jørgen Ulrik B. Krag (jubk@magenta-aps.dk)
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

use Date::Calc qw(Days_in_Month);

our @ISA = qw( Obvius::DocType );
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub action {
    my ($this, $input, $output, $doc, $vdoc, $obvius) = @_;

    my $mode = $input->param('mode') || 'dummy';

    my $accepted_modes = {
                            phorumjump => 1,
                            resume => 1,
                            kommenter => 1,
                            arkiv => 1,
                            viewmonth => 1,
                            viewday => 1
                        };
    $mode = undef unless($accepted_modes->{$mode});

    unless($mode) {
        $obvius->get_version_fields($vdoc, ['docdate', 'enddate', 'authmethod', 'debatleder']);

        my $startdate = $vdoc->field('docdate');
        my $enddate = $vdoc->field('enddate');

        my $_startdate = $startdate;
        $_startdate =~ s/^(\d\d\d\d)-(\d\d)-(\d\d).*$/$3\.$2\.$1/;
        $output->param('startdate' => $_startdate);

        if(!$enddate or $enddate eq '0000-00-00 00:00:00') {
            $output->param('enddate' => '?');
            $enddate = '99.99.9999';
        } else {
            my $_enddate = $enddate;
            $_enddate =~ s/^(\d\d\d\d)-(\d\d)-(\d\d).*$/$3\.$2\.$1/;
            $output->param('enddate' => $_enddate);
        }

        my $nowdate = strftime('%Y-%m-%d 00:00:00', localtime);
        $output->param('aktivt' => 1) if($startdate le $nowdate and $enddate ge $nowdate);

        my $authmethod = $vdoc->field('authmethod') || 'none';

        if($authmethod eq 'explicit') {
            $output->param(Obvius_SIDE_EFFECTS => 1);
            my $debatleder = $vdoc->field('debatleder');
            my $lederdoc;
            $lederdoc = $obvius->lookup_document($debatleder) if($debatleder);
            my $leder_id;
            $leder_id = $lederdoc->Id if($lederdoc);

            my $deltager_doctype = $obvius->get_doctype_by_name('Debatdeltager');
            my $deltagere = $obvius->search(
                                            [], "type = ". $deltager_doctype->Id . " AND parent = " . $doc->Id,
                                            public => 1,
                                            needs_document_fields => ['parent']
                                        ) || [];
            my @deltagere;
            for(@$deltagere) {
                $obvius->get_version_fields($_, ['email', 'title', 'stilling', 'content', 'picture']);
                my $data = {
                                navn => $_->field('title'),
                                email => $_->field('email'),
                                stilling => $_->field('stilling'),
                                beskrivelse => $_->field('content'),
                                picture => $_->field('picture')
                            };

                if($leder_id and $_->Docid == $leder_id) {
                    $data->{'leder'} = 1;
                    unshift(@deltagere, $data);
                } else {
                    push(@deltagere, $data);
                }
            }

            $output->param('deltagere' => \@deltagere);
        }
    } else {
        $output->param('mode' => $mode);

        if($mode eq 'phorumjump') {
            my $phorumname = $obvius->get_version_field($vdoc, 'phorumname');
            my $phorumid;
            $phorumid = $obvius->get_phorum_id_by_name($phorumname) if($phorumname);
            $output->param('obvius_redirect' => "http://forum.biotik.dk/forum/read.php?f=$phorumid") if($phorumid);
        } elsif($mode eq 'kommenter') {
            return OBVIUS_OK unless($input->param('submit'));

            my @errors;
            my $email = $input->param('email');
            my $name = $input->param('name');
            my $message = $input->param('message');

            if($email and $email =~ /^[^\@]+\@.+\.\w+/) {
                $output->param('email' => $email);
            } else {
                push(@errors, 'Emailadresse mangler eller er ikke korrekt formateret');
            }

            if($name) {
                $output->param('name' => $name);
            } else {
                push(@errors, 'Navn mangler');
            }

            if($message) {
                $output->param('message' => $message);
            } else {
                push(@errors, 'Du skal angive en besked');
            }

            if(scalar(@errors)) {
                $output->param('errors' => \@errors);
            } else {
                my $leder = $obvius->get_version_field($vdoc, 'debatleder');
                my $lederdoc;
                $lederdoc = $obvius->lookup_document($leder) if($leder and $leder ne '/');
                my $ledervdoc;
                $ledervdoc = $obvius->get_public_version($lederdoc) if($lederdoc);
                if($ledervdoc) {
                    $obvius->get_version_fields($ledervdoc, ['title', 'email']);
                    $output->param('lederemail' => $ledervdoc->field('email'));
                    $output->param('ledernavn' => $ledervdoc->field('title'));
                    $output->param('send_mail' => 1);
                } else {
                    $output->param('errors' => [ 'Kunne ikke finde emailadresse på debatlederen' ]);
                }
            }
        } elsif($mode eq 'resume') {
            my $startdate = $vdoc->field('docdate');
            my $enddate = $vdoc->field('enddate');

            my $nowdate = strftime('%Y-%m-%d 00:00:00', localtime);
            $output->param('aktivt' => 1) if($startdate le $nowdate and $enddate ge $nowdate);
        } elsif($mode eq 'arkiv') {
            $output->param(Obvius_DEPENDENCIES => 1);
            my $archive_dir = '/var/www/www.biotik.dk/var/phorum_archives/'; # XXX This should not be hardcoded!

            my $phorumname = $obvius->get_version_field($vdoc, 'phorumname');

            # Convert to dirname
            $phorumname = lc($phorumname);
            $phorumname =~ s/[^a-z0-9_-]/_/;

            if(-d $archive_dir . $phorumname . '/') {
                opendir(DIR, $archive_dir . $phorumname . '/');
                my @files = readdir(DIR);
                closedir(DIR);

                my $datedata;

                my $highest_month = '000000';
                my $lowest_month = '999999';

                for my $filename (@files) {
                    next unless($filename =~ /^(\d\d\d\d)-(\d\d)-(\d\d).txt$/);
                    my $year = $1;
                    my $month = $2;
                    my $day = $3;

                    $datedata->{"$year$month"} ||= {};
                    $datedata->{"$year$month"}->{$day} = 1;

                    my $thismonth = "$year$month";
                    $highest_month = $thismonth if($thismonth > $highest_month);
                    $lowest_month = $thismonth if($thismonth < $lowest_month);
                }

                if($highest_month < $lowest_month) {
                    $output->param('no_archive' => 1);
                    return OBVIUS_OK;
                }

                for my $m ($lowest_month..$highest_month) {
                    my($year, $month) = ($m =~ /^(\d\d\d\d)(\d\d)$/);
                    next if($month > 12 or $month < 1);

                    my $days_in_month = Days_in_Month($year, $month);
                    for(1..$days_in_month) {
                        $_ = "0$_" if($_ < 10);
                        $datedata->{$m} ||= {};
                        $datedata->{$m}->{$_} ||= 0;
                    }
                }

                $output->param('datedata' => $datedata);
            } else {
                $output->param('no_archive => 1');
                return OBVIUS_OK;
            }

        } elsif($mode eq 'viewmonth') {
            my $month;
            return OBVIUS_OK unless($month = $input->param('month'));
            if($month =~ /^(\d\d\d\d)(\d\d)$/) {
                my $year = $1;
                $month = $2;

                $output->param('year' => $year);
                $output->param('month' => $month);

                if($input->param('plaintext')) {
                    $output->param(Obvius_DEPENDENCIES => 1);
                    my $archive_dir = '/home/httpd/www.biotik.dk/var/phorum_archives/'; # XXX This should not be hardcoded!
                    my $phorumname = $obvius->get_version_field($vdoc, 'phorumname');

                    # Convert to dirname
                    $phorumname = lc($phorumname);
                    $phorumname =~ s/[^a-z0-9_-]/_/;

                    if(-d $archive_dir . $phorumname . '/') {
                        opendir(DIR, $archive_dir . $phorumname . '/');
                        my @files = readdir(DIR);
                        closedir(DIR);

                        @files = grep { /^$year-$month/ } @files;

                        my $text = '';
                        for(@files) {
                            if(open(FILE, $archive_dir . $phorumname . '/' . $_)) {
                                my @lines = <FILE>;
                                close(FILE);
                                my $date = $_;
                                $date =~ s/\.txt$//;
                                $text .= "\nB<$date>\n\n" . join('', @lines);
                            }
                        }

                        $output->param('text' => $text) if($text);

                    }
                } else {
                    my $month_resumes = $obvius->get_version_field($vdoc, 'maanedsresume') || [];

                    my @tmp = map { s/^\d\d\d\d-\d\d¤//; $_ } grep { /^$year-$month¤/ } @$month_resumes;

                    $output->param('text' => $tmp[0]) if($tmp[0]);
                }
            }
        } elsif($mode eq 'viewday') {
            my $day;
            return OBVIUS_OK unless($day = $input->param('day'));
            if($day =~ /^(\d\d\d\d)(\d\d)(\d\d)/) {

                my $year = $1;
                my $month = $2;
                my $day = $3;

                $output->param(Obvius_DEPENDENCIES => 1);
                my $archive_dir = '/home/httpd/www.biotik.dk/var/phorum_archives/'; # XXX This should not be hardcoded!
                my $phorumname = $obvius->get_version_field($vdoc, 'phorumname');

                # Convert to dirname
                $phorumname = lc($phorumname);
                $phorumname =~ s/[^a-z0-9_-]/_/;

                if(open(FILE, $archive_dir . $phorumname . '/' . "$year-$month-$day.txt")) {
                    my @lines = <FILE>;
                    close(FILE);
                    my $text = join('', @lines);

                    $output->param('text' => $text);
                    $output->param('day' => "$day.$month.$year");

                } else {
                    return OBVIUS_OK;
                }
            } else {
                return OBVIUS_OK;
            }
        }
    }

    return OBVIUS_OK;
}

1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Obvius::DocType::Ekspertseminar - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Obvius::DocType::Ekspertseminar;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Obvius::DocType::Ekspertseminar, created by h2xs. It looks like the
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
