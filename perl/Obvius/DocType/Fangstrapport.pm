package Obvius::DocType::Fangstrapport;

########################################################################
#
# Fangstrapport.pm - Sportsfiskeren
#
# Copyright (C) 2002-2004 aparte, Denmark (http://www.aparte.dk/)
#
# Author: Adam Sjøgren (asjo@magenta-aps.dk)
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

# action($input, $output, $doc, $vdoc, $obvius)
#
#    - directs control to the function 'createdocument' if this is
#      requested by the parameter 'mode' on the input-object ($input)
#
sub action {
    my ($this, $input, $output, $doc, $vdoc, $obvius) = @_;

    my $mode=$input->param('mode') || '';

    if ($mode eq 'createdocument') {
	return OBVIUS_ERROR unless ($this->createdocument($input, $output, $doc, $vdoc, $obvius));
    }

    return OBVIUS_OK;
}

sub createdocument {
    my ($this, $input, $output, $doc, $vdoc, $obvius) = @_;

    my $creator=$obvius->get_doctype_by_name('CreateDocument');

    # Create document
    $input->param(op=>'createdocument');

    my $session=$input->param('session');
    if (ref $session) {
        # defined?!
        map {
            $input->param($_=>$session->{$_}) if ($session->{$_} or
                                                  (exists $session->{$_} and $session->{$_} eq '0'));
                                              } keys %$session;
    }

    #  Join special field fangst:
    if (ref $input->param('fangst') eq 'ARRAY') {
	$input->param(fangst=>join "\n", @{$input->param('fangst')});
    }
    $creator->action(
		     $input, $output, $doc, $vdoc, $obvius,
		     doctype=>$obvius->get_doctype_by_name('Fangstrapport'),
		     publish_mode=>'immediate',
		     language=>'da',
		    );
    # Create image
    if ($input->param('picture')) {
	my $image_creator=$obvius->get_doctype_by_name('FiskeKalenderOpret');
	$image_creator->create_image($output, $obvius, $output->param('new_doc'), 'billede', $input->{_INCOMING_PICTURE});
    }

    return 1;
}

1;
__END__

=head1 NAME

Obvius::DocType::Fangstrapport - Perl module for Sportsfiskerens fangstrapport

=head1 SYNOPSIS

  (used automatically by Obvius)

=head1 DESCRIPTION

Obvius::DocType::Fangstrapport uses methods from
Obvius::DocType::CreateDocument and Obvius::DocType::FiskeKalenderOpret.

=head1 AUTHOR

Adam Sjøgren (asjo@magenta-aps.dk)

=head1 SEE ALSO

L<Obvius::DocType::CreateDocument>, L<Obvius::DocType::FiskeKalenderOpret>.

=cut
