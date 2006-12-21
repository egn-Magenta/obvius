package WebObvius::Site::Mason;

########################################################################
#
# Mason.pm - using Mason as the template system for a WebObvius::Site
#
# Copyright (C) 2001-2004 Magenta Aps, Denmark (http://www.magenta-aps.dk/)
#                         aparte A/S, Denmark (http://www.aparte.dk/),
#                         FI, Denmark (http://www.fi.dk/)
#
# Authors: Jørgen Ulrik B. Krag <jubk@magenta-aps.dk>
#          Peter Makholm <pma@fi.dk>
#          René Seindal
#          Adam Sjøgren <asjo@magenta-aps.dk>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2, or (at your option)
# any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software Foundation,
# Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
#
########################################################################

# $Id$

use strict;
use warnings;

use WebObvius::Site;

our @ISA = qw( WebObvius::Site );
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

use WebObvius::Template::MCMS;
use WebObvius::Template::Provider;

use WebObvius::Cache::Flushing;

use WebObvius::Apache 
	Constants	=> qw(:common :methods :response),
	File		=> ''
;

use HTML::Mason;
# Support Mason before version 1.10 and after simultaneously:
my $new_mason;
BEGIN {
    # The way to specify args_method was changed from version 1.10 and onwards:
    if ($HTML::Mason::VERSION < 1.10) {
        eval "use HTML::Mason::ApacheHandler (args_method=>'mod_perl');";
        $new_mason=0;
    }
    else {
        eval "use HTML::Mason::ApacheHandler;";
        $new_mason=1;
    }
}

use Digest::MD5 qw(md5_hex);

use POSIX qw(strftime);
use Fcntl ':flock';


########################################################################
#
#	Construction
#
########################################################################

sub new
{
	my ( $class, %options) = @_;

	my $new = $class-> SUPER::new( %options);

	my $basedir = $options{base};

	unless ( $new_mason) {
		$new->{parser} = new HTML::Mason::Parser(
		 	in_package    => $class,
		 	# XXX have both $mcms and $obvius here!
		 	allow_globals => [qw($mcms $obvius $doc $vdoc $doctype $prefix $uri)],
		);
	}

	my %interp_conf = (
		comp_root       => $options{comp_root},
		data_dir        => "$basedir/var/$options{site}/",
		max_recurse     => 64, # Default is 32
		preamble        => 
			"my \$benchmark = Obvius::Benchmark->new( __FILE__) if \$obvius->{BENCHMARK};\n",
	);

	if ($new_mason) {
		$interp_conf{autoflush}        = 0;
		$interp_conf{data_cache_api}   = '1.0'; # XXX This won't be supported by Mason forever, but
		                                        # we need it for compability with the old admin.
	} else {
		$interp_conf{parser}           = $new->{parser};
		$interp_conf{static_file_root} = "$basedir/docs";
		$interp_conf{out_mode}         = 'batch';
	}


	if (defined $options{out_method}) {
		$interp_conf{out_method}       = $options{out_method};
		$new->param( SITE_SCALAR_REF   => $options{out_method});
	}

	if (!$new_mason) {
		# Interp was a Mason<1.10 thing. In later Masonae all options
		# are passed to ApacheHandler instead.
		$new-> {interp} = new HTML::Mason::Interp( %interp_conf);
	}

	# If $class ends in ::Common or ::Public, set auto_send_headers to
	# false (we still want headers sent automatically in admin,
	# because less of the handler() is used there (and more is handled
	# in Mason in admin):
	my %apachehandler_options = (
		apache_status_title => 'HTML::Mason: ' . $class,
		# error_mode        => $options{debug} ? 'html' : 'fatal',
		decline_dirs        => 0,
		auto_send_headers  => (scalar ($class) =~ /::(Common|Public)$/) ? 0 : 1,
	);

	if ($new_mason) {
		%apachehandler_options = ( %apachehandler_options, %interp_conf);
		$apachehandler_options{allow_globals} = [
			qw($mcms $obvius $doc $vdoc $doctype $prefix $uri)
		];
		$apachehandler_options{args_method}   = 'mod_perl';
	}
	else {
		$apachehandler_options{interp}        = $new->{interp};
	}

	$new-> {handler} = new HTML::Mason::ApacheHandler( %apachehandler_options);

	if (!$new_mason) {
		# In Mason<1.10 this has to be done "manually":
		# It would be nice, if the user Apache runs as could be detected, instead of this:
		my $httpd_user  = scalar(getpwnam 'www-data' || getpwnam 'httpd' || getpwnam 'apache');
		my $httpd_group = scalar(getgrnam 'www-data' || getgrnam 'httpd' || getgrnam 'apache');
		chown ($httpd_user, $httpd_group, $new->{interp}->files_written);
	}

	$new->{is_admin} = $options{is_admin};

	return bless $new, $class;
}


