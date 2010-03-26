package WebObvius::Cache::ApacheCache;

use strict;
use warnings;

use Fcntl qw ( LOCK_EX LOCK_UN O_RDWR O_CREAT );
use SDBM_File;
use Digest::MD5 qw (md5_hex);

use Data::Dumper;
use Obvius::Hostmap;

use Exporter;

our @ISA = qw(Exporter);

our @EXPORT_OK = qw(is_relevant_for_leftmenu_cache is_relevant_for_tags 
                    is_relevant_for_tags_on_unpublish);

our %known_options = (
    cache_index => 1,
    cache_dir => 1
);


sub with_db {
     my ($this, $method) = @_;
     my $res;
     open my $fh, ">", $this->{cache_db_lock} or die "Couldn't open cache lock";
     
     eval {
          flock $fh, LOCK_EX or die "Couldn't get lock";
          my %h;
          tie (%h, 'SDBM_File', $this->{cache_db}, O_RDWR|O_CREAT, 0666) or 
            die "Failed to tie hash db";
          eval {
               $res = $method->(\%h);
          };
          untie %h;
          if ($@) {
               die $@;
          }
     };
     close $fh;
     if ($@) {
          die $@;
     }

     return $res;
}
     
sub new {
    my ($class, $obvius, %options) = @_;

    for (keys %options) {
	warn "ApacheCache: Unknow option <$_>" if (!$known_options{$_});
    }

    my $new = {obvius => $obvius, %options};

    my $var_dir = '/var/www/' . $obvius->{OBVIUS_CONFIG}{SITENAME} . '/var/';
    $new->{cache_dir} ||= $obvius->{OBVIUS_CONFIG}{CACHE_DIRECTORY} || ($var_dir . 'document_cache/');
    $new->{cache_db} ||= $obvius->{OBVIUS_CONFIG}{CACHE_DB}   
      || ($var_dir . 'cache_db/cache.dbm');
    $new->{cache_db_lock} ||= 
      $obvius->{OBVIUS_CONFIG}{CACHE_DB_LOCK} || ($var_dir . 'cache_db/.lock');
    $new->{cache_dir} .= '/' if ($new->{cache_dir} !~ m|/$|);

    die "ApacheCache: " . $new->{cache_dir} . " is not a directory\n" if 
	(! -d $new->{cache_dir});
    die "ApacheCache: " . $new->{cache_dir} . " is not writable by me\n" if 
	(! -w $new->{cache_dir});

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
	     $req->uri =~ m|^/preview/|                         ||
	     !$args_ok
	    );
}


sub find_cache_filename {
    my ($this, $req, $filename) = @_;

    my $ct = $req->content_type;
    $ct =~ s|^([a-zA-Z0-9.-]+/[a-zA-Z0-9.-]+).*|$1|;
    my $lang_array = $req->content_languages();
    my $lang = scalar @$lang_array ? $lang_array->[0] : 'da';
    my $code = md5_hex($req->hostname . ':' . $req->the_request);
    $code .= "_$filename"  if $filename;
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
	       mkdir $p, 0775 || return 0;
	       chmod 0775, $p;
	  }
     }

     return 1;
}

sub save_request_result_in_cache
{
     my ($this, $req, $s, $filename) = @_;
     
     return if !$this->can_request_use_cache_p($req);
     
     my ($fp, $fn) = $this->find_cache_filename($req, $filename);
     my $local_dir = $fp . $fn;
     return if (!$fn);
     
     my $dir = $this->{cache_dir} . $fp;
     make_sure_exist($dir) or return;
     
     open F, '>', $dir . $fn || (warn "Couldn't write cache\n", return);
     flock F, LOCK_EX || (warn  "Couldn't get lock\n", goto close);
     if (ref $s && defined $$s) {
          print F $$s;
     } elsif (defined $s) {
          print F $s;
     }
          
     flock F, LOCK_UN;
     close F;
     
     #Save image info.
     my ($args) = ($req->args =~ /^(size=\d+(?:x\d+|\%))$/) if ($req->args);
     $args ||= "";
     
     my $path = $req->uri();
     
     $this->with_db(sub {$_[0]->{$path . $args} = "/cache/$local_dir";});

     return;
}

