package WebObvius::Storage::Version;

########################################################################
#
# Version.pm - Version storage-type for edit engine.
#
# Copyright (C) 2004 Magenta Aps, Denmark (http://www.magenta-aps.dk/)
#
# Authors: Jens K. Jensen (jensk@magenta-aps.dk),
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

use Carp;

use WebObvius::Storage;

our @ISA = qw( WebObvius::Storage );
our $VERSION="1.0";

# Internal methods:

sub new {
    my ($class, $options, $obvius)=@_;

    $options->{identifiers} = [qw(docid version)];
    my $this=$class->SUPER::new(%$options, obvius=>$obvius);

    my $docid = $this->param('source');
    if ($docid) {
        $obvius->get_doc_by_id($docid) or die "Source document [docid=$docid] not found!\n";
    }

    return $this;
}


sub lookup {
    my ($this, %how)=@_;

    my @existing_identifiers = grep {exists $how{$_}} @{$this->param('identifiers')};

    my $object = {
                  map {
                      $_ => $how{$_}
                  } @existing_identifiers
                 };

    if (scalar(@existing_identifiers) != scalar(@{$this->param('identifiers')})) {
        return ($object, undef);
    }
    else {
        my $document = $this->param('obvius')->get_doc_by_id($how{docid});
        my $version = $how{version};
        my $record_data = $this->param('obvius')->get_version($document, $version) if $version;

        my $record =  {
                       map { $_ => {
                                    value => $record_data->{$_},
                                    status => 'OK',
                                   }
                         } keys %$record_data
                      };
        return ($object, $record);
    }
}


sub search {
    my ($this, $how)=@_;

    my $versions = $this->param('obvius')->search($how->{fields}, $how->{where}, %{$how->{options}} );
use Data::Dumper; print STDERR '$versions: ' . Dumper($versions);
    map {$this->param('obvius')->get_version_fields($_, 255)} @$versions;

    my @results;
    foreach my $v (@$versions) {

        my @fields = $v->param('fields')->param();
        my $field_data = $v->param('fields')->params(@fields);

        my @params = $v->param();
        my $version_data = $v->params(@params);

        delete $version_data->{FIELDS};

        my $data = {%$field_data, %$version_data};

        push @results, {
                        map { lc($_) => {
                                     value => $data->{$_},
                                     status => 'OK',
                                    }
                          } keys %$data
                       };
    }

    return \@results;
}

1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

WebObvius::Storage::Version - Perl extension for blah blah blah

=head1 SYNOPSIS

  use WebObvius::Storage::Version;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for WebObvius::Storage::Version, created by h2xs. It looks like the
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
