package Obvius::DocType::MultiChoice;

# $Id$

use strict;
use warnings;

use Obvius;
use Obvius::DocType;
use Digest::MD5 qw(md5_hex);


use Data::Dumper;

our @ISA = qw( Obvius::DocType );
our $VERSION="1.0";

sub action {
    my ($this, $input, $output, $doc, $vdoc, $obvius) = @_;

    $this->tracer($input, $output, $doc, $vdoc, $obvius) if ($this->{DEBUG});

    my $is_admin = $output->param('IS_ADMIN');

    $obvius->get_version_fields($vdoc, [ 'vote_option', 'bar_width' ]);

    my $mode = $input->param('mode') || 'form';

    my $voter_id;
    unless ($is_admin) {
        my $cookies = $input->param('Obvius_COOKIES');
        $voter_id = $cookies->{Obvius_VOTER_ID};
        unless ($voter_id) {
            $voter_id = md5_hex($input->param('THE_REQUEST') . $input->param('REMOTE_IP') . $input->param('Now'));

            #print STDERR "MC set cookie $voter_id\n";

            $output->param('Obvius_COOKIES' => { 'Obvius_VOTER_ID' => {
                                                    value => $voter_id,
                                                    expires => '+1y',
                                                }
                                            });
        }
    }

    #print STDERR "MC got cookie ", $voter_id || 'NULL', "\n";

    # Check if user already has voted
    if (($mode eq 'form' or $mode eq 'vote')
        and $voter_id and $obvius->voter_is_registered($voter_id, $doc->ID))
    {
            $mode='show';
    }

    my $answers;
    for(@{$vdoc->Vote_Option}) {
        /^\[(\w+)\](.*)$/;
        $answers->{$1} = $2;
    }

    #print STDERR "MC answers", Dumper($answers);

    if ($mode eq 'vote') {
        my $answer = $input->param('answer');

        if ($voter_id and $answer and defined $answers->{$answer}) {
            $obvius->register_voter($doc->ID, $voter_id);
            $obvius->register_vote($doc->ID, $answer);

            $output->param(vote_registered=>1); ## Think we can use this
        }
        my $redirect_to = $input->param('redirect_to');
        if($redirect_to) {
            $output->param('Obvius_REDIRECT' => $redirect_to);
            return OBVIUS_OK;
        } else {
            $mode = 'show';
        }
    }

    $output->param(mode => $mode);

    my $total = 0;
    my $max   = 0;
    my $votes = $obvius->get_votes($doc->ID);

    my $answer_table = [
						    map {
							({
							  id => $_,
							  answer => $answers->{$_},
							  count => $votes->{$_} || 0,
							 })
						    } sort keys %$answers
						   ];

    $total += $_->{count} for (@{$answer_table});
    $output->param(total => $total);
    map { $max = $_->{count} if $max < $_->{count} } @{$answer_table};
    $output->param(max => $max);

    my $bar_width=$vdoc->Bar_Width ? $vdoc->Bar_Width : 65; # Default

    for (@{$answer_table}) {
	if ($total > 0) {
	    $_->{pct} = int(100.0 * $_->{count} / $total + 0.5);
	    $_->{rel} = int($bar_width * ($_->{count} / $max)); # $total>0 => $max>0
	} else {
	    $_->{pct} = 0;
	    $_->{rel} = 0;
	}
	$_->{total} = $total;
    }

    $output->param(answers => $answer_table);

    return OBVIUS_OK;
}

1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Obvius::DocType::MultiChoice - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Obvius::DocType::MultiChoice;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Obvius::DocType::MultiChoice, created by h2xs. It looks like the
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