########################################################################
#
#	Cache
#
########################################################################

# can_use_cache - Check if the given request is fit for being cached or not.
#                 Note: this method is also present in WebObvius::Site::MultiMason
sub can_use_cache {
    my ($this, $req, $output) = @_;

    $output ||= $req->pnotes('OBVIUS_OUTPUT');

    return '' if ($output && $output->param('OBVIUS_SIDE_EFFECTS'));
    return '' if ($req->no_cache);
    return '' unless ($req->method_number == M_GET);
    return '' unless ($this->{WEBOBVIUS_CACHE_INDEX} and
		      $this->{WEBOBVIUS_CACHE_DIRECTORY});
    return '' if($req->dir_config('WEBOBVIUS_NOCACHE'));
    return '' if (-e $this->{WEBOBVIUS_CACHE_INDEX} . "-off");
    return '' if $req-> notes('nocache');

    my $vdoc=$output->param('version');
    my $lang=$vdoc->Lang || 'UNKNOWN'; # Should always be there

    my $content_type = $req->content_type;
    return '' unless ($content_type =~ s|^([a-zA-Z0-9.-]+/[a-zA-Z0-9.-]+).*|$1|);
                                            # Not really the RFC2045 definition but should work most of the time
    $req->content_type($content_type);

    my $id = md5_hex($req-> hostname . ':'. $req->the_request);
    $id .= '.gz' if ($req->notes('gzipped_output'));

    $req->notes('cache_id' => $id);
    $req->notes('cache_dir' => join '/', $this->{WEBOBVIUS_CACHE_DIRECTORY}, $lang, $req->content_type, substr($id, 0, 2));
    $req->notes('cache_file' => $req->notes('cache_dir') .  '/' . $id);
    $req->notes('cache_url' => join '/', '/cache', $lang, $req->content_type, substr($id, 0, 2), $id);

    Obvius::log->debug("Cache file name ", $req->notes('cache_file'), "\n");

    return 1;
}

# save_in_cache - Saves the data in $s in the document cache.
#                 can_use_cache should always be called before calling this method.
#                 Note: this method is also present in WebObvius::Site::MultiMason
sub save_in_cache {
    my ($this, $req, $s) = @_;

    my $obvius=$req->notes('obvius');

    my $log;
    if (defined $obvius) {
        $log = $obvius->log;
    } else {
        $log = Obvius::log();
    }

    my $id = $req->notes('cache_id');
    return unless ($id);
    return unless ($this->{WEBOBVIUS_CACHE_INDEX}
                   and $this->{WEBOBVIUS_CACHE_DIRECTORY});

    my $dir = $req->notes('cache_dir');
    unless (-d $dir) {
        my $d;
        my @dirs = split '/', $dir;
        if ($dirs[0] eq '') {
            $dir = '/'; shift @dirs;
        } else {
            $dir = '';
        }
        while ($d = shift @dirs) {
            $dir .= $d . '/';
            unless (-d $dir) {
                mkdir($dir, 0775) or do{$log->debug("Couldn't make dir: $dir"); return};
                chmod(0775, $dir);
            }
        }
    }

    my $file = $req->notes('cache_file');

    $log->debug("Cache file name $file");
    unlink($file);

    my $fh = new Apache::File('>'.$file);
    if ($fh) {
        $log->debug("Cache file open ok");
        print $fh (ref($s) ? $$s : $s);
        $fh->close;

        my $extra = '';
        my $qstring = $req->args;
        if ($qstring and $qstring =~ /^size=\d+(x\d+|\%)$/) {
            $extra = $qstring;
        }

        # Add to cache-db
        $fh = new Apache::File('>>' . $this->{WEBOBVIUS_CACHE_INDEX});
        if (open FH, '>>', $this->{WEBOBVIUS_CACHE_INDEX}) {
            if (flock FH, LOCK_EX|LOCK_NB) {
                my $real_path=$req->uri();
                # If handle_path_info() is true on the doctype
                # (see WebObvius::Site::obvius_document),
                # obvius_path_info needs to be added:
                $real_path.=$req->notes('obvius_path_info') . '/' if (defined $req->notes('obvius_path_info'));
                print $fh $real_path, $extra, "\t", $req->notes('cache_url'), "\n";
                $log->debug(" ADDED TO CACHE: " . $req->uri);
            } else {
                $log->debug("Couldn't lock WEBOBVIUS_CACHE_INDEX-file");
            }
            close FH;
        }
        else {
            $log->debug("Couldn't write to WEBOBVIUS_CACHE_INDEX-file ($this->{WEBOBVIUS_CACHE_INDEX})");
        }

    }
    $log->debug("Cache file done");
}

