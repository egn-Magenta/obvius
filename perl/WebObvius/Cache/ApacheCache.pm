package WebObvius::Cache::ApacheCache;

use strict;
use warnings;

use Fcntl ':flock';
use Digest::MD5 qw (md5_hex);

use Data::Dumper;
use Obvius::Hostmap;

use Exporter;

our @ISA = qw(Exporter);

our @EXPORT_OK = qw(is_relevant_for_leftmenu_cache);

our %known_options = (
    cache_index => 1,
    cache_dir => 1
);


sub new {
    my ($class, $obvius, %options) = @_;

    for (keys %options) {
	warn "ApacheCache: Unknow option <$_>" if (!$known_options{$_});
    }

    my $new = {obvius => $obvius, %options};

    my $var_dir = '/var/www/' . $obvius->{OBVIUS_CONFIG}{SITENAME} . '/var/';
    $new->{cache_dir} ||= $obvius->{OBVIUS_CONFIG}{CACHE_DIRECTORY} || ($var_dir . 'document_cache/');
    $new->{cache_index} ||= $obvius->{OBVIUS_CONFIG}{CACHE_INDEX}   || ($var_dir . 'document_cache.txt');
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
    
    my $args = $req->args;
    my $args_ok = (!$args || $args =~ /^\s*$/ || $args =~ /^size=\d+(?:x\d+|%)$/);

    return !((
             $output && $output->param('OBVIUS_SIDE_EFFECTS'))	||
	     $req->no_cache					||
	     $req->method_number != 0				|| # 0 er M_GET, mod_perl bug.
	     $req->notes('nocache')                             ||
	     !$args_ok
	    );
}


sub find_cache_filename {
    my ($this, $req) = @_;

    my $ct = $req->content_type;
    $ct =~ s|^([a-zA-Z0-9.-]+/[a-zA-Z0-9.-]+).*|$1|;
    my $lang_array = $req->content_languages();
    my $lang = scalar @$lang_array ? $lang_array->[0] : 'da';
    my $code = md5_hex($req->hostname . ':' . $req->the_request);

    return ((join '/', ($ct, $lang)) . '/', $code);
}

sub make_sure_exist {
     my $path = shift;
     my @path = split '/', $path;
     
     shift @path;
     my $p = '/';
     while (scalar @path ) {
	  $p .= (shift @path) . '/';
	  if (! -d $p) {
	       mkdir $p, 0775 || return 1;
	       chmod 0775, $p;
	  }
     }

     return 0;
}

sub save_request_result_in_cache
{
     my ($this, $req, $s) = @_;
     
     return if (!$this->can_request_use_cache_p($req));
     
     my ($fp, $fn) = $this->find_cache_filename($req);
     my $local_dir = $fp . $fn;
     return if (!$fn);
     
     my $dir = $this->{cache_dir} . $fp;
     make_sure_exist($dir);
     
     open F, '>', $dir . $fn || (warn "Couldn't write cache\n", return);
     flock F, LOCK_EX || (warn  "Couldn't get lock\n", goto close);
     print F (ref $s ? $$s : $s);
     flock F, LOCK_UN;
     close F;

     #Save image info.
     my ($args) = ($req->args =~ /(?:^|&)(size=\d+(?:x\d+|\%))(?:$|&)/) if ($req->args);
     $args ||= "";
     
     my $path=$req->uri();
     
     open F, ">>", $this->{cache_index} || (warn "Failed to open " . $this->{cache_index}, return);
     flock F, LOCK_EX || (warn "couldn't get lock", goto close);
     print F $path, $args, "\t", '/cache/' . $local_dir, "\n";
     flock F, LOCK_UN;
     
   close:
     close F;
     
     return;
}

