package Obvius::Log::Readable;

use strict;
use warnings;

use Obvius::Log;
use Data::Dumper;

our $VERSION="1.0";
our $AUTOLOAD;

my %loglevels;

{
    my $i;
    $loglevels{$_} = $i++ for qw(debug info notice warn error crit alert emerg none);

    # Backward compatibility:
    $loglevels{0} = $loglevels{info};
    $loglevels{1} = $loglevels{debug};
}

# new - returns an Obvius::Log::Readable object
sub new {
    my ($class, $loglevel_str, $output_to_stderr) = @_;

    $loglevel_str = 'none' unless defined $loglevel_str;
    my $loglevel = exists($loglevels{$loglevel_str}) ? $loglevels{$loglevel_str} : $loglevels{none};

    my $this = {
        'logs'             => {},
        'output_to_stderr' => $output_to_stderr ? 1 : 0,
        'loglevel'         => $loglevel
    };
    bless $this, $class
}

sub read {
    my ($this, $level, $clear) = @_;
    my @messages;
    if ($level && $this->{logs}->{$level}) {
        @messages = @{$this->{logs}->{$level}};
    }
    if ($clear) {
        $this->clear($level);
    }
    return \@messages;
}

sub clear {
    my ($this, $level) = @_;
    if ($level eq 'all') {
        $this->{logs} = {};
    } elsif ($level && $this->{logs}->{$level}) {
        $this->{logs}->{$level} = [];
    }
}

# AUTOLOAD - this is the actual workhorse, doing the logging according to level
sub AUTOLOAD {
    my ($this, $value) = @_;
    return if $AUTOLOAD =~ /::DESTROY$/;

    my $name = $AUTOLOAD;
    $name =~ s/.*:://;

    if ($loglevels{$name} >= $this->{loglevel}) {
        if (!defined($this->{logs}->{$name})) {
            $this->{logs}->{$name} = [];
        }
        push(@{$this->{logs}->{$name}}, $value);
        if ($this->{output_to_stderr}) {
            print STDERR "[$name] $value\n";
        }
    }
}

1;
__END__

=head1 NAME

Obvius::Log::Readable - A wrapper for logging to a readable buffer

=head1 SYNOPSIS

  use Obvius::Log::Readable;

  my $log=Obvius::Log::Readable->new;

  my $messages=$log->read('warn');

  $log->clear('all');

=head1 DESCRIPTION

This module may be used as a logger in obvius to pick up log messages from
code that we don't want to tamper with. Log messages will be put in a buffer
(and optionally output to STDERR), and calls to read() can extract the
accumulated messages.

Use this module only when you need the log messages in the code (e.g. when running a script),
as the default logger usually is enough and doesn't accumulate messages over time.


=head1 AUTHOR

Lars Peter Thomsen<lt>larsp@magenta-aps.dk<gt>

=cut