sub dirty_url_in_cache {
    my ($this, $url) = @_;

    # XXX This should just remove the url from the CACHE_INDEX and
    # (possibly) delete the corresponding file in the
    # CACHE_DIRECTORY. That would be nice. Well. Any search document
    # that finds the document should be removed as well. And if it's
    # on a newsbox, then...  Conclusion: clear the whole she-bang:

    # 20020619 New conclusion: Remove the dirty url immediately and
    # clear the rest slowly.

    # XXX This should be called when a document is
    # published/unpublished. And when it expires(!)

    WebObvius::Cache::Flushing::flush($url,$this->{WEBOBVIUS_CACHE_DIRECTORY} . 'flush.db', $this->{WEBOBVIUS_CACHE_INDEX});
}

sub clear_cache {
    my ($this, $obvius) = @_;

    return 0 unless ($this->{WEBOBVIUS_CACHE_INDEX});

    WebObvius::Cache::Flushing::immediate_flush($this->{WEBOBVIUS_CACHE_DIRECTORY} . 'flush.db', $this->{WEBOBVIUS_CACHE_INDEX});

    # Notice that handle_mason_cache is only called if the
    # $obvius-argument is defined, for backward compability (the old
    # admin does not need handle_mason_cache and does not pass
    # $obvius).
    $this->handle_mason_cache($obvius, undef) if (defined $obvius);
}


########################################################################
#
#	Handlers
#
########################################################################

sub access_handler ($$) {
    my ($this, $req) = @_;

    return OK unless ($req->is_main);

    # We havn't created the $obvius yet. Fall back on Obvius::log()
    #Obvius::log->debug(" Mason::access_handler ($this : " . $req->uri . ")";

    $this->tracer($req) if ($this->{DEBUG});
    my $benchmark = Obvius::Benchmark-> new('mason::access') if $this-> {BENCHMARK};

    my $uri=$req->uri;
    my $remove = $req->dir_config('RemovePrefix');
    $uri =~ s/^\Q$remove\E// if ($remove);
    # We will allow .html (but don't use it if you don't need it) ...
    #$uri =~ s/\.html?$//;
    $req->notes(prefix=>($req->dir_config('AddPrefix') || ''));
    $req->notes(uri=>$uri);
    $req->uri($uri) unless ($req->dir_config('AddPrefix')); # I'm unsure about this... but I'm guessing it's okay to put here.

    my $orig_uri = $uri;
    my $roothost = $req->subprocess_env('ROOTHOST');

    # XXX Instead of checking for a '.' in the uri here, wouldn't it
    # be better to only do this whole slash-redirection thing only if
    # there is no alternate_location for the document?
    # The problem with that is, that we only know if there is an
    # alternate location much later (in handler, below), so it takes a
    # little more work to change it.
    
    # ... and we auto-slash any uri without .'s in it except on admin where it's
    # handled in Mason ...
	if ($orig_uri !~ m!/$! and $orig_uri !~ /[.]/ and !$this->param('is_admin')) {
        # If on a subsite system (eg. roothost is set) always redirect to the roothost
        # or we will get a double subsite rewrite. A better way to handle this would be
        # good since we now wil get 3 redirects if a user ommits the ending /:
        # http://subsite.somehost/someurl =>
        # http://roothost.somehost/somesubsite/someurl/ =>
        # http://subsite.somehost/someurl/
        my $host_part = $roothost ? ('http://' . $roothost) : '';
        return $this->redirect($req, $host_part . $req->notes('prefix') . $orig_uri . '/', 'force-external')
    }


    # The orig_uri case from above does not apply to admin, however, so it's
    # not needed here.
    return $this->redirect($req, $req->notes('prefix') . $uri , 'force-external') 
    	if (!$this->param('is_admin') and ($uri =~ s{[.]html/$}{.html}i)); 
	# ... and we auto-deslash any uri which ends in .html.

    my $obvius   =$this->obvius_connect($req, $req->notes('user'), undef, $this->{SUBSITE}->{DOCTYPES}, $this->{SUBSITE}->{FIELDTYPES}, $this->{SUBSITE}->{FIELDSPECS});
    return SERVER_ERROR unless ($obvius);

    # Cache these structures: (they should be dirtied when the db is updated... XXX)
    map { unless ($this->{SUBSITE}->{$_}) { $obvius->log->debug("$this->{SUBSITE}: CACHING $_"); $this->{SUBSITE}->{$_}=$obvius->{$_}} }
	qw(DOCTYPES FIELDTYPES FIELDSPECS);

    my $doc    =$this->obvius_document($req, $uri);
    return NOT_FOUND unless ($doc);

    $req->pnotes('document'=>$doc);
    $req->pnotes('site'    =>$this);

    return OK;
}

