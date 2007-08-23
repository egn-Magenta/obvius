package WebObvius::Cache::Flushing;
# $Id$

use Fcntl qw(:flock);
use BerkeleyDB;

require Exporter;
our @ISA = qw( Exporter );
our @EXPORT = qw( flush immediate_flush step );

our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

#delete cache_file
sub immediate_flush {
    my $cache_file = shift;

    open F ">$cache_file";
    close F;
}

sub flush_all {
    immediate_flush(@_);
}

sub flush {
    my ($cache_file, $url) = @_;
    my $content;
    my @url_regexes = map { qr/^$_\s/ } @$url;

    open F, "<$cache_file";
    
    while(my $line = <F>) {
	for (@url_regexes) {
	    $line = "" if ($line =~ /$_/);
	}
	$content .= $line;
    }
    close F;
    open F, ">$cache_file";
    
    print F $content;
    close F;
}

       
43;
