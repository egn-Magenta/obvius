# $Id$

package Obvius::FieldType::Xref;

use 5.006;
use strict;
use warnings;

use Obvius::FieldType;

our @ISA = qw( Obvius::FieldType );
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

use Obvius::Data::Xref;

sub copy_in {
    my ($this, $obvius, $fspec, $value) = @_;

    my ($table, $key) = split('\.', $this->{VALIDATE_ARGS});
    return $value unless ($table);
    $key ||= 'id';

    my $rec = $obvius->get_table_record($table, { $key => $value });
    return $rec ? new Obvius::Data::Xref($rec) : undef;
}

sub copy_out {
    my ($this, $obvius, $fspec, $value) = @_;

    my $key='id';
    if ($this->{VALIDATE_ARGS}) {
	my $table;
	($table, $key) = split('\.', $this->{VALIDATE_ARGS});
    }

    return $value unless (ref $value);
    return $value->{uc($key)} if (ref $value eq 'HASH' and exists $value->{uc($key)});
    return $value->param($key) if ($value->UNIVERSAL::can('param'));
    return undef;
}

sub validate {
    my ($this, $obvius, $fspec, $value, $input) = @_;
    return undef unless (defined $value);
    $value = $this->copy_out($obvius, $fspec, $value);
    return undef unless (defined $value);
    return $this->copy_in($obvius, $fspec, $value);
}



1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Obvius::FieldType::Xref - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Obvius::FieldType::Xref;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Obvius::FieldType::Xref, created by h2xs. It looks like the
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
