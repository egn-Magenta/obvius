package Obvius::DocType::Lecture;

# $Id$

use strict;
use warnings;

use Obvius;
use Obvius::DocType;

our @ISA = qw( Obvius::DocType );
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub action {
    my ($this, $input, $output, $doc, $vdoc, $obvius) = @_;

    return OBVIUS_OK unless($input->param('mode') and $input->param('mode') eq 'bestil');

    $output->param('mode' => 'bestil');

    my $expert_doc = $obvius->get_doc_by_id($doc->Parent);
    my $expert_vdoc = $obvius->get_public_version($expert_doc) || $obvius->get_latest_version($expert_doc);

    if($input->param('go')) {

        unless($input->param('email') and $input->param('email') =~ /^\w+@[\w-]+\.\w+$/) {
            $output->param('error' => "Manglende eller ikke korrekt emailadresse");
            return OBVIUS_OK;
        }

        unless($input->param('name')) {
            $output->param('error' => "Du skal angive et navn");
            return OBVIUS_OK;
        }

        unless($input->param('message')) {
            $output->param('error' => "Du skal angive en besked");
            return OBVIUS_OK;
        }

        $obvius->get_version_fields($expert_vdoc, ['name', 'email']);
        $output->param('expertname' => $expert_vdoc->field('name'));
        $output->param('expertemail' => $expert_vdoc->field('email'));

        $output->param('sendername' => $input->param('name'));
        $output->param('senderemail' => $input->param('email'));
        $output->param('sendertext' => $input->param('message'));

        $output->param('send_mail' => 1);
    } else {
        $output->param('expertname' => $obvius->get_version_field($expert_vdoc, 'name'));
    }

    return OBVIUS_OK;
}

sub alternate_location {
    my ($this, $doc, $vdoc, $obvius) = @_;

    $this->tracer($doc, $vdoc, $obvius) if ($this->{DEBUG});

    $obvius->get_version_fields($vdoc);

    my $url = $vdoc->field('url');
    return undef unless ($url);

    my $content = $vdoc->field('content');
    return (defined $content and length($content) == 0) ? $url : undef;
}

1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Obvius::DocType::Lecture - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Obvius::DocType::Lecture;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Obvius::DocType::Lecture, created by h2xs. It looks like the
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