# handler - Handles incoming Apacghe requests when using Mason as template system.
sub handler ($$) {
    my ($this, $req) = @_;

    # Does we need to do this before fetching $obvius-object?
    Obvius::log->debug(" Mason::handler ($this : " . $req->uri . ")");

    $this->tracer($req) if ($this->{DEBUG});
    my $benchmark = Obvius::Benchmark-> new('mason::handler') if $this-> {BENCHMARK};

    $req->notes(now => strftime('%Y-%m-%d %H:%M:%S', localtime($req->request_time)));

    my $obvius=$req->pnotes('obvius');
    my $doc=$req->pnotes('document');

    unless ($this->param('is_admin')) {
	return NOT_FOUND unless ($obvius->is_public_document($doc));
	my $vdoc = $this->obvius_document_version($req, $doc);
	return NOT_FOUND unless ($vdoc);
	return FORBIDDEN if ($vdoc->Expires lt $req->notes('now'));

	my $doctype = $obvius->get_version_type($vdoc);

        my $output = $this->create_output_object($req,$doc,$vdoc,$doctype,$obvius);

    # The document can have a "alternate_location" method if the user should be redirected to a different URL.
    # The method should return a path or URL to the new location.
	if (my $alternate = $doctype->alternate_location($doc, $vdoc, $obvius, $req->uri)) {
	    return NOT_FOUND if (Apache->define('NOREDIR'));
	    return $this->redirect($req, $alternate, 'force-external');
	}

    # Documents returning data which shouldnt be handled by the portal (eg. a download document), but directly
    # by the browser should have a method called "raw_document_data"
	    	
	my ($mime_type, $data, $filename, $con_disp) = $doctype->raw_document_data(
		$doc, $vdoc, $obvius, 
		WebObvius::Apache::apache_module('Request')-> new($req), 
		$output
	);

	if ($data) {
	    $mime_type ||= 'application/octet-stream';

	    $obvius->log->debug(" Serving raw_document_data from db: $mime_type");

	    $this->set_expire_header($req, expire_in=>30*24*60*60); # 1 month
	    $req->content_type($mime_type);
	    if($filename) {
	        $con_disp ||= 'attachment';
	        $req->header_out("Content-Disposition", "$con_disp; filename=$filename");
                # Microsoft Internet Explorer/Adobe Reader has
                # problems if Vary is set at the same time as
                # Content-Disposition is(!) - so we unset Vary if we
                # set Content-Disposition.
                $req->header_out('Vary'=>undef);
	    }

            # The spec. says that it is not necessary to advertise this:
            # $req->header_out('Accept-Ranges'=>'bytes');

            # Handle Range: N-M
            my $range=$req->headers_in->{Range};
            if (defined $range and $range=~/^bytes=(\d*)[-](\d*)$/) {
                my ($start, $stop)=($1 || 0, $2 || length($data));

                # Sanity check range:
                if ($start>length($data) or $stop>length($data) or $start>$stop) {
                    $req->header_out('Content-Range'=>'0-0/' . length($data));
                    $req->status(416); # "Requested range not satisfiable"
                    $req->send_http_header;
                    return OK;
                }

                $req->header_out('Content-Range'=>'bytes ' . $start . '-' . $stop . '/' . length($data));
                $req->set_content_length($stop-$start);
                $req->status(206); # "Partial content"
                $req->send_http_header;
                $req->print(substr($data, $start, $stop-$start));
            }
            else {
                $req->set_content_length(length($data));
                $req->send_http_header;
                $req->print($data) unless ($req->header_only);
            }

            # Add to cache:
            if ($this->can_use_cache($req,$output) and not scalar($req->args)) {
	        $this->save_in_cache($req, \$data);
	    }
            else {
	        $obvius->log->debug(" NOT ADDED TO CACHE: " . $req->notes('uri'));
	    }

	    return OK;
	}

	$req->content_type('text/html') unless $req->content_type;
	$req->content_type('text/html') if $req->content_type =~ /directory$/;
	return -1 unless ($req->content_type eq 'text/html');
    }
    else {
	# XXX $req->no_cache(1);
    }

    $obvius->log->debug("  Mason on " . $req->document_root . $req->notes('prefix') . "/dhandler");
    $req->filename($req->document_root . $req->notes('prefix') . "/dhandler"); # default handler

    my $status=$this->execute_mason($req);

    if (defined $this->{'SITE_SCALAR_REF'}) { # This, out_method, is not used in admin; only for public.
	my $html="Couldn't generate page. Yikes.";
	if ($status==OK) {
	    $html=${$this->{'SITE_SCALAR_REF'}};
        }
        ${$this->{'SITE_SCALAR_REF'}}='';

        # Set headers from the hashref $output->param('OBVIUS_HEADERS_OUT'), if present.
        # XXX Consider whether checking if each header is already set should be done,
        #     and how conflicts should be resolved?
        my $headers_out=$req->pnotes('OBVIUS_OUTPUT')->param('OBVIUS_HEADERS_OUT');
        if ($headers_out) {
            map { $req->header_out($_=>$headers_out->{$_}); } keys %$headers_out;
        }

        # Previously the ::Common object would send the headers, so
        # the Public-object had to not do that.  Now the
        # WebObvius::Site::Mason::new()-method sets auto_send_header to
        # false if the objects name ends in ::Common or ::Public, so the
        # the Public-object must (can!) send the headers here, now.
        #
        # The benefit is that we can set_content_length, and that
        # means that browser can keepalive the connection, and don't
        # have to make another one to get the rest of the stuff. That
        # should amount to an efficiency-improvement...
        $req->status($status) if ($status!=OK);
        $req->set_content_length(length($html)) unless ($req->header_only or $status!=OK);
        $req->send_http_header;

        $req->print($html) unless ($req->header_only or $status!=OK);

        # Add to cache:
        if ($this->can_use_cache($req) and $status==OK) {
	    $this->save_in_cache($req, \$html);
	}
        else {
	    $obvius->log->debug(" NOT ADDED TO CACHE: " . $req->notes('uri'));
	}

    }

    $this->handle_modified_docs_cache($obvius);

    return $status;
}

