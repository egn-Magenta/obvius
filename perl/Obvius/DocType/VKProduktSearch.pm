package Obvius::DocType::VKProduktSearch;

# $Id$

use strict;
use warnings;

use Obvius;
use Obvius::DocType;

use Storable qw(store retrieve);

our @ISA = qw( Obvius::DocType );
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub action {
    my ($this, $input, $output, $doc, $vdoc, $obvius) = @_;

    my $session = $input->param('SESSION') || {};

    if($input->param('search')) {
        my $produkt_doctype = $obvius->get_doctype_by_name('VKProdukt');

        my $kategori = $obvius->get_version_field($vdoc, 'skategori');

        my @fields = ('kategori');
        my $where = "type = " . $produkt_doctype->Id . " AND kategori = '$kategori'";
        for my $field ( ('serie', 'stil', 'materiale') ) {
            my $incoming = $input->param($field);
            if($incoming) {
                push(@fields, $field);
                if(ref($incoming) eq 'ARRAY') {
                    $where .= " AND $field IN ('" . join("', '", @$incoming) . "')";
                    for(@$incoming) {
                        $session->{selected}->{$field}->{$_} = 1;
                    }
                } else {
                    $session->{selected}->{$field}->{$incoming} = 1;
                    $where .= " AND $field = '$incoming'";
                }
            }
        }

        if(my $pris = $input->param('pris')) {
            push(@fields, 'pris');
            $pris = [ $pris ] unless(ref($pris) eq 'ARRAY');
            my @pris_conditions;
            for my $p (@$pris) {
                my ($low, $high) = split(/;/, $p);
                if($low == -1) {
                    push(@pris_conditions, "pris < '$high'");
                } elsif($high == -1) {
                    push(@pris_conditions, "pris > '$low'");
                } else {
                    push(@pris_conditions, "pris < $high AND pris >= $low");
                }
                $session->{selected}->{pris}->{$p} = 1;
            }
            $where .= " AND ((" . join(") OR (", @pris_conditions) . "))";
        }

        # Only find documents i own language.
        $where .= " AND lang = '" . $vdoc->Lang . "'";

        $session->{docs} = $obvius->search(
                                    \@fields, $where,
                                    public => 1,
                                    notexpired => 1,
                                    needs_document_fields => ['parent']
                            ) || [];
        $output->param('SESSION' => $session);
    } else {
        $output->param('SESSION_ID' => $session->{_session_id}) if($session->{_session_id});
    }

    if($session->{docs} and scalar(@{$session->{docs}})) {
        my $page = $input->param('p') || 1;
        $this->export_paged_doclist(
                                    5,
                                    $session->{docs},
                                    $output, $obvius,
                                    name=>'result',
                                    page=>$page,
                                    require=>'all',
                                    use_vdoc_data=>1
                                );
    }
    
    $output->param(selectedinfo => $session->{selected});

    return OBVIUS_OK;
}

1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Obvius::DocType::VKProduktSearch - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Obvius::DocType::VKProduktSearch;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Obvius::DocType::VKProduktSearch, created by h2xs. It looks like the
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
