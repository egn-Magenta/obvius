package Obvius::DocType::FiskeMedlemstilbud;

########################################################################
#
# FiskeMedlemstilbud.pm - FiskeMedlemstilbud Document Type
#
# Copyright (C) 2001-2003 aparte, Denmark (http://www.aparte.dk/)
#
# Author: Mads Kristensen,
#         Adam Sjøgren (asjo@aparte.dk)
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2, or (at your option)
# any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software Foundation,
# Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA. 
#
########################################################################

# $Id$

use strict;
use warnings;

use Obvius;
use Obvius::DocType;
use Net::SMTP;
use POSIX qw(strftime);

our @ISA = qw( Obvius::DocType );
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub action {
    my ($this, $input, $output, $doc, $vdoc, $obvius) = @_;

    my $mode = $input->param('mode') || '';
    if ($mode eq 'send') {
	$output->param('mode'=>$mode);
	my $mailto = $obvius->get_version_field($vdoc, 'mailto');
	return OBVIUS_OK unless $mailto;

	# make a new version of the document with the new ordrenr
	my $ordrenr = $obvius->get_version_field($vdoc, 'ordrenr');
	$ordrenr++;
	$output->param(ordrenr=>$ordrenr);
	$obvius->get_version_fields($vdoc, 255);
	my $docfields = $vdoc->fields;
	$docfields->{'ORDRENR'} = $ordrenr;

	my $backup_user = $obvius->{USER};
	$obvius->{USER} = 'admin';
	my $version = $obvius->create_new_version($doc, $vdoc->Type, $vdoc->Lang, $docfields);
	$obvius->{USER} = $backup_user;

	# Publish the version
	my $new_vdoc = $obvius->get_latest_version($doc);
	
	# Start out with som defaults
	$obvius->get_version_fields($new_vdoc, 255, 'PUBLISH_FIELDS');
	
	# Set published
	my $publish_fields = $new_vdoc->publish_fields;
	$publish_fields->param(PUBLISHED => strftime('%Y-%m-%d %H:%M:%S', localtime));
	
	$obvius->{USER} = 'admin';
	$obvius->publish_version($new_vdoc);
	$obvius->{USER} = $backup_user;
	
	my $kvitto=$this->send_order_mail($mailto, 'webmaster@sportsfiskeren.dk', $input, $obvius, $ordrenr);
        $output->param(kvitto=>$kvitto);
    }
    return OBVIUS_OK;
}

sub get_ordrenummer($vdoc) {


}


sub send_order_mail {
    my ($this, $to, $from, $input, $obvius, $ordrenr) = @_;

    my $orders = $input->param('ordre');
    $orders=[$orders] unless (ref($orders));

    my $order_docs = $input->param('docs');
    my @orders = split /,/, $order_docs;
    my @order_docs;

    for (@orders) {
	my $doc   = $obvius->get_doc_by_id($_);
	my $url   = $obvius->get_doc_uri($doc);
	my $vdoc  = $obvius->get_public_version($doc);
	next unless $vdoc;
	my $title = $obvius->get_version_field($vdoc, 'title');
	push (@order_docs, { title=>$title, url=>$url });
    }

    my $orderstring = "";
    my $i = 0;
    for (@$orders) {
	if ($_) {
	    $orderstring .= $order_docs[$i]->{title} . ":  $_ stk.\n";
	    $orderstring .= " <http://www.sportsfiskeren.dk" . $order_docs[$i]->{url} . ">\n\n";
	}
	$i++;
    }

    my %info;
    map { $info{$_}=$input->param($_) || "Ikke angivet" }
        qw(medlemsnr navn email adresse kommentarer betaling);

    my $adresse_indent=$info{adresse};
    $adresse_indent=~s/\n/\n               /g;

    my $kommentarer_indent=$info{kommentarer};
    $kommentarer_indent=~s/\n/\n               /g;

    my $kvitto=<<EOT;
Følgende er blevet bestilt på www.sportsfiskeren.dk:

$orderstring
----------------------

  Ordrenummer: $ordrenr

Medlemsnummer: $info{medlemsnr}
         Navn: $info{navn}
        email: $info{email}
      Adresse: $adresse_indent
Betalingsform: $info{betaling}

  Kommentarer: $kommentarer_indent


EOT

    my $message =<<EOF;
To: $to
From: www.sportfiskeren.dk <$from>
Subject: Medlemstilbud, ordrenr: $ordrenr ($info{navn})
MIME-Version: 1.0
Content-Type: text/plain; charset=iso-8859-1
Content-Transfer-Encoding: 8bit
Content-Disposition: inline
Precedence: bulk

$kvitto
Med venlig hilsen
www.sportsfiskeren.dk

----------------------

$ordrenr
$info{navn} ($info{medlemsnr})
$info{adresse}

EOF

    my $smtp = Net::SMTP->new('localhost', Timeout=>30, Debug => 1);
    $kvitto=$kvitto . "Kunne ikke angive afsender [$from]<br>"  unless ($smtp->mail($from));
    $kvitto=$kvitto . "Kunne ikke angive modtager [$to]<br>"    unless ($smtp->to($to));
    $kvitto=$kvitto . "Kunne ikke sende beskeden<br>"           unless ($smtp->data($message));
    $kvitto=$kvitto . "Kunne ikke afslutte email-afsending<br>" unless ($smtp->quit);

    return $kvitto;
}

1;
__END__

=head1 NAME

Obvius::DocType::FiskeMedlemstilbud - Order items

=head1 SYNOPSIS

  (use'd by Obvius by itself)

=head1 DESCRIPTION

FiskeMedlemstilbud shows a list of items (subdocuments) and allows the
user to order a number of these - by entering how many and filling out
fields saying where to ship and payment method.

Each order is given a number, and an email is sent to the specified
email-address with the order.

=head1 TODO

 * Ordernumbers aren't handed out atomically
 * A confirmation should be sent to the person making the order

=head1 AUTHOR

 Mads Kristensen,
 Adam Sjøgren <asjo@aparte.dk>

=head1 SEE ALSO

L<Obvius>.

=cut
