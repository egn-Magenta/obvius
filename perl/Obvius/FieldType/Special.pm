# $Id$

package Obvius::FieldType::Special;

use 5.006;
use strict;
use warnings;

use Obvius::FieldType;

our @ISA = qw( Obvius::FieldType );
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

# Given the thing that is in the database-field, give back the relevant
# piece of data (object, whatever):
sub copy_in {
    my ($this, $obvius, $fspec, $value) = @_;

    if ($this->{VALIDATE_ARGS} eq 'DocumentPathCheck') {
        return undef unless($value);
        if (my $doc=$obvius->get_doc_by_id($value)) {
            return $obvius->get_doc_uri($doc);
        } else {
            return undef;
        }
    }

    if ($this->{VALIDATE_ARGS} eq 'DocidLink') {
        return undef unless(defined($value));

        if ($value =~ /(\d+)\.docid/) {
            my $doc = $obvius->get_doc_by_id($1);
            if($doc) {
                return ($obvius->get_doc_uri($doc));
            } else {
                return $value;
            }
        } else {
            return $value;
        }
    }

    $obvius->log->notice("Obvius::FieldType::Special unknown special type $this->{VALIDATE_ARGS}, falling through.");
    return $value;
}

# Give the relevant piece of data used in Obvius (perl), give back the thing that is
# to be put in the corresponding database-field.
sub copy_out {
    my ($this, $obvius, $fspec, $value) = @_;

    if ($this->{VALIDATE_ARGS} eq 'DocumentPathCheck') {
        if (my $doc=$obvius->lookup_document($value)) {
            return $doc->Id;
        } else {
            return undef;
        }

    }

    if ($this->{VALIDATE_ARGS} eq 'DocidLink') {
        return undef unless(defined($value));

        # If value starts with a / it might be a local URL.
        # If so store it as XX.docid
        if ($value =~ m!^/!) {
            my $doc = $obvius->lookup_document($value);
            if($doc) {
                return $doc->Id . ".docid";
            } else {
                return $value;
            }
        }
    }

    return $value;
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

Obvius::FieldType::Special - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Obvius::FieldType::Special;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Obvius::FieldType::Special, created by h2xs. It looks like the
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
