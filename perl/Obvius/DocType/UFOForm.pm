package Obvius::DocType::UFOForm;

# $Id$

use strict;
use warnings;

use Obvius;
use Obvius::DocType;

our @ISA = qw( Obvius::DocType );
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub action {
  my ($this, $input, $output, $doc, $vdoc, $obvius) = @_;

  $this->tracer($input, $output, $doc, $vdoc, $obvius) if ($this->{DEBUG});

  # Get the required vfields
  $obvius->get_version_fields($vdoc, [ 'mailto', 'mailmsg' ]);

  # Fail if the required fields are not filled
  return OBVIUS_ERROR unless ($vdoc->Mailto and $vdoc->Mailmsg);

  # Copy each incoming "_parameter_" to outgoing "parameter"
  foreach (grep { /^_\w+_$/ } $input->param) {
    $output->param(substr($_, 1, -1) => $input->param($_));
  }

  # Set recipeint
  $output->param(recipient => $vdoc->Mailto);

  # Set mailmsg
  $output->param(mailmsg => $vdoc->Mailmsg);

  return OBVIUS_OK;
}

1;
__END__

=head1 NAME

Obvius::DocType::UFOForm - Perl extension for ?

=cut
