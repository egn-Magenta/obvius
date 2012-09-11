package WebObvius::Cache::MysqlApacheCache;

use strict;
use warnings;

use Fcntl qw ( LOCK_EX LOCK_UN O_RDWR O_CREAT );
use WebObvius::Cache::ApacheCache;
use WebObvius::Cache::MysqlApacheCache::QueryStringMapper;

use Data::Dumper;
use Obvius::Hostmap;

use Exporter;

our @ISA = qw(WebObvius::Cache::ApacheCache Exporter);

our @EXPORT_OK = qw(is_relevant_for_leftmenu_cache is_relevant_for_tags 
                    is_relevant_for_tags_on_unpublish);

sub new {
    my ($class, $obvius, %options) = @_;

    my $new = {obvius => $obvius, %options};
    
    my $config = $obvius->config;

    $new->{local_table} = $config->param('mysql_apachecache_table');
    die "No cache table for mysql-based cache specified" unless($new->{local_table});

    $new->{other_tables} = [grep {$_} split(/\s*,\s*/, $config->param('mysql_apachecache_other_tables') || '')];

    my $var_dir = '/var/www/' . $obvius->{OBVIUS_CONFIG}{SITENAME} . '/var/';
    $new->{cache_dir} ||= $obvius->{OBVIUS_CONFIG}{CACHE_DIRECTORY} || ($var_dir . 'document_cache/');
    die "ApacheCache: " . $new->{cache_dir} . " is not a directory\n" if 
	(! -d $new->{cache_dir});
    $new->{cache_dir} .= "/" unless($new->{cache_dir} =~ m!/$!);
        
    $new->{qstring_mapper} = $config->param('mysqlcache_querystring_mapper')
        || new WebObvius::Cache::MysqlApacheCache::QueryStringMapper();

    return bless $new, $class;
}

sub insert_or_update {
    my ($this, $uri, $querystring, $cache_path) = @_;
    
    my $table = $this->{local_table};
    my $sth = $this->{obvius}->dbh->prepare(qq|
        INSERT INTO ${table}
            (uri, querystring, cache_uri)
        VALUES
            (?, ?, ?)
        ON DUPLICATE KEY UPDATE
            cache_uri = VALUES(cache_uri)
    |);
    $sth->execute($uri, $querystring, $cache_path);
}

sub can_request_use_cache_p {
    my ($this, $req) = @_;

    my $output = $req->pnotes('OBVIUS_OUTPUT');
    
    my $result = !(
        ($output && $output->param('OBVIUS_SIDE_EFFECTS'))  ||
        $req->no_cache                                      ||
        $req->method_number != 0                            || # 0 er M_GET, mod_perl bug.
        $req->notes('nocache')                              ||
        $req->uri =~ m|^/preview/|
    );

    my $new_qstring;
    if($result) {
	$req->uri($req->uri() . "/") unless($req->uri() =~ m!/$!);
        my ($doctypeid, $doctypename) = $this->get_doctype_id_and_name($req->uri);
        if($doctypeid) {
            my $args = $req->args || '';
            ($result, $new_qstring) = $this->{qstring_mapper}->map_querystring_for_cache($doctypeid, $doctypename, $args);
        } else {
            $result = 0;
        }
    }
    
    if(wantarray) {
        return ($result, $new_qstring);
    } else {
        return $result;
    }
}


sub get_doctype_id_and_name {
    my ($this, $uri) = @_;

    my $dtype = $this->{obvius}->dbh->prepare(qq|
        SELECT
            doctypes.id AS doctypeid,
            doctypes.name AS doctypename
        FROM
            docid_path,
            versions,
            doctypes
        WHERE
            docid_path.docid = versions.docid
            AND
            versions.public = 1
            AND
            versions.type=doctypes.id
            AND
            docid_path.path = ?;
    |);
    $dtype->execute($uri);

    return ($dtype->fetchrow_array);
}

sub save_request_result_in_cache
{
    my ($this, $req, $s, $filename) = @_;
    
    my ($can_cache, $qstring) = $this->can_request_use_cache_p($req);
    return if !$can_cache;

    my ($fp, $fn) = $this->find_cache_filename($req, $filename);
    my $local_dir = $fp . $fn;
    return if (!$fn);

    my $dir = $this->{cache_dir} . $fp;
    WebObvius::Cache::ApacheCache::make_sure_exist($dir) or return;

    open F, '>', $dir . $fn || (warn "Couldn't write cache\n", return);
    flock F, LOCK_EX || (warn  "Couldn't get lock\n", goto close);
    if (ref $s && defined $$s) {
         print F $$s;
    } elsif (defined $s) {
         print F $s;
    }

    flock F, LOCK_UN;
    close F;

    my $path = $req->uri();

    $this->insert_or_update($path, $qstring, "/cache/$local_dir");

    return;
}

