package WebObvius;

########################################################################
#
# WebObvius.pm - perl-modules for handling the web-part of Obvius.
#
# Copyright (C) 2001-2004 Magenta Aps, Denmark (http://www.magenta-aps.dk/)
#                         aparte A/S, Denmark (http://www.aparte.dk/),
#
# Authors: René Seindal,
#          Adam Sjøgren (asjo@magenta-aps.dk).
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

require Exporter;
our @ISA = qw( Exporter );
our @EXPORT_OK = qw( parse_editpage_fieldlist );

our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub parse_editpage_fieldlist {
    my ($this, $fieldlist, $doctype, $obvius) = @_;

    my @fieldlist;
    foreach (split /\n/, $fieldlist) {
	$_=~/^(\w+)\s?(.*)$/;
	my ($name, $rest)=($1, $2);
        $rest=~s/([^\\]);/$1¤/g; # This is not so nice
	my ($title, $opts) = map { s/\\;/;/g; $_; } split /¤/, $rest;
	my @options;
	if ($opts) {
	    $opts =~ s/\\,/¤/g; # This is quite ugly
	    @options=map { s/¤/,/g; $_ } (split /\s*[,=]\s*/, $opts);
	}
	my %f=(
	       title=>$title,
	       fieldspec=>$obvius->get_fieldspec($name, $doctype),
	      );
	$f{options}={ @options } if (@options);

	die "No fieldspec for $name ($_)!\n" unless ($f{fieldspec});
	push @fieldlist, \%f;
    }
    return \@fieldlist;
}


1;
__END__

=head1 NAME

WebObvius - Top of the web-application part for Obvius.

=head1 SYNOPSIS

  use WebObvius;

  $this->parse_editpages_fieldlist($fieldlist, $doctype, $obvius);

=head1 DESCRIPTION

parse_editpages_fieldlist() - parses the fieldlist from an editpage
and returns a ref to a list with each field nicely included as a hash
with title, fieldspec and options.

=head1 AUTHOR

René Seindal,
Adam Sjøgren E<lt>asjo@magenta-aps.dkE<gt>

=head1 SEE ALSO

L<WebObvius::Site>.

=cut