sub flush {
    my ($this, $commands) = @_;

    $commands = [$commands] if (ref($commands) ne 'ARRAY');
    
    my %flush_simple;
    my @uris = map { lc $_->{uri} } grep {$_->{command} eq 'clear_uri' } @$commands;
    for my $uri (@uris) {
	$uri =~ s!/+$!!;
	$flush_simple{$uri} = $flush_simple{"$uri/"} = 1;
    }

    my @flush_regexps = map { qr/$_->{regexp}/i } 
	grep {$_->{command} eq 'clear_by_regexp'} @$commands;
    my @flush_not_regexps = map { qr/$_->{regexp}/i } 
	grep {$_->{command} eq 'clear_by_not_regexp'} @$commands;
    
    return $this->flush_by_pattern(
            sub {
		 my $uri = shift;
		 $uri =~ s|/size=\d+x\d+$||;
		 $flush_simple{lc $uri} and return 1;
		 $uri =~ /$_/ and return 1 for (@flush_regexps);
		 $uri !~ /$_/ and return 1 for (@flush_not_regexps);
		 
		 return 0;
	    });
}

sub flush_by_pattern {
    my ($this, $pred) = @_;

    $this->with_db( 
                   sub {
                        my ($h) = @_;
                        for my $k (keys %$h) {
                             if ($pred->($k)) {
                                  delete $h->{$k};
                             }
                        }
                   });
}
    
sub execute_query {
     my ($this, @args) = @_;
     
     return $this->{obvius}->execute_select(@args);
}

sub check_rightboxes {
     my ($this, $docs) = @_;
     
     return $this->check_vfields_for_docids($docs, [ 'rightboxes', 'boxes1', 'boxes2', 'boxes3'],
                                            anchored_regexp => 1);
}

sub uniquify_simple {
     my ($elems) = @_;
     my %seen;
     my @res;
     
     for my $elem (@$elems) {
          next if $seen{$elem}++;
          push @res, $elem;
     }
     
     return \@res;
}

sub bring_forth_sql_for_docsearch {
     my ($this, $docs, $str, %options) = @_;
     
     my @docids = grep { $_ && /^\d+$/ } map { ref $_ ? $_->{docid} : $_ } @$docs;
     return if !@docids;

     my $docids = uniquify_simple(\@docids);
     
     my @docid_query;
     if ($options{anchored_regexp}) {
          my $docids = join '|', @$docids;
          push @docid_query, "$str regexp '^[0-9]+:/($docids)\\\\.docid'";
     } else {
          @docid_query = map { "$str like '%/$_.docid%'" } @$docids;
     }

     my $sql = join " or ", @docid_query;
     return $sql;
}
     
sub check_vfields_for_docids {
     my ($this, $docs, $fields, %options) = @_;
     my $obvius = $this->{obvius};

     $fields = [ $fields ] if !ref $fields;
     $docs = [ $docs ] if !ref $docs;

     my $docsearch_sql = $this->bring_forth_sql_for_docsearch($docs, "text_value", %options);
     return [] if !$docsearch_sql;

     my $sql = <<END;
select distinct docid from versions v natural join vfields vf where
     vf.name = ? and v.public=1
END
     
     my @res;
     for my $field (@$fields) {
          my $query_sql = $sql . " and $docsearch_sql";
          push @res, map { $_->{docid}} @{$this->execute_query($query_sql, $field)};
     }

     return \@res;
}

     
sub find_referrers {
     my ($this, $docs) = @_;

     my $docids = $this->check_rightboxes($docs);

     my $res = $this->make_clear_uris($docids);
     return $res;
}

     
sub is_relevant_for_tags {
     my ($obvius, $docid, $vdoc) = @_;
     
     my $doc = $obvius->get_doc_by_id($docid);
     return 0 if !$doc;
     
     my $old_vdoc = $obvius->get_public_version($doc);
     return 1 if !$old_vdoc;
     
     $obvius->get_version_fields($old_vdoc, ['tags']);
     $obvius->get_version_fields($vdoc, ['tags']);
     
     my $old_tags = $old_vdoc->field('tags');
     my $tags = $vdoc->field('tags');
     
     return 1 if ((!$old_tags && $tags) || (!$tags && $old_tags));
     return 0 if (!$old_tags && !$old_tags);

     my %tags_hash = map { $_ => 1} @$old_tags;
     for my $tag (@$tags) {
          return 1 if (!$tags_hash{$tag});
     }
     
     %tags_hash = map { $_ => 1 } @$tags;
     
     for my $tag (@$old_tags) {
          return 1 if !$tags_hash{$tag};
     }

     return 0;
}