# copy_file_to_cache -   Copies a file to the cache instead of printing it from
#                        a blob.
sub copy_file_to_cache {
    my ($this, $req, $source_path, $filename) = @_;

    my ($can_cache, $qstring) = $this->can_request_use_cache_p($req);
    return if !$can_cache;
    
    my ($fp, $fn) = $this->find_cache_filename($req, $filename);
    my $local_dir = $fp . $fn;
    return if (!$fn);
    
    my $dir = $this->{cache_dir} . $fp;
    WebObvius::Cache::ApacheCache::make_sure_exist($dir) or return;
    
    my $dest_path = $dir . $fn;
    my $lockfile = $dest_path . ".LOCK";
    
    open LOCK, '>', $lockfile  || (warn "Couldn't open lockfile\n", return);
    flock LOCK, LOCK_EX || (warn  "Couldn't get lock\n", close LOCK, return);
    
    my $copy = 1;
    if(-f $dest_path) {
        my @s = stat $source_path;
        my @d = stat $dest_path;
        # Don't copy unless size doesn't match or source file has been modified.
        $copy = 0 unless($s[7] != $d[7] or $s[9] >= $d[9]);
    }
    
    system('cp', $source_path, $dest_path) if($copy);
    
    flock LOCK, LOCK_UN;
    close LOCK;

    my $path = $req->uri();
    
    $this->insert_or_update($path, $qstring, "/cache/$local_dir");

    return;
}

sub flush {
    my ($this, $commands) = @_;
    
    for my $table ($this->{local_table}, @{$this->{other_tables}}) {
        $this->flush_in_table($commands, $table);
    }
}

sub flush_in_table {
    my ($this, $commands, $table) = @_;
    
    $commands = [$commands] if (ref($commands) ne 'ARRAY');
    
    my %flush_simple;
    my @uris = map { lc $_->{uri} } grep {$_->{command} eq 'clear_uri' } @$commands;
    for my $uri (@uris) {
	$uri =~ s!/+$!!;
	$flush_simple{$uri} = $flush_simple{"$uri/"} = 1;
    }

    my @simple_uris = keys %flush_simple;
    
    while(my @cur_uris = splice @simple_uris, 0, 200) {
        my $qmarks = join(",", map{'?'} @cur_uris);
        my $flusher = $this->{obvius}->dbh->prepare(qq|
            DELETE FROM ${table}
                WHERE
                    uri IN ($qmarks)
        |);
        $flusher->execute(@cur_uris);
    }

    my @flush_regexps = map { $_->{regexp} } 
	grep {$_->{command} eq 'clear_by_regexp'} @$commands;
    my @flush_not_regexps = map { $_->{regexp} } 
	grep {$_->{command} eq 'clear_by_not_regexp'} @$commands;

    if(@flush_regexps) {
        my $regexp_condition = "(" . join(") OR (", map { "uri REGEXP ?" } @flush_regexps) . ")";
        eval {
            my $flusher = $this->{obvius}->dbh->prepare("DELETE FROM ${table} WHERE ($regexp_condition)");
            $flusher->execute(@flush_regexps);
        };
        if($@) {
            warn("Flushing with regexps ($regexp_condition) failed: $@");
        } else {
            @flush_regexps = ();
        }
    }

    if(@flush_not_regexps) {
        my $regexp_not_condition = "(" . join(") OR (", map { "uri NOT REGEXP ?" } @flush_not_regexps) . ")";
        eval {
            my $flusher = $this->{obvius}->dbh->prepare("DELETE FROM ${table} WHERE ($regexp_not_condition)");
            $flusher->execute(@flush_not_regexps);
        };
        if($@) {
            warn("Flushing with regexps ($regexp_not_condition) failed: $@");
        } else {
            @flush_not_regexps = ();
        }
    }

    # Check if we have to clear by no subsite
    if(grep { $_->{command} eq 'clear_by_no_subsite' } @$commands) {
	my $hostmap = Obvius::Hostmap->new_with_obvius($this->{obvius});

	$this->flush_by_pattern(sub {
	    my $uri = shift;
	    return !$hostmap->find_host_prefix($uri);
	});
    }
    
    # If the above fails due to perl-only regexps, fall back to flushing by pattern
    if(@flush_not_regexps or @flush_regexps) {
        return $this->flush_by_pattern_in_table(
            sub {
                my $uri = shift;
                $uri =~ /$_/ and return 1 for (@flush_regexps);
                $uri !~ /$_/ and return 1 for (@flush_not_regexps);
                return 0;
            },
            $table
        );
    }

    return 1;    
}

sub flush_by_pattern {
    my ($this, $pred) = @_;
    
    for my $table ($this->{local_table}, @{$this->{other_tables}}) {
        $this->flush_by_pattern_in_table($pred, $table);
    }
}

sub flush_by_pattern_in_table {
    my ($this, $pred, $table) = @_;
    
    my $lst = $this->{obvius}->dbh->prepare("SELECT uri FROM ${table}");
    my $del = $this->{obvius}->dbh->prepare("DELETE FROM ${table} WHERE uri = ?");
    $lst->execute;
    while(my ($uri) = $lst->fetchrow_array) {
        if($pred->($uri)) {
            $del->execute($uri);
        }
    }
}

sub quick_flush {} # No quick flush

# Mysql isn't fast at regexps, so avoid using it when finding pages that does
# not have a subsite. Flushing those will be handled by a flush_by_pattern
# call later.

sub find_related {
    my ($this, $uri) = @_;
    
    my $obvius = $this->{obvius};

    my $hostmap = Obvius::Hostmap->new_with_obvius($obvius);

    my $host_prefix = $hostmap->find_host_prefix($uri);

    if ($host_prefix) {
	 return { command => 'clear_by_regexp', regexp => "^$host_prefix" } 
    } else {
	 return { command => 'clear_by_no_subsite' };
    }
}


1;
