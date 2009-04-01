package Obvius::DocType::FileUpload;

# $Id$

use strict;
use warnings;

use Obvius;
use Obvius::DocType;
use Digest::MD5 qw( md5_hex );
our @ISA = qw( Obvius::DocType );
our $VERSION="1.0";

sub raw_document_data {
     my ($this, $doc, $vdoc, $obvius, $req, $output) = @_;
     my $data =	$req->hostname . ':' . $req->the_request;
     
     print STDERR "DATA: $data\n";
     print STDERR "MD5: " . md5_hex($data) . "\n";
    
     $obvius->get_version_fields($vdoc, ['mimetype', 'title', 'uploadfile']);
     my $path = $vdoc->field('uploadfile');
     return undef if !$path;

     $path = $obvius->{OBVIUS_CONFIG}{DOCS_DIR} . $path;
     $path =~ s|/+|/|g;
     
     my $mime_type = $vdoc->field('mimetype');
     
     
     my ($filename) = $path =~ m|/([^/]+)$|;
     $filename ||= $vdoc->field('title');
     
     $filename =~ s/\s+/_/g;

     local $/;
     my $fh;
     open $fh, $path or die "File not found: $path";
     $data = <$fh>;
     close $fh;
     return ($mime_type, \$data, $filename);
}

1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Obvius::DocType::FileUpload - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Obvius::DocType::FileUpload;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Obvius::DocType::FileUpload, created by h2xs. It looks like the
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
