package Obvius::Translations::ExtractPlugins::Mason;

use strict;
use warnings;
use utf8;

use base qw(Locale::Maketext::Extract::Plugin::Base);
use HTML::Mason::Compiler::ToObject;
use Obvius::CharsetTools;
use Obvius::Translations::Extract;

my $msg_match =
    qr{\$m->comp\((\s*)['"]?/shared/msg['"](\s*),(\s*)text(\s*)=>(\s*)};

sub known_file_type {
    my $self = shift;

    my $result = $self->SUPER::known_file_type(@_);
    $self->{_current_file} = $_[0] if($result);
    return $result;
}

sub extract {
    my $self = shift;
    my $input = shift;
    my $org = $input;
    $input = Obvius::CharsetTools::mixed2utf8($input);

    my $line = 1;
    # TODO: Maybe handle /shared/trans as well?
    while($input =~ m{\G(.*?<&\s*/shared/(msg)\s*,(.*?)&>)}gs) {
        my ($method, $inner) = ($2, $3);
        $line += ( () = ($1 =~ /\n/g) );

        # We want the raw strings so don't do utf8-conversion
        no utf8;

        my $hash = eval(qq|
            local \$_ = "####FATALUNDERSCORE####";
            my \$_h = { $inner };
            if(grep { /####FATALUNDERSCORE####/ } \%\$_h) {
                die "Wrong use of variable"
            }
            \$_h;
        |);
        if($@) {
            if($Obvius::Translations::Extract::DEBUG) {
                my $file = $self->{_current_file} || '<not defined>';
                $inner =~ s{(^\s+|\s+$)}{}gs;
                print STDERR "  At $file line $line:\n" .
                    "    Failed to parse args: {" .
                    join("\n      ", "", split(/\n[\t ]+/, $inner)) .
                    "\n    }\n";
            }
            next;
        }

        if($method eq 'msg') {
            if(my $text = $hash->{text}) {
                $self->add_entry($text, $line);
            }
        }
        #elsif($method eq 'trans') {
        #    if(my $text = ($hash->{en} || $hash->{da})) {
        #        $self->add_entry($text, $line);
        #    }
        #}
    }
}

1;