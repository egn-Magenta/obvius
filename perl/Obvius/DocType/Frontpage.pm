package Obvius::DocType::Frontpage;

########################################################################
#
# Frontpage.pm - Frontpage Document Type
#
# Copyright (C) 2001 Magenta Aps, Denmark (http://www.magenta-aps.dk/)
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

our @ISA = qw( Obvius::DocType );
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub action {
    my ($this, $input, $output, $doc, $vdoc, $obvius) = @_;

    my $cookies = $input->Obvius_COOKIES;

    my $in_profile = $input->param('profile');
    my $profile = $in_profile || 1; # Links etc. defaults to profile 1

    my $text;
    if(! $in_profile) {
        $text = $obvius->get_version_field($vdoc, 'content') || '';
        $profile = '_fp'; # Get the _fp subjects
    } else {
        $obvius->get_version_fields($vdoc, [ 'subject'.$profile.'_text', 'subject'.$profile.'_title', 'subject'.$profile.'_gdt' ]);
        $text = $vdoc->field('subject'.$profile.'_text') || '';
        my $title = $vdoc->field('subject'.$profile.'_title');
        $output->param(override_title => $title) if($title);
        $output->param(gaa_direkte_til => $vdoc->field('subject'.$profile.'_gdt'));
    }
    $output->param(text => $text);

    $obvius->get_version_fields($vdoc, [ 'link'.$profile.'_1', 'link'.$profile.'_2', 'link'.$profile.'_3' ] );
    my @subjects;

    for(1..3) {
        my $linkpath = $vdoc->field('link'.$profile."_".$_);
        my $linkdoc;
        $linkdoc = $obvius->lookup_document($linkpath) if($linkpath);
        my $linkvdoc;
        $linkvdoc = $obvius->get_public_version($linkdoc) || $obvius->get_latest_version($linkdoc) if($linkdoc);

        next unless($linkvdoc);

        $obvius->get_version_fields($linkvdoc, ['title', 'short_title', 'teaser', 'picture']);

        my $url = '';
        $url = $obvius->get_doc_uri($linkdoc) if($linkdoc and $linkvdoc);

        my $from = '';
        if($url =~ /^\/([^\/])([^\/]+)\//) {
            $from = uc($1).$2;
        }

        push(@subjects, {
                            title => $linkvdoc->Short_Title || $linkvdoc->Title || '',
                            teaser => $linkvdoc->Teaser || '',
                            url => $url,
                            from => $from,
                            picture => $linkvdoc->Picture || '',
                            version => $linkvdoc->Version
                    });

    }
    $output->param(subjects => \@subjects);

    return OBVIUS_OK;
}

1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Obvius::DocType::Frontpage - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Obvius::DocType::Frontpage;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Obvius::DocType::Frontpage, created by h2xs. It looks like the
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
