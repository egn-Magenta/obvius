package Obvius::DocType::MailData;

# $Id$

use strict;
use warnings;

use Obvius;
use Obvius::DocType;

our @ISA = qw( Obvius::DocType );
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

# Unhandled stuff:

    #$req->param(base => $docargs{base});           XXX What to do here?
    #my $id = $this->store_data_in_session($req);   XXX ----- !! -----

    # Template system takes over from here

    #$output->param(LINK=>
	#	     sprintf('http://%s%s/admin%s?op=%s;id=%s',
	#		     $req->get_server_name, ($req->get_server_port != 80
	#					     ? ':'.$req->get_server_port : ''),
	#		     $docargs{base}, $docargs{operation}, $id ));


sub action {
	my ($this, $input, $output, $doc, $vdoc, $obvius) = @_;

	$this->tracer($input, $output, $doc, $vdoc, $obvius) if ($this->{DEBUG});

    # Just do a view unless a form is submitted
    return OBVIUS_OK unless ($input->param('op') eq 'mail_data');

    $obvius->get_version_fields($vdoc, [ 'mailfrom', 'mailto', 'mailmsg' ]);

    return OBVIUS_ERROR unless ($vdoc->MailTo and $vdoc->MailMsg and $vdoc->MailFrom);

    map { $output->param("$_" => $input->param($_)) } $input->param;
    $output->param(sender => $vdoc->MailFrom);
    $output->param(recipient => $vdoc->MailTo);
    $output->param(mailmsg => $vdoc->MailMsg);

    $output->param(send_mail => 1); # Tell the template system to send the mail

    return OBVIUS_OK;
}


1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Obvius::DocType::MailData - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Obvius::DocType::MailData;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Obvius::DocType::MailData, created by h2xs. It looks like the
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
