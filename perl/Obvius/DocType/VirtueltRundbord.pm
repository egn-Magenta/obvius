package Obvius::DocType::VirtueltRundbord;

# $Id$

use strict;
use warnings;

use Obvius;
use Obvius::DocType;

use POSIX qw(strftime);

our @ISA = qw( Obvius::DocType );
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub action {
    my ($this, $input, $output, $doc, $vdoc, $obvius) = @_;

    my $mode = $input->param('mode') || 'dummy';

    my $accepted_modes = {
                            phorumjump => 1,
                            resume => 1,
                            kommenter => 1
                        };
    $mode = undef unless($accepted_modes->{$mode});

    unless($mode) {
        $obvius->get_version_fields($vdoc, ['docdate', 'enddate', 'debatleder']);

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

    } else {
        $output->param('mode' => $mode);

        if($mode eq 'phorumjump') {
            my $phorumname = $obvius->get_version_field($vdoc, 'phorumname');
            my $phorumid;
            $phorumid = $obvius->get_phorum_id_by_name($phorumname) if($phorumname);
            $output->param('obvius_redirect' => "http://forum.biotik.dk/forum/read.php?f=$phorumid") if($phorumid);
        }

        if($mode eq 'kommenter') {
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
        }
    }

    return OBVIUS_OK;
}

1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Obvius::DocType::VirtueltRundbord - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Obvius::DocType::VirtueltRundbord;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Obvius::DocType::VirtueltRundbord, created by h2xs. It looks like the
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