sub handle_modified_docs_cache { # See also obvius/mason/admin/default/dirty_cache
    my ($this, $obvius)=@_;

    #print STDERR __PACKAGE__, '->handle_modified_cache', "\n";
    my $modified_list=$obvius->list_modified();
    if (scalar(@$modified_list)) {
        my %dirty_urls=();
        my %dirty_docids=();

        # Turn of object-cache (otherwise we get wrong parents after a move!):
        $obvius->cache(0);

        #print STDERR " docs modified:\n";
        my $i=1;
        foreach my $modified (@$modified_list) {
            # Find document:
            my $mod_doc=undef;
            if (defined $modified->{docid}) {
                $mod_doc=$obvius->get_doc_by_id($modified->{docid});
            }
            elsif (defined $modified->{url}) {
                $mod_doc=$obvius->lookup_document($modified->{url});
            }
            # Find url:
            my $mod_url=undef;
            if (defined $modified->{url}) {
                $mod_url=$modified->{url};
            }
            elsif (defined $mod_doc) {
                $mod_url=$obvius->get_doc_uri($mod_doc);
            }

            #print STDERR "  (", $i++, ") ", ($modified->{docid} || $modified->{url}), " ";
            if ($mod_doc) { # The doc exists, evict it:
                #print STDERR "doc exists ";
                if ($mod_url) {
                    $dirty_urls{$mod_url}=1;
                    $dirty_docids{$mod_doc->Id}=1;
                }
                if (my $mod_parent=$obvius->get_doc_by_id($mod_doc->Parent)) {
                    #print STDERR "parent ", $mod_parent->Id, " ";
                    if (my $mod_parent_url=$obvius->get_doc_uri($mod_parent)) {
                        $dirty_urls{$mod_parent_url}=1;
                        $dirty_docids{$mod_parent->Id}=1;
                    }
                }
            }
            elsif ($modified->{url}) { # A doc couldn't be found for
                                       # this url, but do pass it
                                       # anyway, in case some caches
                                       # uses url as key:
                $dirty_urls{$modified->{url}}=2; # 2 is just for
                                                 # debugging, true is
                                                 # all that is used
            }
            #print STDERR "\n";
        }
        # Consider only doing this for the public ones:
        # (or do we define that it's up to dirty_url_in_cache to worry about that?)
        map { #print STDERR "  dirty_url: $_\n";
              $this->dirty_url_in_cache($_); } keys %dirty_urls;

        # Handle the Mason-cache:
        $this->handle_mason_cache($obvius, \%dirty_docids);

        # Turn object-cache back on:
        $obvius->cache(1);
    }
}

