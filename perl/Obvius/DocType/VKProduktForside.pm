package Obvius::DocType::VKProduktForside;

# $Id$

use strict;
use warnings;

use Obvius;
use Obvius::DocType;

use Data::Dumper;

use Storable qw(lock_store lock_retrieve);

our @ISA = qw( Obvius::DocType );
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

our $cache_dir;
our $time_file;

BEGIN {
    $cache_dir = '/home/httpd/www.vordingborg.com/var/produktforsidecache/';
    $time_file = '/home/httpd/www.vordingborg.com/var/produktforsidecache/time.txt';

    mkdir($cache_dir) unless(-d $cache_dir);
    unless(-f $time_file) {
        open(FH, '>' . $time_file) or die "huh: $!\n";
        print FH "";
        close(FH);
    }
}

sub action {
    my ($this, $input, $output, $doc, $vdoc, $obvius) = @_;

    my $prod_doctype = $obvius->get_doctype_by_name('VKProdukt');
    my $where = "type = " . $prod_doctype->Id;
    $where .= " AND parent = " . $doc->Id;


    # This should be cached somehow but sessions seems a bad idea.
    # Maybe some homebrewed Storable stuff.
    my $docs = $this->retrive_from_cache($doc->Id);
    unless($docs) {
        $docs = $obvius->search(['seq', 'title'], $where,
                                public => 1,
                                notexpired => 1,
                                needs_document_fields => ['parent'],
                                straight_documents_join => 1,
                                order => 'seq, title'
                        ) || [];
        $this->store_in_cache($doc->Id, $docs);
    }
    my $index;
    my $count = 0;
    if(my $showid = $input->param('showid')) {
        for(@$docs) {
            if($_->DocId == $showid) {
                $index = $count;
                last;
            }
            $count++;
        }
    }
    $output->param('index' => $index);

    $output->param('result' => $docs);

    return OBVIUS_OK;
}


sub store_in_cache {
    my ($this, $docid, $data) = @_;

    lock_store({data => $data},  $cache_dir . $docid );
}

sub retrive_from_cache {
    my ($this, $docid) = @_;

    return undef unless(-f $cache_dir . $docid);

    # If someone touched the time file since the storable file was last modified
    # we shouldn't use cache
    return undef if ( (stat $time_file)[9] > (stat $cache_dir . $docid)[9] );

    my $data = lock_retrieve($cache_dir . $docid);

    return($data->{data});
}

1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Obvius::DocType::VKProduktForside - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Obvius::DocType::VKProduktForside;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Obvius::DocType::VKProduktForside, created by h2xs. It looks like the
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
