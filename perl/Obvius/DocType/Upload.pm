package Obvius::DocType::Upload;

# $Id$

use strict;
use warnings;

use Obvius;
use Obvius::DocType;

our @ISA = qw( Obvius::DocType );
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

# raw_document_data($document, $version, $obvius)
#    - returns the 'mimetype' and 'udloaddata' fields from the
#      $version object.  If the $document's name ends with '.\w'
#      the name is also returned.
sub raw_document_data {
    my ($this, $doc, $vdoc, $obvius) = @_;

    $this->tracer($doc, $vdoc, $obvius) if ($this->{DEBUG});

    my $fields = $obvius->get_version_fields($vdoc, ['mimetype', 'uploaddata']);

    my $name = $doc->Name || '';
    if($name =~ /\.\w+$/) {
        return ($fields->param('mimetype'), $fields->param('uploaddata'), $name);
    } else {
        return ($fields->param('mimetype'), $fields->param('uploaddata'));
    }
}


1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Obvius::DocType::Upload - Perl extension for blah blah blah

=head1 SYNOPSIS

    use Obvius::DocType::Upload;

=head1 DESCRIPTION

Stub documentation for Obvius::DocType::Upload, created by h2xs. It looks like the
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