# handle_mason_cache - given a hash-ref to dirty docids, calls the
#                      mason-component that invalidates the
#                      cache-entries accordingly, in its own
#                      namespace. If no hash-ref is given, the
#                      components clears the entire cache. Returns the
#                      status if the mason-component run. False on
#                      failure.
sub handle_mason_cache {
    my ($this, $obvius, $dirty_docids)=@_;

    # Only do this, if the website uses a newer admin - check if the
    # CacheHandling-package is there:
    my $package=$obvius->config->param('perlname') . '::Site';
    my $cachehandling_package=$package . '::Admin::CacheHandling';
    my $str="\$" . $cachehandling_package . '::VERSION;';
    my $res=eval $str;
    my $error=$@;
    if (!$res) {
        my $config=$obvius->config;
        warn "Package $cachehandling_package not defined. If this website uses an obsolete admin, please set 'suppress_obsolete_admin_warning=1' in the websites .conf-file" unless ($config->param('suppress_obsolete_admin_warning'));
        return;
    }

    # This method must be callable from ::Public as well as ::Admin
    # (think CreateDocument and similar doctypes).
    #
    # So we get the Admin-object from the Perlname::Site-package:
    $str="\$" . $package . '::Admin;';
    my $admin=eval $str;

    # Run Mason by hand:
    my $string='';
    my $status;
    my $interp;
    if ($new_mason) {
        $interp=HTML::Mason::Interp->new(
                                         allow_globals=>[qw($obvius)],
                                         in_package=>$cachehandling_package,
                                         comp_root=>$admin->{handler}->interp()->comp_root(),
                                         data_dir=>$admin->{handler}->interp()->data_dir(),
                                         data_cache_api=>'1.0',
                                         out_method=>\$string,
                                        );
    }
    else {
        my $parser=HTML::Mason::Parser->new(
                                            allow_globals=>[qw($obvius)],
                                            in_package=>$cachehandling_package,
                                           );
        $interp=HTML::Mason::Interp->new(
                                         parser=>$parser,
                                         comp_root=>$admin->{interp}->comp_root(),
                                         data_dir=>$admin->{interp}->data_dir(),
                                         out_method=>\$string
                                        );
    }

    $interp->set_global(obvius=>$obvius);

    # XXX Should pass dirty_urls as well, in case some caches use url as key:
    $status=$interp->exec('/default/dirty_cache', sitebase=>$admin->Base, dirty_docids=>$dirty_docids);

    if (!$status) {
        warn "Error when running dirty_cache: $status ($string)";
    }
    $string=undef;

    return $status;
}