sub is_relevant_for_tags_on_unpublish {
     my ($obvius, $vdoc) = @_;
     
     $obvius->get_version_fields($vdoc, ['tags']);
     my $tags = $vdoc->field('tags');
     return $tags && @$tags;
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


sub make_clear_uris {
     my ($this, $docids) = @_;
     my $obvius = $this->{obvius};
     my @commands;

     for(@$docids) {
	  my $doc = $obvius->get_doc_by_id($_);
	  my $path = $obvius->get_doc_uri($doc) if ($doc); 
	  push @commands, {command => 'clear_uri', uri => $path} if($path);
     }

     return \@commands;
}

sub perform_command_clear_doctype {
     my ($this, $doctype_name) = @_;
     my $obvius = $this->{obvius};
     
     my $doctype = $obvius->get_doctype_by_name($doctype_name);
     return [] if !$doctype;

     my $query = <<END;
select distinct(docid) from 
    documents d inner join versions v on (v.docid = d.id)
where
    v.public = 1 AND (d.type = ? OR v.type = ?);
END
     my $docids = $this->execute_query($query, $doctype->Id, $doctype->Id);

     my @docids = map { $_->{docid} } @$docids;
     return $this->make_clear_uris(\@docids);
}
	 
sub perform_command_sophisticated_rightbox_clear {
     my ($this, @doctypes) = @_;
     
     return [] if !@doctypes;

     my @doctypes_sql = ('?') x @doctypes;
     my $doctypes_sql = '(' . (join ',', @doctypes_sql) . ')';
     
     
     my $query = "select distinct docid from versions v join doctypes dt on (dt.id = v.type)
                  where v.public = 1 and dt.name in $doctypes_sql";
     my @docids = map { $_->{docid} } @{$this->execute_query($query, @doctypes)};
     
     my @docids_to_clear;
     while (my @cur_docids = splice @docids, 0, 5000) {
          push @docids_to_clear, 
               @{$this->check_rightboxes(\@cur_docids, 
                                         ['rightboxes', 'boxes1', 'boxes2', 'boxes3'],
                                         anchored_regexp => 1)};
     }
     
     
     my @res_docids;
     my %seen;
     for my $docid (@docids_to_clear) {
          push @res_docids, $docid if(!$seen{$docid}++);
     }

     return $this->make_clear_uris(\@res_docids);
}

sub perform_command_rightbox_clear {
    my ($this, $table) = @_;
    
    my $docids = $this->execute_query("select distinct docid from $table");
    
    return $this->make_clear_uris([map { $_->{docid} } @$docids]);
}

sub uniquify_docs {
     my ($docs) = @_;
     my %seen;
     my @res;

     for my $doc (@$docs) {
          next if $seen{$doc->{docid}}++;
          push @res, $doc;
     }
     return \@res;
}

sub special_actions {
     my ($this, $docs) = @_;
     my $obvius = $this->{obvius};

     $docs = uniquify_docs($docs);
     
     my @commands;
     my %special_op_per_doctype = ( 
				   Nyhed => [
                                                {
						 command => 'clear_doctype', 
						 args => ['Nyhedsliste'] 
						}, 
						{
						 command => 'rightbox_clear', 
						 args => ['newslists']
						},
						{
						 command => 'clear_doctype', 
						 args => ['NyNyhedsliste'] 
						}],
				   CalendarEvent => [
						{
						 command => 'clear_doctype', 
						 args => ['Arrangementsliste']
						}, 
						{
						 command => 'rightbox_clear', 
						 args => ['calendars']
						},
						{
						 command => 'clear_doctype', 
						 args => ['NyArrangementsliste']
						}]
				  );
     
     for my $doc (@$docs) {
	  next if (!$doc->{doctype});
	  my $doctype = $obvius->get_doctype_by_id($doc->{doctype});
	  
	  my $cmd_list = $special_op_per_doctype{$doctype->{NAME}};
	  next if (!$cmd_list);
	  $cmd_list = [$cmd_list] if (ref $cmd_list ne 'ARRAY');
	  
	  for my $cmd (@$cmd_list) {
	       my $func = "perform_command_" . $cmd->{command};
	       my @args = (@{$cmd->{args}}, [$doc]);
	       my $cmds = $this->$func(@args);
	       push @commands, @$cmds;
	  }
     }
 
     return \@commands;
}

sub clear_moved {
     my ($this, @uris) = @_;
     
     my @docids;

     for my $uri (@uris) {
          $uri .= '%';
          my $res = $this->execute_query("select docid from docid_path dp natural join versions v
                                          where v.public = 1 and  path like ?", $uri);
          push @docids, map { $_->{docid} } @$res;
     }
     
     my @to_clear;
     for my $docid (@docids) {
          push @to_clear, @{$this->check_vfields_for_docids([{docid => $docid}], 
                                                            ['content', 'teaser', 
                                                             'html_content', 'introduction', 
                                                             'introduktion'])};
     }
     
     return $this->make_clear_uris(\@to_clear);
}
     
sub clear_tags {
     my ($this) = @_;
     
     return $this->perform_command_sophisticated_rightbox_clear("TagCloud");
}
     
          
sub find_dirty {
     my ($this, $cache_objects) = @_;

     my $vals = $cache_objects->request_values('uri', 'doctype', 'docid', 'clear_leftmenu', 
                                               'clear_recursively', 'document_moved');
     my @uris = grep { $_ } map { $_->{uri}   } @$vals;
     my @uris_to_clear = map { { command => 'clear_uri', uri => $_}} @uris;
     my @docid_uris =  
       map { {command => 'clear_uri', uri => "/$_->{docid}.docid" } } 
       grep { $_->{docid} } @$vals;
     push @uris_to_clear, @docid_uris;
     
     my @leftmenu_uris	= map { $_->{uri} } grep {  $_->{uri} and $_->{clear_leftmenu}} @$vals;
     my @related = map { $this->find_related($_) } @leftmenu_uris;
     
     my @clear_recursively = map {{command => 'clear_by_regexp', regexp => "^" . $_->{uri}}}
       grep { $_->{uri} and $_->{clear_recursively}} @$vals;
     
     my @moved_documents = grep { $_ } map { $_->{uri} } grep {$_->{document_moved} } @$vals;
     my $moved_documents = $this->clear_moved(@moved_documents);
     
     my @docids_doctypes = map { {docid => $_->{docid}, doctype => $_->{doctype}, uri => $_->{uri}}} 
       grep { $_->{docid}} @$vals;
     my $special_actions = $this->special_actions(\@docids_doctypes);

     my @docids		= grep { $_ } map { {docid => $_->{docid}, uri => $_->{uri} }} @$vals; 
     my $referrers = $this->find_referrers(\@docids);
     
     my @clear_tags = grep { $_ } 
                 map { $_->{clear_tags} } @{$cache_objects->request_values('clear_tags')};
     my @clear_tags_command = @{$this->clear_tags} if @clear_tags;
                   
     
     my @commands = grep { $_ } 
       (@clear_recursively,
	@$referrers,
	@related,
	@$special_actions,
	@uris_to_clear,
        @$moved_documents,
        @clear_tags_command
       );

     return \@commands;
}

sub uniquify_commands {
     my ($commands) = @_;
     
     my @res;
   OUTER: for my $cmd1 (@$commands) {
          for my $cmd2 (@res) {
	       my $same = 1;
               for (keys %$cmd1, keys %$cmd2) {
                    if (!exists $cmd1->{$_} || !exists $cmd2->{$_} || $cmd1->{$_} ne $cmd2->{$_}) {
			$same = 0;
		    }
               }
	       next OUTER if $same;
          }
	  push @res, $cmd1;
     }
     
     return \@res;
}

sub quick_flush {
    my ($this, $cache_objects) = @_;;
    
    my $uris = $cache_objects->request_values('uri', 'quick');
    my %uris = map { $_->{uri} => 1} grep { $_->{uri} and $_->{quick} } @$uris;
   
    $this->flush_by_pattern(sub {return $uris{$_[0]}; }) if(scalar keys %uris);
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