sub flush {
    my ($this, $commands) = @_;

    $commands = [$commands] if (ref($commands) ne 'ARRAY');
    
    my %flush_simple = map { lc $_->{uri} => 1} 
        grep {$_->{command} eq 'clear_uri' } @$commands;
    my @flush_regexps = map { qr/$_->{regexp}/i } 
	grep {$_->{command} eq 'clear_by_regexp'} @$commands;
    my @flush_not_regexps = map { qr/$_->{regexp}/i } 
	grep {$_->{command} eq 'clear_by_not_regexp'} @$commands;
    
    return $this->flush_by_pattern(
            sub {
		 my $uri = shift;
		 $uri =~ s|/size=.*$||;
		 $flush_simple{lc $uri} and return 1;
		 $uri =~ /$_/ and return 1 for (@flush_regexps);
		 $uri !~ /$_/ and return 1 for (@flush_not_regexps);
		 
		 return 0;
	    });
}

sub flush_by_pattern {
    my ($this, $pred) = @_;

    open F, '+<', $this->{cache_index} || return;
    flock F, LOCK_EX || goto close;
    my @lines;
    while(my $line = <F>) {
        my ($local_uri) = ($line =~ m/^(\S+)/);
	push @lines, $line if ($local_uri && !(&$pred($local_uri)));
    }
    seek F, 0, 0;
    truncate F, 0;
    print F $_ for (@lines);
    
    flock F, LOCK_UN;
  close:
    close F;
    
    return;
}

sub execute_query {
     my ($this, $sql, @args) = @_;

     my $obvius = $this->{obvius};
     $obvius->connect if (!$obvius->{DB});
     my $sth = $obvius->{DB}->DBHdl->prepare($sql);
     
     $sth->execute(@args);
     my @res;

     while (my $row = $sth->fetchrow_hashref) {
	  push @res, $row;
     }
     
     $sth->finish;
     return \@res;
}

sub check_vfields_for_docids {
     my ($this, $docids) = @_;
     
     my @docids = grep { /^\d+$/ } @$docids;
     return if (!scalar @docids);
     my @regexp_query = map { "vf.text_value REGEXP '(^|[^0-9])$_\\\.docid'" } @docids;
     
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
     my ($this, $docids) = @_;
     
     my $obvius = $this->{obvius};
     $docids = $this->check_vfields_for_docids($docids);
     
     my @uris;

     for my $docid (@$docids) {
	  my $doc = $obvius->get_doc_by_id($docid);
	  push @uris, $obvius->get_doc_uri($doc) if ($doc);
     }
     my @res = map { {command => 'clear_uri', uri => $_} } @uris;
     
     return \@res;
}
     
sub is_relevant_for_leftmenu_cache {
     my ($this, $docid, $vdoc) = @_; 
     my @relevant_fields = qw(title short_title seq);

     my $obvius = ref $this eq 'Obvius' ? $this : $this->{obvius};
     
     my $doc = $obvius->get_doc_by_id($docid);
     return 0 if (!$doc);

     my $old_vdoc = $obvius->get_public_version($doc);
     return 1 if (!$old_vdoc);
     
     $obvius->get_version_fields($old_vdoc, \@relevant_fields);
     $obvius->get_version_fields($vdoc, \@relevant_fields);

     for (@relevant_fields) {
	  return 1 if ($vdoc->field($_) ne $old_vdoc->field($_));
     }
     
     return 0;
}


sub perform_command_clear_doctype {
     my ($this, $doctype_name) = @_;
     my $obvius = $this->{obvius};
     
     my $doctype = $obvius->get_doctype_by_name($doctype_name);

     my $query = <<END;
SELECT DISTINCT(docid) FROM 
    documents d INNER JOIN versions v ON (v.docid = d.id)
WHERE

    v.public = 1 AND (d.type = ? OR v.type = ?);
END
     my $docids = $this->execute_query($query, $doctype->Id, $doctype->Id);
     
     my @commands;
     
     for (@$docids) {
	  my $doc = $obvius->get_doc_by_id($_->{docid});
	  my $path = $obvius->get_doc_uri($doc) if ($doc); 
	  push @commands, {command => 'clear_uri', uri => $path} if($path);
     }
     
     return \@commands;
}
	 