sub execute_mason {
    my ($this, $req)=@_;

    # Run mason on the request:
    my $status=$this->{handler}->handle_request($req);

    # Clean up globals (we don't clean up $r; we didn't make it):
    if ($new_mason) {
        # XXX IMPLEMENT FOR NEWER, >=1.10, MASONAE!
        warn "Need to implement cleaning up globals for Mason =>1.10\n";
    }
    else {
        map { $this->{handler}->interp->set_global($_=>undef) }
            grep { $_ ne '$r' }
                $this->{handler}->interp->parser->allow_globals();
    }

    return $status;
}

sub authen_handler ($$) {
    my ($this, $req) = @_;

    Obvius::log->debug(" Mason::authen_handler ($this : " . $req->uri . ")");

    my $benchmark = Obvius::Benchmark-> new('mason::authen') if $this-> {BENCHMARK};

    return OK unless ($req->is_initial_req); # Only check on the initial request, not
                                             # any subrequests (think /admin/admin/...)
    my ($res, $pw) = $req->get_basic_auth_pw;
    return $res unless ($res == OK);

    my $login = $req->connection->user;
    unless ($login and $pw) {
	$req->note_basic_auth_failure;
	return AUTH_REQUIRED;
    }

    # Check password
    my $obvius = $this->obvius_connect($req, $login, $pw, $this->{SUBSITE}->{DOCTYPES}, $this->{SUBSITE}->{FIELDTYPES}, $this->{SUBSITE}->{FIELDSPECS});
    unless ($obvius) {
        $req->note_basic_auth_failure;
        return AUTH_REQUIRED;
    }

    # if there's no 'admin', it's an old table layout
    my $uid = $obvius-> get_user( $login);
    if ( exists $uid->{admin} and not $uid->{admin}) {
        $req->note_basic_auth_failure;
        return AUTH_REQUIRED;
    }

    $req->notes(user=>$login);

    return OK;
}

# public_authen_handler - this method is called by Apache with a
#                         request object (notice the prototype, which
#                         is necessary for Apache) during the
#                         authentification phase of the request on the
#                         public website (if so defined in
#                         setup.conf). Connects to obvius and handles
#                         a public login cookie if the request isn't a
#                         sub-request. Always returns OK.
sub public_authen_handler($$) {
    my ($this, $req) = @_;

    return OK unless ($req->is_initial_req);

    my $obvius = $this->obvius_connect($req);

    # Handle obvius_public_login cookie
    $this->public_login_cookie($req, $obvius);

    return OK;

}

sub authz_handler ($$) {
    my ($this, $req) = @_;

    Obvius::log->debug(" Mason::autz_handler ($this : " . $req->uri . ")");

    # Lookup user-permissions...

    return $this->access_handler($req);
}

sub rulebased_authen_handler ($$) 
{
	my ($this, $req) = @_;

	Obvius::log->debug(" Mason::authz_handler_rulebased ($this : " . $req->uri . ")");
	
	my $doc = $req-> pnotes('document');
	return NOT_FOUND unless $doc;
		
	my ( $login, $uid, $obvius);

	# stage 1: try to access the document as nobody
	$obvius = $this-> obvius_connect(
		$req, 
		$login = 'nobody', undef, 
		$this->{SUBSITE}->{DOCTYPES}, 
		$this->{SUBSITE}->{FIELDTYPES}, 
		$this->{SUBSITE}->{FIELDSPECS}
	);
	return SERVER_ERROR unless $obvius;
	
	$uid = $obvius-> get_user( $login);
	return SERVER_ERROR unless $uid;
	$req-> notes( user => $login);

	# check if the user can view the document
	my $caps = $obvius-> compute_user_capabilities( $doc, $uid->{id});
	return OK if $caps->{view};

	# stage 2: cannot access the document anonymously, try to authenticate
	my ( $have_user, $password) = $req-> get_basic_auth_pw;
	goto AUTH_FAIL unless $have_user == OK;
	$login = $req-> connection-> user;
	goto AUTH_FAIL unless $login and $password;

	$obvius-> {USER}     = $login;
	$obvius-> {PASSWORD} = $password;
	goto AUTH_FAIL unless $obvius-> validate_user;

	# authenticated, can view?
	$uid = $obvius-> get_user( $login);
	return SERVER_ERROR unless $uid;
	$req-> notes( user => $login);

	unless ( $uid-> {admin}) {
		$caps = $obvius-> compute_user_capabilities( $doc, $uid->{id});
		goto AUTH_FAIL unless $caps->{view};
	}

	# finally, turn server cache off for the protected documents
    	$req-> notes('nocache', 1) unless $have_user == OK;

	return OK;

AUTH_FAIL:
	$req-> note_basic_auth_failure;
	return AUTH_REQUIRED;
}


