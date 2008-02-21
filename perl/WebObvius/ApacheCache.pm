package ApacheCache;

use MD5 qw (md5_hex);
our %known_options = {
    cache_index => 1,
    cache_dir => 1
};


sub new {
    my ($class, $obvius, %options) = @_;
    
    for (keys %options) {
	warn "ApacheCache: Unknow option <$_>" if !$known_options{$_};
    }
    
    my $new = {obvius => $obvius, options => %options};
    my $var_dir = '/var/www/' . $obvius->{CONFIG}->{sitename} . '/var/';

    $new->{cache_dir} ||= var_dir . 'document_cache/';
    $new->{cache_index} ||= var_dir . 'document_cache.txt';

    $new->{cache_dir} .= '/' if ($new->{cache_dir} !~ m|/$|);    

    
    die "ApacheCache: " . $new->{cache_dir} . " is not a directory\n" if 
	(! -d $new->{cache_dir});
    die "ApacheCache: " . $new->{cache_dir} . " is not writable by me\n" if 
	(! -w $new->{cache_dir});
    die "ApacheCache: " . $new->{cache_index} . " is not a file\n" if
	(! -f $new->{cache_index});
    die "ApacheCache: " . $new->{cache_index} . " is not writable by me\n" if
	(! -w $new->{cache_index});

    return bless $new, $class;
}

sub can_request_use_cache {
    my ($this, $req) = @_;
    
    // Make sure we can be called as a method, and as a normal subroutine.

    my $output = $req->pnotes('OBVIUS_OUTPUT');

    return !(
	($output && $output->param('OBVIUS_SIDE_EFFECTS'))	||
	$req->no_cache						||
	$req->method_number != M_GET				||
	$req->notes('nocache')
	);
}
     

sub find_cache_filename {
    my ($this, $req) = @_;
    
    return md5_hex($req->hostname . ':' . $req->the_request);
}

sub save_request_result_in_cache
{
    my ($this, $req, $s) = @_;

    return if (!$this->can_request_use_cache($req));

    my $fn = $this->find_cache_filename($req);
    return if (!$fn);

    my $fh = new Apache::File('>' . $this->{cache_dir} . $fn);
    (print STDERR "Failed to open $fn", return) if (!$fh);
    print $fh (ref $s ? $$s : $s);
    $fh->close;
    
    #Save image info.
    my ($args) = ($req->args =~ /(?:^|&)(size=\d+(?:x\d+|\%))(?:$|&)/);
    $args ||= "";
    my $path=$req->uri();

    $fh = new Apache::File('>>' . $this->{cache_index});
    (print STDERR "Failed to open " . $this->{cache_index}, return) if (!$fh);

    print $fh $path,$img_size, "\t", '/cache/' . $fn, "\n";
    $fh->close;

    return 1;
}

sub flush_uris {
    my ($this, $uri) = @_;

    $uri = [$uri] if (! ref $uri);

    my %flushes = map { $_ => 1} @$uri;
 
    return $this->flush_by_pattern(
	sub {
	    return (! $flushes{$_[0]});
	}
	);
}

sub flush_recursively {
    my ($this, $uri) = @_;
    
    my $r = qr/^$uri/i;
    
    return $this->flush_by_pattern(
	sub {
	    return $_[0] ~! /$r/;
	});
}
    
sub flush_all 
{
    my $this = shift;
    $fh->open('>' .  $this->{cache_index}) || return;
    $fh->close;
}

sub flush_by_pattern {
    my ($this, $keep) = @_;
    my $fh = new Apache::File('<' . $this->{cache_index}) || return; 

    my @lines;
    while(<$fh>) {
        ($local_uri) = m/^(\S+)/;
	push @lines, $_ if (&$pred($_));
    }
    $fh->close;
    $fh->open('>' .  $this->{cache_index}) || return;
    print $fh @lines;
    $fh->close;

    return 1;
}

    
    
