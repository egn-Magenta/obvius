package Obvius::DocType::ForsoegsGodkendelse;

# $Id$

use strict;
use warnings;

use Obvius;
use Obvius::DocType;

our @ISA = qw( Obvius::DocType );
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub action {
    my ($this, $input, $output, $doc, $vdoc, $obvius) = @_;

    my $udsaet_type = $obvius->get_doctype_by_name('ForsoegsUdsaetning');

    my $udsaettelser = $obvius->search(
                                        ['gk_godkendelse'],
                                        'type = ' . $udsaet_type->Id . " AND gk_godkendelse = " . $doc->Id,
                                        'notexpired' => 1,
                                   'public' => 1
                                );
    use Data::Dumper;
    print STDERR Dumper($udsaettelser);
    my @result;
    my $areal_total = 0;
    if($udsaettelser) {
        for(@$udsaettelser) {
            my $doc = $obvius->get_doc_by_id($_->DocId);
            my $url = $obvius->get_doc_uri($doc);

            $obvius->get_version_fields($_, ['gk_areal', 'gk_navn', 'gk_amt']);
            my $areal = $_->Gk_Areal;
            $areal_total += ($areal || 0);
            push(@result, {
                            areal => $_->Gk_Areal,
                            navn => $_->Gk_Navn,
                            amt => $_->Gk_Amt,
                            url => $url
                        });
        }
    }

    $output->param(udsaetninger => \@result) if(scalar(@result));
    $output->param(areal_total => $areal_total);

    return OBVIUS_OK;
}

1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Obvius::DocType::ForsoegsGodkendelse - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Obvius::DocType::ForsoegsGodkendelse;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Obvius::DocType::ForsoegsGodkendelse, created by h2xs. It looks like the
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
