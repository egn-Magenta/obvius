package Obvius::DocType::HandlingsplansSkema;

# $Id$

use strict;
use warnings;

use Obvius;
use Obvius::DocType;

use Data::Dumper;

our @ISA = qw( Obvius::DocType );
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub action {
    my ($this, $input, $output, $doc, $vdoc, $obvius) = @_;

    my $rows = $obvius->get_version_field($vdoc, 'skema') || [];

    my @sorted_rows =  sort {
                                    my ($_a) = ($a =~ /^(\d+)/);
                                    my ($_b) = ($b =~ /^(\d+)/);
                                    $_a <=> $_b;
                                } @$rows;

    my @rows;
    for(@sorted_rows) {
        my ($nr, $type, $tekst1, $tekst2, $tekst3) = split(/¤/, $_);
        push(@rows, {
                                nr => $nr,
                                type => $type,
                                tekst1 => $tekst1,
                                tekst2 => $tekst2,
                                tekst3 => $tekst3
                            });
    }

    $output->param('rows' => \@rows);

    return OBVIUS_OK;
}

1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Obvius::DocType::HandlingsplansSkema - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Obvius::DocType::HandlingsplansSkema;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Obvius::DocType::HandlingsplansSkema, created by h2xs. It looks like the
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
