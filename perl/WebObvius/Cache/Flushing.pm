package WebObvius::Cache::Flushing;
# $Id$

use Fcntl qw(:flock);
use BerkeleyDB;

require Exporter;
our @ISA = qw( Exporter );
our @EXPORT = qw( flush immediate_flush step );

our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;


sub flush {
    my ($uri, $flushdb, $rewritedb) = @_;

    my @lines;
    my %flushes;

    $flushes{$uri} = 1 unless (ref $uri);
    map { $flushes{$_} = 1 } @$uri if (ref($uri) eq "ARRAY");

    open FH, '<', $rewritedb || return 0;
    flock FH, LOCK_EX || return 0;
    while(<FH>) {
        ($local_uri) = m/^(\S+)/;
	push @lines, $_ unless ($flushes{$local_uri});
    }
    open FH, '>', $rewritedb || return 0;
    print FH @lines;
    close FH;
    
    map { chomp; s/^\s*(\S*).*$/$1/ } @lines; # Extract uri's

    # BerkeleyDB has it own locking scheme so don't use any kind og flock'ing.
    
    my $env = new BerkeleyDB::Env -Flags => DB_INIT_LOCK;
    tie %flushdb,  "BerkeleyDB::Hash", -Filename => $flushdb,
                                       -Flags => DB_CREATE,
				       -Env => $env or return 0;
    $flushdb{$_} ||= time for (@lines);
    $flushdb{'step'} = 0;
    untie %flushdb;
    return 1;
}

sub immediate_flush {
    my ($flushdb, $rewritedb) = @_;

    open FH, '<', $rewritedb || return 0;
    flock FH, LOCK_EX || return 0;
    open FH, '>', $rewritedb || return 0;
    close FH;

    my $env = new BerkeleyDB::Env -Flags => DB_INIT_LOCK;
    my $db = new BerkeleyDB::Hash -Filename => $flushdb,
                                  -Flags => DB_TRUNCATE,
				  -Env => $env or return 0;
    $db->db_close;
    return 1;
}

sub step {
    my ($maxdelay, $flushdb, $rewritedb) = @_;
    
    # BerkeleyDB has it own locking scheme so don't use any kind og flock'ing.
    my $env = new BerkeleyDB::Env -Flags => DB_INIT_LOCK;
    tie %flushdb,  "BerkeleyDB::Hash", -Filename => $flushdb,
                                       -Env => $env or return 0;
    $step = $flushdb{'step'}++;
    for (keys %flushdb) {
	next if ($_ eq 'step');
        if ($flushdb{$_} < (time() - 60 * $maxdelay)) {
	    $flush{$_} = 1;
	} else {
	    push @rest, [$flushdb{$_}, $_];
	}
    }
    
    @rest = map { $_->[1] } sort { $a->[1] <=> $b->[1] } @rest;

    # ACHTUNG: I should come up we something more readable but nearly
    #          equivalent formulation of the following: 
    map { $flush{$_} = 1 } $maxdelay<=$step?@rest:@rest[0..(int $#rest/($maxdelay-$step))];

    delete $flushdb{$_} for (keys %flush);
    
    untie %flushdb;

    open FH, '+<', $rewritedb || return 0;
    flock FH, LOCK_EX || return 0;
    while($line = <FH>) {
        ($local_uri) = ($line =~ m/^(\S+)/);

    	push @lines, $line unless ($flush{$local_uri});
    }
    open FH, '>', $rewritedb || return 0;
    print FH @lines;
    flock FH, LOCK_UN;
    close FH;
    return 1;
}

#Takes the cache index file and an url array,
#and removes the urls in the url array, from the index file passed...

sub flush_multiple {
    my ($cache_file, $url) = @_;
    my $content;
    my @url_regexes = map { qr/^$_\s/i } @$url;
	    
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
									    
									    

42; 
__END__

=head1 NAME

WebObvius::Cache::Flushing - Perl module for flushing the cache in steps.
