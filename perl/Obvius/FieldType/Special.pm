# $Id$

package Obvius::FieldType::Special;

use 5.006;
use strict;
use warnings;

use Obvius::FieldType;
use Date::Calc qw(check_date);
use LWP::UserAgent;
use HTTP::Request::Common;

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

    if ($this->{VALIDATE_ARGS} eq 'CorrectDate') {
        return $value;
    }

    if ($this->{VALIDATE_ARGS} eq 'ValidXhtml') {
        return $value;
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
                return "/" . $doc->Id . ".docid";
            } else {
                return $value;
            }
        }
    }

    if ($this->{VALIDATE_ARGS} eq 'CorrectDate') {
        return undef unless($value);
        my ($year, $month, $day) = ($value =~ /(\d\d\d\d)-(\d\d)-(\d\d)/);
        if(check_date($year, $month, $day)) {
            return $value;
        } else {
            return undef;
        }
    }

    return $value;
}

sub validate {
    my ($this, $obvius, $fspec, $value, $input) = @_;

    if ($this->{VALIDATE_ARGS} eq 'ValidXhtml') {
        return $this->check_xhtml($value, $obvius, $fspec);
    }

    return undef unless (defined $value);
    $value = $this->copy_out($obvius, $fspec, $value);
    return undef unless (defined $value);
    return $this->copy_in($obvius, $fspec, $value);
}

# check_xhtml($value, $obvius, $fspec)
#   - takes a value and runs it through the w3c html validator. Returns undef
#     if the value is not valid xhtml, otherwise returns the value. The url for
#     the w3c validator needs to be specified in the sites' configuration file.
sub check_xhtml {
    my ($this, $value, $obvius, $fspec) = @_;

    return $value if(not $value or $value =~ m!^\s+$!s);

    my $w3c_check_url = $obvius->config->param('w3c_check_url');

    unless($w3c_check_url) {
        print STDERR "No w3c_check_url specified in config file - can't validate xhtml\n";
        return undef;
    }

    my $tmpfile = "/tmp/obvius-htmlcheck-" . $fspec->param('name') . "-" . time . ".html";

    my $charset = $obvius->config->param('html_charset') || 'iso-8859-1';

    if(open(FH, "> $tmpfile")) {
        print FH '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">' . "\n";
        print FH '<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">' . "\n";
        print FH '<head>' . "\n";
        print FH '<title>Obvius test of Xhtml</title>' . "\n";
        print FH '<meta http-equiv="content-Type" content="text/html; charset=' . $charset . '" />' . "\n";
        print FH '</head>' . "\n";
        print FH '<body>' . "\n";
        print FH '<div>' . "\n";
        print FH "$value\n";
        print FH '</div>' . "\n";
        print FH '</body>' . "\n";
        print FH '</html>' . "\n";
        close(FH);


        # Post file to the validator:
        my $ua  = LWP::UserAgent->new();
        my $req = POST($w3c_check_url,
                        Content_Type => "form-data",
                        Content      => [
                                            uploaded_file =>  [ "$tmpfile" ]
                                        ]);
        my $response = $ua->request($req);

        unlink($tmpfile);

        if ($response->is_success()) {
            my $output = $response->content;

            if($output =~ m!This Page Is Valid!) {
                return $value;
            } else {
                return undef;
            }
        } else {
            print STDERR "Error from validator: " .  $response->as_string;
            return undef;
        }
    } else {
        print STDERR "Couldn't open temporary file while checking XHTML\n";
        return undef;
    }

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
