package Obvius::DocType::OrderForm;

# $Id$

use strict;
use warnings;

use Obvius;
use Obvius::DocType;

our @ISA = qw( Obvius::DocType );
our $VERSION="1.0";

sub action {
	my ($this, $input, $output, $doc, $vdoc, $obvius) = @_;

	$this->tracer($input, $output, $doc, $vdoc, $obvius) if ($this->{DEBUG});

	#Get the requered vfields
	$obvius->get_version_fields($vdoc, [ 'mailto', 'mailmsg' ]);

	# Fail if the required fields are not filled
	return OBVIUS_ERROR unless ($vdoc->Mailto and $vdoc->Mailmsg);

	# Copy each incoming "_parameter_" to outgoing "parameter"
    foreach (grep { /^_\w+_$/ } $input->param) {
	$output->param(substr($_, 1, -1) => $input->param($_));
    }

	# Set recipeint
    $output->param(recipient => $vdoc->Mailto);

	# set mailmsg
    $output->param(mailmsg => $vdoc->Mailmsg);


	# Copy each order from incoming param "id" to loopvar "orders"
    my $orders = $input->param('id');
    $orders = [] unless $orders;
    $orders = [ $orders ] unless(ref($orders));
    $output->param(orders => [
				map { {order => $_} } @$orders
			       ]);

    return OBVIUS_OK;
}

1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Obvius::DocType::OrderForm - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Obvius::DocType::OrderForm;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Obvius::DocType::OrderForm, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head2 EXPORT

None by default.


=head1 AUTHOR

A. U. Thor, E<lt>a.u.thor@a.galaxy.far.far.awayE<gt>

=head1 SEE ALSO

L<perl>.

-------------------------------------------
Kontakt FI

<form action="." method=POST name=kontakt>
<input type=hidden name=op value=kontakt>

<P>Indhold<BR>
<textarea cols="30" name="_Kommentar_" rows="3"></textarea>

<P>Navn<BR>
<input CLASS=input name="_Navn_" size="25">

<P>Adresse (valgfri)<BR>
<input CLASS=input name="_Adresse_" size="25">

<P>Postnr. &amp; by (valgfri)<BR>
<input CLASS=input name="_By_" size="25">

<P>Email<BR>
<input CLASS=input name="_Email_" size="25">

<P><input type=submit value="  Send  ">
&nbsp; <input name="reset" type="reset" value="Slet">
</form>

------------------------------------------
Send til en ven

<form action="." method=POST name=send_til_ven>
<input type=hidden name=op value=send_til_ven>
<input type="hidden" name="url">

<P>Kommentar<BR>
<textarea cols="30" name="_Kommentar_" rows="10"></textarea>

<P>Dit navn<BR>
<input CLASS=input name="_NavnFra_" size="25">

<P>Din e-mail-adresse<BR>
<input CLASS=input name="_MailFra_" size="25">

<P>Send til e-mail-adresse<BR>
<input CLASS=input name="_MailTil_" size="25">

<P><input type=submit value="  Send  ">
&nbsp; <input name="reset" type="reset" value="Slet">
</form>





=cut
