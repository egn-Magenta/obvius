package ApacheCache;

use Fcntl ':flock';
use MD5 qw (md5_hex);

use Obvius::Hostmap;

use Exporter;

our @ISA = qw(Exporter);

@EXPORT_OK = qw(is_relevant_for_related_cache);

our %known_options = {
    cache_index => 1,
    cache_dir => 1
};


sub new {
    my ($class, $obvius, %options) = @_;

    for (keys %options) {
	warn "ApacheCache: Unknow option <$_>" if (!$known_options{$_});
    }

    my $new = {obvius => $obvius, options => %options};

    my $var_dir = '/var/www/' . $obvius->{CONFIG}->{sitename} . '/var/';
    $new->{cache_dir} ||= $obvius->{CONFIG}->{CACHE_DIRECTORY} || (var_dir . 'document_cache/');
    $new->{cache_index} ||= $obvius->{CONFIG}->{CACHE_INDEX}   || (var_dir . 'document_cache.txt');
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

sub can_request_use_cache_p {
    my ($this, $req) = @_;

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

    return if (!$this->can_request_use_cache_p($req));

    my $fn = $this->find_cache_filename($req);
    return if (!$fn);

    open F, '>', $this->{cache_dir} . $fn || (warn "Couldn't write cache\n", return);
    flock F, LOCK_EX || (warn  "Couldn't get lock\n", goto close);
    print F (ref $s ? $$s : $s);
    flock F, LOCK_UN;
    close F;

    #Save image info.
    my ($args) = ($req->args =~ /(?:^|&)(size=\d+(?:x\d+|\%))(?:$|&)/);
    $args ||= "";

    my $path=$req->uri();

    open F, ">>", $this->{cache_index} || (warn "Failed to open " . $this->{cache_index}, return);
    flock F, LOCK_EX || (warn "couldn't get lock", goto close);
    print $fh $path,$args, "\t", '/cache/' . $fn, "\n";
    flock F, LOCK_UN;

  close:
    close F;
    
    return;
}

sub flush {
    my ($this, $commands) = @_;

    $commands = [$commands] if (ref($commands) ne 'ARRAY');

    my %flush_simple = map { $_->{url} => 1} 
        grep {$_->{command} eq 'clear_url' } @$commands;
    my @flush_regexps = map { qr/$_->{regexp}/ } 
	grep {$_->{command} eq 'clear_by_regexp'} @$commands;
    my @flush_not_regexps = map { qr/$_->{regexp}/ } 
	grep {$_->{command} eq 'clear_by_note_regexp'} @$uri;
      
    
    return $this->flush_by_pattern(
            sub {
		 $flushes{$_[0]} and return 1;
		 $_[0] =~ /$_/ and return 1 for (@flush_regexps);
		 $_[0] !~ /$_/ and return 1 for (@flush_not_regexps);

		 return 0;
	    });
}

sub flush_by_pattern {
    my ($this, $keep) = @_;

    open F, '<+', $this->{cache_index} || return;
    flock F, LOCK_EX || goto close;
    my @lines;
    while(<F>) {
        ($local_uri) = m/^(\S+)/;
	push @lines, $_ if (! &$pred($_));
    }
    truncate F, 0
    print F @lines;
    
    flock F, LOCK_UN
  close:
    close F;
    
    return;
}

sub execute_query {
     my ($this, $sql, @args) = @_;

     my $sth = $this->{obvius}->{DB}->DBHdl->prepare($sql);
     $sth->execute(@args);
     my @res;

     while (my $row = $sth->fetchrow_hashref) {
	  push @res, $row;
     }
     
     return \@res;
}

sub check_vfields_for_docids {
     my ($this, @docids) = @_;
     
     @docids = grep { /^\d+$/ } @docids;
     return if (!scalar @docids);
     my @regexp_query = map { "vf.text_value REGEXP '(^|[^0-9])$_.docid'" } @docids;
     
     my $append = "( " . (join " OR ", @regexp_query) . ")";
     my $sql = <<END;
SELECT DISTINCT(vf.docid) FROM
       versions v INNER JOIN vfields vf ON 
       (v.docid = vf.docid AND v.version = vf.version)
WHERE
       v.public = 1 AND $append
END
     my @res = map { $_->{docid}} @{$this->execute_query($sql)};
     
     return \@res;
}

			      
sub find_referrers {
     my ($this, $docs) = @_;
     
     my @docids = map {$_->{docid}} grep { $_->{docid} } @$docs;
     
     my $docids = $this->check_vfields_for_docids(@docids);
     
     my @urls;

     for my $docid (@$docids) {
	  my $doc = $obvius->get_doc_by_id($docid);
	  push @urls, $obvius->get_doc_uri($doc) if ($doc);
     }
     my @res = map { {command => 'clear_url', url => $_} } @urls;
     
     return \@res;
}
     
sub is_relevant_for_related_cache {
     my ($this, $docid, $vdoc) = @_; 
     my @relevant_fields = qw(title short_title seq);

     my $obvius = ref $this eq 'Obvius' ? $this : $this->{obvius};

     my $doc = $obvius->get_doc_by_id($docid);
     my $old_vdoc = $obvius->get_public_version($doc);
     $obvius->get_version_fields($old_vdoc, \@relevant_fields);
     $obvius->get_version_fields($vdoc, \@relevant_fields);

     for (@relevant_fields) {
	  return 1 if ($vdoc->field($_) ne $old_vdoc->field($_));
     }
     
     return 0;
}

sub find_dirty {
     my ($this, $uris} = @_;
     
     my $referrers = $this->find_referrers($uris);
     
     my $related = $this->find_related($uris);
     
     my @commands = (@referrers, @$related);
     return \@commands;
}


sub find_and_flush {
     my ($this, $uris) = @_;
     
     my $commands = $this->find_dirty($uris);
     
     $this->flush($commands);
}

#Clear the whole site's cache.
#Unless we are at the root.
sub find_related {
     my ($this, $uris) = @_;
     
     my $obvius = $this->{obvius};

     my $hostmap = Obvius::Hostmap->new_with_obvius($obvius);

     my $host_prefix = $hostmap->find_host_prefix($uris);
     
     return $host_prefix ? { command => 'clear_by_regexp', regexp => "^$host_prefix" } : 
                           { command => 'clear_by_not_regexp', regexp => $hostmap->{regexp} };
}

1;