#######################################################################
#
#	Public handling functions
#
#######################################################################

# create_output_object - if an output-object has already been created,
#                        put on $r->pnotes, return that. Otherwise
#                        create an output-object (with SERVER_NAME,
#                        PREFIX, URI, PATH_INFO, NOW, VERSION,
#                        DOCUMENT, DOCTYPE), put it on $r->pnotes and
#                        return it.
#
#                        Expects the request object, doc object,
#                        version object, doctype object and obvius
#                        object as inputs.
#
sub create_output_object {
    my ($this, $req, $doc, $vdoc, $doctype, $obvius) = @_;

    my $output = $req->pnotes('OBVIUS_OUTPUT');

    unless (defined $output) {
        $output = new Obvius::Data;
        $output->param(SERVER_NAME => $req->server->server_hostname);
        $output->param(PREFIX => $req->notes('prefix'));
        $output->param(URI => $req->uri);
        $output->param(PATH_INFO => $req->path_info);
        $output->param(NOW => $req->notes('now'));
        $output->param(VERSION=>$vdoc);
        $output->param(DOCUMENT=>$doc);
        $output->param(DOCTYPE=>$doctype);
        $req->pnotes(OBVIUS_OUTPUT => $output);
    }

    return $output;
}

sub expand_output {
    my ($this, $site, $output, $req) = @_;
    
    my $benchmark = Obvius::Benchmark-> new('mason::expand output') if $this-> {BENCHMARK};

    # XXX Hvordan pokker håndteres dette? XXX
    # Måske kan HTML::Mason::Interp out_method hjælpe?
    # Måske lidt a la dette:

    $req->notes('is_admin'=>$output->param('IS_ADMIN')) if ($output->param('IS_ADMIN'));
    my $filename=$site->param('comp_root')->[0]->[1] . '/switch'; # Grab the docroot from the setup.pl
    $req->filename($filename);
    $req->pnotes('OBVIUS_OUTPUT'=>$output);

    my $status=$this->execute_mason($req);

    my $s='We have an anomaly, the subsite centerpiece was unable to generate.';
    # Ou wee, handle this better (subsite_scalar_ref must be emptied for each request):
    if ($status==OK) {
	$s=${$this->{'SITE_SCALAR_REF'}};
    }
    ${$this->{'SITE_SCALAR_REF'}}='';

    return $s;
}

1;
__END__

=head1 NAME

WebObvius::Site::Mason - use Mason as the template system for a site.

=head1 SYNOPSIS

  use WebObvius::Site::Mason;

  my $output=$this->create_output_object($r, $doc, $vdoc, $doctype, $obvius);

  # In setup.conf:
  PerlAuthenHandler Example::Site::Public->public_authen_handler

=head1 DESCRIPTION

Connects WebObvius with Mason, so Mason can be used as the template
system for an Obvius-site.

Supports Mason before version 1.10 and after - tested on 1.04 (before,
Debian woody) and 1.26 (after, Debian sarge).

=head1 AUTHOR

Jørgen Ulrik B. Krag <jubk@magenta-aps.dk>
Peter Makholm <pma@fi.dk>
René Seindal
Adam Sjøgren <asjo@magenta-aps.dk>

=head1 SEE ALSO

L<WebObvius::Site>, L<Obvius>.

=cut