sub special_actions {
     my ($this, $docids) = @_;
     my $obvius = $this->{obvius};

     my @commands;
     my %special_op_per_doctype = ( 
				   Nyhed => {command => 'clear_doctype',  args => ['Nyhedsliste'] },
				   CalendarEvent => {command => 'clear_doctype', args => ['Arrangementsliste']}
				  );
     
     for (@$docids) {
     
	  my $doc = $obvius->get_doc_by_id($_);
	  next if (!$doc);
	  my $doctype = $obvius->get_doctype_by_id($doc->Type);
	  next if (!$doctype);
	  
	  if (my $cmd = $special_op_per_doctype{$doctype->{NAME}}) {
	       my $func = "perform_command_" . $cmd->{command};
	       my $cmds = $this->$func(@{$cmd->{args}});
	       push @commands, @$cmds;
	  }
     }

     return \@commands;
}

sub find_dirty {
     my ($this, $cache_objects) = @_;

     my $vals = $cache_objects->request_values('uri', 'docid', 'clear_leftmenu', 'clear_recursively');
     my @uris		= grep { $_ } map { $_->{uri}   } @$vals;
     my @docids		= grep { $_ } map { $_->{docid} } @$vals;
     my @leftmenu_uris	= map { $_->{uri} } grep {  $_->{uri} and $_->{clear_leftmenu}} @$vals;
     my @clear_recursively = map {{command => 'clear_by_regexp', regexp => "^" . $_->{uri}}}
       grep { $_->{uri} and $_->{clear_recursively}} @$vals;
     
     my @uris_to_clear = map { { command => 'clear_uri', uri => $_}} @uris;

     my $referrers = $this->find_referrers(\@docids);
     my @related = map { $this->find_related($_) } @leftmenu_uris;
     my $special_actions = $this->special_actions(\@docids);
     
     my @commands = grep { $_ } 
       (@clear_recursively,
	@$referrers, 
	@related, 
	@$special_actions,
	@uris_to_clear
       );
     
     print STDERR Dumper(\@commands);
     return uniquify_commands(\@commands);
}

sub uniquify_commands {
     my $commands = shift;
     
     my @result;
     
     OUTER: for my $cmd1 (@$commands) {
	  for my $cmd2 (@result) {
	       next OUTER if (commands_equal_p($cmd1, $cmd2));
	  }
	  push @result, $cmd1;
     }

     return \@result;
}

sub commands_equal_p {
     my ($cmd1, $cmd2) = @_;
     
     for (keys %$cmd1, keys %$cmd2) {
	  return 0 if ($cmd1->{$_} and $cmd2->{$_} and $cmd1->{$_} ne $cmd2->{$_});
     }

     return 1;
}

sub quick_flush {
    my ($this, $cache_objects) = @_;;
    
    my $uris = $cache_objects->request_values('uri', 'quick');
    my %uris = map { $_->{uri} => 1} grep { $_->{uri} and $_->{quick} } @$uris;
    
    $this->flush_by_pattern(sub {return 1 if $uris{shift}; return 0; }) if(scalar keys %uris);
}

sub find_and_flush {
     my ($this, $cache_objs) = @_;
     
     my $commands = $this->find_dirty($cache_objs);
     
     @$commands = grep {$_} @$commands;

     $this->flush($commands) if scalar(@$commands);
}

sub find_related {
     my ($this, $uri) = @_;
     
     my $obvius = $this->{obvius};

     my $hostmap = Obvius::Hostmap->new_with_obvius($obvius);

     my $host_prefix = $hostmap->find_host_prefix($uri);

     if ($host_prefix) {
	  return { command => 'clear_by_regexp', regexp => "^$host_prefix" } 
     } else {
	  return { command => 'clear_by_not_regexp', regexp => $hostmap->{regexp} };
     }
}

1;
