package WebObvius::Timer;

use strict;
use warnings;
use Apache::Constants qw(:common);
use Time::HiRes qw(gettimeofday tv_interval);

require Exporter;
our @ISA = qw( Exporter );
our @EXPORT_OK = qw( handler );

our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub StartTimer {
    my $r = shift;
    $r->pnotes(entrytime => [gettimeofday()]); 
    return OK;
}

sub LogTimer {
    my $r = shift;
    my $logfile = $r->dir_config('TimerLog') || return OK;
    my $request = $r->the_request;
    my $remote = $r->get_remote_host;
    my $date = localtime;
    my $status = $r->status;
    my $bytes = $r->bytes_sent;
    my $timer = tv_interval($r->pnotes('entrytime'));
    open FH, ">>$logfile" || return OK;
    print FH join " ", $remote, qq([$date]), qq("$request"), $status, $bytes, $timer, "\n";
    close FH;
    return OK;
}

1;
__END__

=head1 NAME

WebObvius::Timer - Perl module for logging status, bytes and time of each request.
