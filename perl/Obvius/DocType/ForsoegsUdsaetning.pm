package Obvius::DocType::ForsoegsUdsaetning;

# $Id$

use strict;
use warnings;

use Obvius;
use Obvius::DocType;

our @ISA = qw( Obvius::DocType );
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub action {
    my ($this, $input, $output, $doc, $vdoc, $obvius) = @_;

    # Hent godkendelse
    my $gk_doc_path = $obvius->get_version_field($vdoc, 'gk_godkendelse');
    print STDERR "$gk_doc_path\n";
    my $gk_doc = $obvius->lookup_document($gk_doc_path);
    my $gk_vdoc = $obvius->get_public_version($gk_doc);

    if($gk_vdoc) {
        $obvius->get_version_fields($gk_vdoc, [
                                                'gk_nr', 'gk_produkt', 'gk_ansoeger', 'gk_formaal',
                                                'gk_herbicidres', 'gk_insektres', 'gk_virusres',
                                                'gk_virustype', 'gk_markoergen', 'gk_kommentar'
                                            ]
                                );
        $output->param(gk_url => $gk_doc_path);
        $output->param(gk_nr => $gk_vdoc->Gk_Nr);
        $output->param(produkt => $gk_vdoc->Gk_Produkt);
        $output->param(ansoeger => $gk_vdoc->Gk_Ansoeger);
        $output->param(formaal => $gk_vdoc->Gk_Formaal);
        $output->param(kommentar => $gk_vdoc->Gk_Kommentar);
        my @egenskaber;
        if(my $h_res = $gk_vdoc->Gk_Herbicidres) {
            push(@egenskaber, "Herbicidresistens: $h_res");
        }
        if(my $i_res = $gk_vdoc->Gk_Insektres) {
            push(@egenskaber, "Insektresistens: $i_res");
        }
        if($gk_vdoc->Gk_Virusres) {
            my $v_res = $gk_vdoc->Gk_Virustype;
            push(@egenskaber, "Virusresistens: $v_res");
        }
        if(my $mkgen = $gk_vdoc->Gk_Markoergen) {
            push(@egenskaber, "Markørgen: $mkgen");
        }
        $output->param(egenskaber => \@egenskaber) if(scalar(@egenskaber));
    } else {
        $output->param(gk_nr => 'Ikke offentligt');
        $output->param(produkt => 'Ikke offentligt');
        $output->param(ansoeger => 'Ikke offentligt');
        $output->param(formaal => 'Ikke offentligt');
        $output->param(kommentar => 'Ikke offentligt');
        $output->param(egenskaber => ['Ikke offentligt']);
    }

    return OBVIUS_OK;
}

1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Obvius::DocType::ForsoegsUdsaetning - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Obvius::DocType::ForsoegsUdsaetning;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Obvius::DocType::ForsoegsUdsaetning, created by h2xs. It looks like the
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
