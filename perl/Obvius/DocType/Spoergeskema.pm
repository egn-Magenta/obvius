package Obvius::DocType::Spoergeskema;

# $Id$

use strict;
use warnings;

use Obvius;
use Obvius::DocType;

use POSIX qw(strftime);

our @ISA = qw( Obvius::DocType );
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub action {
    my ($this, $input, $output, $doc, $vdoc, $obvius) = @_;

    my $fields = $obvius->get_version_field($vdoc, 'questionfields') || [];

    my @fields = sort @$fields;

    my @fielddata;

    for my $f (@fields) {
        my ($nr, $type, $heading, $description, $data) = split(/¤/, $f);

        if($type eq 'radio') {
            $data ||= '';
            my @options;
            my @data = split(/\n+/, $data);
            for(@data) {
                my ($key, $value) = /^\[([^\]]+)\]\s+(.*)$/;
                push(@options, { key => $key, value => $value }) if($key and $value);
            }
            $data = \@options;
        }

        push(@fielddata, {
                            name => 'spgskema_field_' . $nr,
                            type => $type,
                            heading => $heading,
                            description => $description,
                            data => $data,
                            nr => $nr
                        });
    }

    @fielddata = sort { $a->{nr} <=> $b->{nr} } @fielddata;

    $output->param('fielddata' => \@fielddata);


    if($input->param('go')) {
        my @answer_data;
        for my $f (@fielddata) {
            my $answer = $input->param($f->{name}) || '';
            push(@answer_data, { 'name' => $f->{heading}, 'answer' => $answer });

            #try to get email and name
            if($f->{heading} =~ /^\s*(navn|name)\s*$/i) {
                $output->param('sender_name' => $answer);
                print STDERR "Name: $answer\n";
            }
            if($f->{heading} =~ /^\s*(email|emailadresse)\s*$/i) {
                $output->param('sender_email' => $answer) if($answer =~ /^.+\@.+\..+/);
                print STDERR "Email: $answer\n";
            }
        }

        my $new_file = 0;

        # XXX hardcoded for now
        my $filename = '/home/httpd/www.biotik.dk/docs/spgskema/' . $vdoc->DocId . '.txt';

        $new_file = 1 unless(-f $filename);

        if($new_file) {
            open(FH, '>>' . $filename) or die "$!";
            print FH '# ' . join(', ', map{ $_->{name} } @answer_data) . "\n";
            close(FH);
        }

        open(FH, '>>' . $filename) or die "$!";
        print FH "'" . join("', '", map{ $_->{answer} } @answer_data) . "'\n";
        close(FH);

        $output->param(answer_data => \@answer_data);

    }

    return OBVIUS_OK;

}

1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Obvius::DocType::Spoergeskema - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Obvius::DocType::Spoergeskema;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Obvius::DocType::Spoergeskema, created by h2xs. It looks like the
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
