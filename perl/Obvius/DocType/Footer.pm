package Obvius::DocType::Footer;

# Jason Armstrong <ja@riverdrums.com>
#  $Id$

use strict;
use warnings;

use Obvius;
use Obvius::DocType;

our @ISA = qw( Obvius::DocType );
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub action {
  my ($this, $input, $output, $doc, $vdoc, $obvius) = @_;

  my @fields = $obvius->get_version_fields($vdoc, 128);
  my (%h, %a);

  # We are looking for img/url combinations, and they should
  # be called: img1 and url1
  
  map {
        /(URL|IMG)(\d+)$/i;
        $h{$2}->{$1} = $a{$_} if ($1 and $2);
      } map {
        %a = %{$_};
        keys %a;
      } @fields;

  # Remove those that have no image ( ie eq '/')
  my @check;
  foreach (keys %h) {
    push @check, $_ if (not $h{$_}->{IMG} or $h{$_}->{IMG} eq '/');
  }
  delete $h{$_} foreach @check;

  $output->param('footer' => \%h);
  $output->param('footer_num' => scalar keys %h);

  # This field indicates how many images to show
  $output->param('footer_show' => (defined $vdoc->field('show')) ? 
                                           $vdoc->Show : 6);

  return OBVIUS_OK;
}

1;
__END__
