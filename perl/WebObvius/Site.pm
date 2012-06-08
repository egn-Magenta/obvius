package WebObvius::Site;

########################################################################
#
# Site.pm - General site object
#
# Copyright (C) 2001-2004 Magenta Aps, Denmark (http://www.magenta-aps.dk/)
#                         aparte A/S, Denmark (http://www.aparte.dk/),
#                         FI, Denmark (http://www.fi.dk/)
#
# Authors: Jørgen Ulrik B. Krag (jubk@magenta-aps.dk)
#          Peter Makholm (pma@fi.dk)
#          René Seindal,
#          Adam Sjøgren (asjo@magenta-aps.dk),
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

use Obvius;
use Obvius::Data;

use WebObvius;
use WebObvius::Cache::Cache;

use Image::Size;
use Data::Dumper;
our @ISA = qw( Obvius::Data WebObvius );
our $VERSION="1.0";

our %xml_cache;

use constant TRANSLATION_FILENAME => 'translations';
use constant TRANSLATION_SUFFIXES => ('_local.xml', '.xml');

use WebObvius::Apache
        Constants       => qw(:common :methods :response),
        Util            => '',
        Cookie          => ''
;

use Digest::MD5 qw(md5_hex);

use POSIX qw(strftime);

use XML::Simple;
use Unicode::String qw(utf8 latin1);
use Obvius::PreviewDocument;

sub new
{
        my $self = shift-> SUPER::new(@_);
	
        $self-> {LANGUAGE_PREFERENCES} = [];
        $self-> load_translation_fileset();
	
        return $self;
}


########################################################################
#
#       Language handling
#
########################################################################


# get_languages - returns a hash with keys being languages and values
# being their priority. The higher value the more preferred

sub get_language_preferences {
    my ($this, $req)=@_;

    my %lang;
    my $accept_language = $req->headers_in->{'Accept-Language'};
    if ($accept_language) {
        %lang = split_language_preferences($accept_language);

        # Add "Accept-Language" to the "Vary" header:
        # See: <http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.44>
        my @vary;
        push(@vary, $req->header_out('Vary')) if $req->header_out('Vary');
        push @vary, "Accept-Language";
        $req->header_out('Vary', join(', ', @vary));
    }

    # The cookie "lang" overrides browser-settings:
    my $cookies=Apache::Cookie->fetch; # XXX Called in create_input_object as well...
    my $lang_cookie=$cookies->{lang};
    my $lang=($lang_cookie ? $lang_cookie->value() : undef);

    if ($lang) {
        my %user_pref = split_language_preferences($lang, 2000); # Override
        for (keys %user_pref) {
            $lang{$_} = $user_pref{$_};
        }
    }

    # Find out if somebody specified ?lang=XX on the URL, if so, give it even more weight:
    if ($req->args) {
         my ($lang_arg) = $req->args =~ /.*lang=([^&]+)/;
         
         if ($lang_arg) {
              my %user_pref = split_language_preferences($lang_arg, 4000); # Override
              for (keys %user_pref) {
                   $lang{$_} = $user_pref{$_};
              }
         }
    }

    return \%lang;
}




########################################################################
#
#       Obvius interface methods
#
########################################################################

# obvius_connect - given a request object, strings containing username
#                  and password, array-refs to doctypes, fieldtypes
#                  and fieldspecs returns an obvius-object if a
#                  connection could be made. The object is also put on
#                  notes, key 'obvius'. Returns undef on error.
#
#                  Note that this method is also present in
#                  WebObvius::Site::MultiMason.
sub obvius_connect {
    my ($this, $req, $user, $passwd, $doctypes, $fieldtypes, $fieldspecs) = @_;

    my $obvius = $req->pnotes('obvius');
    return $obvius if ($obvius);
    
    $doctypes   = $this->{OBVIUS_ARGS}->{doctypes};
    $fieldtypes = $this->{OBVIUS_ARGS}->{fieldtypes};
    $fieldspecs = $this->{OBVIUS_ARGS}->{fieldspecs};

    $this->tracer($req, $user||'-user', $passwd||'-passwd') if ($this->{DEBUG});
    
    $obvius = new Obvius($this->{OBVIUS_CONFIG}, $user, $passwd, $doctypes, $fieldtypes, $fieldspecs, log => $this->{LOG});
    return undef unless ($obvius);
    $obvius->param(LANGUAGES=>$this->get_language_preferences($req));

    $obvius->cache(1);
    $req->register_cleanup(sub {
				my $i = 0;
				while ($i < 5 && $obvius->modified) {
				     my $cache = WebObvius::Cache::Cache->new($obvius);
				     my $modified = $obvius->modified;
				     $obvius->clear_modified;
				     $cache->find_and_flush($modified);
				     $i++;
				}
				warn "Error: updated $i times\n" if ($i >= 5);
				$obvius->{DB} = undef;
				
				return 1;
			   });
    $req->pnotes(obvius => $obvius);
    return $obvius;
}

sub obvius_document {
    my ($this, $req, $path) = @_;

    my $obvius = $this->obvius_connect($req);
    return undef unless ($obvius);

    $this->tracer($req, $path||'NULL') if ($this->{DEBUG});

    if (my ($docid) = $path =~ m|^/preview/(\d+)/?$|) {
	 $req->no_cache(1);
	 return Obvius::PreviewDocument->new($obvius, $docid);
    } 
    
    if ($path) { # Specific path lookup
        my $found_doc=$obvius->lookup_document($path);
        return $found_doc;
   }
    return undef;
}

sub obvius_document_version {
    my ($this, $req, $doc) = @_; 

    $this->tracer($req, $doc) if ($this->{DEBUG});

    my $obvius = $this->obvius_connect($req);
    return undef unless ($obvius);

    my $vdoc = $obvius->get_public_version($doc);
    $vdoc ||= $obvius->get_latest_version($doc);
    $req->pnotes(version => $vdoc);

    $obvius->get_version_fields($vdoc) if ($vdoc);

    return $vdoc;
}


########################################################################
#
#       Apache request helpers
#
########################################################################

# Perform a redirect
sub redirect {
    my ($this, $req, $uri, $force_external) = @_;

    $this->tracer($req, $uri, $force_external||'undef') if ($this->{DEBUG});

    if ($uri =~ m!^(=)?/!) {
        if ($1) {
            $uri =~ s/^=//;
            $force_external = 1;
        }

        if ($req->method_number == M_GET and $req->args) {
            if (index($uri, '?') < 0) {
                $uri .= '?' . $req->args;
            } else {
                $uri .= ';' . $req->args;
            }
        }

        if ($force_external) {
            # Jason: Added to detect whether to redirect to https
            my $script_uri = $req->subprocess_env('script_uri');
            my $protocol = ($script_uri =~ /^https/ or $req->subprocess_env('https')) ? 'https' : 'http';
            my $port=$req->get_server_port;
            $uri = sprintf('%s://%s%s', $protocol, $req->hostname,
                           (($port!=80 and $port!=81) ? ':'.$port : '')) . $uri;
        } else {
            $req->internal_redirect($uri);
            return DONE;
        }
    }

    if ($req->method_number == M_POST) {
        $req->method('GET');
        $req->method_number(M_GET);
        $req->headers_in->unset('Content-Length');
    }

    $req->status(REDIRECT);
    $req->headers_out->add(Location => $uri);
    $req->send_http_header;

    return REDIRECT;
}

sub set_expire_header {
    my ($this, $req, %options) = @_;

    my $output=$options{output};
    my $ttl=$options{expire_in} || 15*60; # 15 minutes time to live default

    if ($req->no_cache) {
        my $agent = $req->headers_in->{'User-Agent'};
        # See this address for explanation of the -1
        # http://support.microsoft.com/support/kb/articles/Q234/0/67.ASP
        if ($agent =~ m/[Mm][Ss][Ii][Ee]/) {
            $req->header_out('Expires', -1);
        } else {
            $req->header_out('Expires', Apache::Util::ht_time($req->request_time));
        }
        $req->headers_out->add('Pragma' => 'no-cache');
        $req->header_out('Cache-Control', 'no-cache');

        if (defined $output) {
            $output->param(http_equiv=>[
                                        { name=>'Pragma',
                                          value=>'no-cache',
                                        }
                                       ]);
        }
    } else {
        $req->header_out('Expires', Apache::Util::ht_time($req->request_time + $ttl));

        # If another Cache-Control header was specified, use that one:
        my $cache_control=$req->header_out('Cache-Control');
        unless ($cache_control) {
            $cache_control="max-age=" . $ttl;
            $req->header_out('Cache-Control', $cache_control);
        }

        if (defined $output) {
            $output->param(http_equiv=>[
                                        { name=>'Expires',
                                          value=>Apache::Util::ht_time($req->request_time + $ttl),
                                        },
                                        { name=>'Cache-Control',
                                          value=>$cache_control,
                                        },
                                       ]);
        }
    }
}


########################################################################
#
#       Content Handler
#
########################################################################

sub create_output_object {
    my ($this, $req, $doc, $vdoc, $doctype, $obvius) = @_;

    $this->tracer($req, $doc, $vdoc, $doctype, $obvius) if ($this->{DEBUG});

    die 'Cannot create an output object';
}

sub create_input_object {
    my ($this, $req, %options) = @_;

    my $input=new Obvius::Data;
    my $parms = $req->param;
    foreach (keys %$parms) {
        my @value=$req->param($_);
        $input->param($_=> (scalar(@value)>1 ? \@value : $value[0]));
    }
    $input->param(NOW=>$req->notes('now'));
    $input->param(THE_REQUEST=>$req->the_request);
    $input->param(REMOTE_IP=>$req->connection->remote_ip);
    $input->param(IS_ADMIN => (defined $options{is_admin} ? $options{is_admin} : 0));
    if (my $cookies=Apache::Cookie->fetch) {
        $cookies={ map { $_=>$cookies->{$_}->value } keys %{Apache::Cookie->fetch} };
        $input->param('OBVIUS_COOKIES'=>$cookies);
    }
    $input->param('OBVIUS_HEADERS_IN'=> scalar( $req->headers_in() ));
    if (my $obvius_session_id=$req->param('obvius_session_id')) {
        # Notice that the admin/public-Mason must have released the
        # session for the common-part to grab it here. Symptoms of
        # this not happening is a browser that keeps spinning, the
        # webserver not returning anything.
        warn "The session $obvius_session_id has not been released by admin/public-Mason; WebObvius::Site->create_input_object hangs now!" if ($req->pnotes('obvius_session'));
        my $session=$this->get_session($obvius_session_id, $options{obvius_object});
        $input->param(SESSION=>$session);
    }
    
    my @uploads = $req->upload;
    for(@uploads) {
        if($_->filename ne '' and $_->size!=0 and my $fh=$_->fh) {
            my $data = new Obvius::Data;
            local $/ = undef; # /
            my $value = <$fh>;
            $data->param(filename => $_->filename);
            $data->param(data => $value);
            $data->param(mimetype => $_->type);
            $data->param(size => $_->size);
            if($_->type =~ /^image\//) {
                my ($w, $h)=imgsize(\$value);
                $data->param(width => $w);
                $data->param(height => $h);
            }
            # XXX This naming, _incoming_, is questionable, to say the least:
            $input->param("_incoming_" . $_->name => $data);
        }
    }
    $input->param('OBVIUS_PATH_INFO'=>$req->notes('obvius_path_info')) if (defined $req->notes('obvius_path_info'));

    return $input;
}

# expand_output - given a site, an output object and the request
#                 object, runs the template system and returns a
#                 string of HTML.
#                 Notice that this method must be defined in the
#                 subclasses that implement interfaces to template
#                 systems, if not the one here is run, and dies with
#                 an error.
sub expand_output {
    my ($this, $site, $output, $r) = @_;

    $this->tracer($site, $output) if ($this->{DEBUG});

    die 'Cannot expand output';
}

sub handle_operation {
    my ($this, $input, $output, $doc, $vdoc, $doctype, $obvius) = @_;

    $this->tracer($input, $output, $doc, $vdoc, $doctype, $obvius) if ($this->{DEBUG});

    $output->param("_incoming_$_" => $input->param($_)) for ($input->param);

    return ($doctype->action($input, $output, $doc, $vdoc, $obvius)
            ? OK
            : SERVER_ERROR
           );
}

# Helper for subclasses
sub generate_subsite {
    my $this = shift;

    $this->tracer(@_) if ($this->{DEBUG});

    return $this->generate_page(@_);
}

# $this er evt. en subsite (hvis this != site)
# $site er forældre-siten
sub generate_page {
    my ($this, $site, $req, $doc, $vdoc, $doctype, $obvius, %options) = @_;

    $this->tracer($req, $site, $doc, $vdoc, $doctype, $obvius) if ($this->{DEBUG});

    my $output = $this->create_output_object($req, $doc, $vdoc, $doctype, $obvius);

    my $benchmark = Obvius::Benchmark-> new('site::generate page') if $this-> {BENCHMARK};

    if ($this->{SUBSITE}) {
        print STDERR "GENERATE_PAGE: calling subsite\n" if ($this->{DEBUG});

        my $sdata = $this->{SUBSITE}->generate_subsite($site, $req, $doc, $vdoc, $doctype, $obvius, %options);
        unless (defined $sdata) {
            printf(STDERR scalar localtime(), ": GENERATE_PAGE: subsite FAILED - status %s\n", $req->status);
            return undef;
        }
        printf(STDERR "GENERATE_PAGE: subsite returned - status %s\n", $req->status)
            if ($this->{DEBUG});

        if (ref $sdata) {
            if (ref $sdata eq 'HASH') {
                while (my ($k, $v) = each %$sdata) {
                    $output->param("subsite_$k" => $v);
                }
            } else {
                # XXX what now ????
                # $output->param(subsite => 'Houston, we have a problem!');
                die('generate_subsite() returned malformed output');
            }
        } else {
            $output->param(subsite => $sdata);
        }
    } else {
        print STDERR "GENERATE_PAGE: calling site operation\n"
            if ($this->{DEBUG});

        $benchmark-> lap( "operation " . $doctype->Name) if $benchmark;

        my $input=$this->create_input_object($req, obvius_object => $obvius, %options);
        my $status = $site->handle_operation($input, $output, $doc, $vdoc, $doctype, $obvius);

        my $outgoing_cookies=$output->param('OBVIUS_COOKIES') || {};
        foreach my $k (keys %$outgoing_cookies) {
            # To keep backwards compatibility we do something like this,
            # even though it would have been nicer to keep compatibility
            # with the Apache::Cookie/CGI::Cookie interface (eg. make
            # a session cookie if expires is undef).

            my $expires = $outgoing_cookies->{$k}->{expires} || '+3M';
            $expires = undef if($expires eq 'session');
            my $cookie=new Apache::Cookie($req,
                                          -name => $k,
                                          -value => $outgoing_cookies->{$k}->{value},
                                          -expires => $expires,
                                          -path => '/',
                                         );
            $cookie->bake($req);
        }
        $output->param(OBVIUS_COOKIES => undef); # clear

        $output->param('IS_ADMIN'=>$input->param('IS_ADMIN'));

        # If there was a session on the input object, release it now
        # that the operation, for which $input is input, has run:
        if (my $session=$input->param('SESSION')) {
            $this->release_session($session);
        }

        # If the operation has put data in the output-objects
        # SESSION-param (which does not correspond to a real session),
        # create a session for them to be stored in, release it, and
        # set SESSION_ID, so the id can be used by the template system
        # for making links etc.: See
        #  <http://cvs.magenta-aps.dk/cgi-bin/viewcvs.cgi/mcms/perl/WebMCMS/Site/Site.pm?rev=1.2.2.20&content-type=text/vnd.viewcvs-markup>
        if (my $session_data=$output->param('SESSION')) {
            my $session=$this->get_session(undef, $obvius);
            foreach (keys %$session_data) {
                $session->{$_}=$session_data->{$_};
            }
            $output->param(SESSION_ID=>$session->{_session_id});
            $this->release_session($session);
            $output->param(SESSION=>''); # "clear"
        }

        if (my $redir=$output->param('OBVIUS_REDIRECT')) {
            $this->redirect($req, $redir, 1);
        }

	# Transfer notes and pnotes to the req object
	if(my $notes = $output->param('OBVIUS_NOTES')) {
	    if(ref($notes) eq 'ARRAY') {
		map { $req->notes($_ => 1) } @$notes;
	    } elsif(ref($notes) eq 'HASH') {
		map { $req->notes( $_ => $notes->{$_} ) } keys %$notes;
	    } else {
		$req->notes($notes => 1);
	    }
	}

	if(my $pnotes = $output->param('OBVIUS_PNOTES')) {
	    if(ref($pnotes) eq 'ARRAY') {
		map { $req->pnotes($_ => 1) } @$pnotes;
	    } elsif(ref($pnotes) eq 'HASH') {
		map { $req->pnotes( $_ => $pnotes->{$_} ) } keys %$pnotes;
	    } else {
		$req->pnotes($pnotes => 1);
	    }
	}

        print STDERR "GENERATE_PAGE: calling site operation returned $status\n"
            if ($this->{DEBUG});

        unless ($status == OK) {
            $req->status($status);
            $req->no_cache(1);
            return undef;
        }

        $req->no_cache(1) unless ($doctype->is_cacheable);
        $this->set_expire_header($req, output=>$output);
    }
    print STDERR "GENERATE_PAGE: expanding site outputs\n" if ($this->{DEBUG});

    $benchmark-> lap('output start') if $benchmark;
    return $this->expand_output($site, $output, $req);
}

sub read_request {
    my ($this, $req) = @_;

    $this->tracer($req) if ($this->{DEBUG});

    $req = new Apache::Request($req,
                               POST_MAX => $this->{POST_MAX} || 1,
                               DISABLE_UPLOADS => $this->{DISABLE_UPLOADS} || 0,
                              );

    my $status = $req->parse;
    if ($status != OK) {
        $req->log->error(__PACKAGE__ , '::read_request:',
                         "Request parsing failed: $status (", $req->notes("error-notes"), ")");
        return undef;
    }

    map { print(STDERR "PARM $_ => ", $req->param($_), "\n"); } $req->param
        if ($this->{DEBUG});

    # This should probably go somewhere else but where
    $req->notes(now => strftime('%Y-%m-%d %H:%M:%S', localtime($req->request_time)));
    $req->notes(prefix => $req->dir_config('AddPrefix') || '');

    return $req;
}

sub handler ($$) {
    my ($this, $req) = @_;

    $this->tracer($req) if ($this->{DEBUG});

    my $benchmark = Obvius::Benchmark-> new('site::handler') if $this-> {BENCHMARK};

    my $uri = $req->uri;
    return $this->redirect($req, "$uri/", 'force-external')
        if ($req->method_number == M_GET and $uri !~ /\/$/ and $uri !~ /\./);

    my $obvius = $this->obvius_connect($req);
    return SERVER_ERROR unless ($obvius);

    my $doc = $this->obvius_document($req);
    return NOT_FOUND unless ($doc);

    my $vdoc = $this->obvius_document_version($req, $doc);
    return FORBIDDEN unless ($vdoc);

    my $doctype = $obvius->get_version_type($vdoc);

    if (my $alternate = $doctype->alternate_location($doc, $vdoc, $obvius)) {
        return NOT_FOUND if (Apache->define('NOREDIR'));
        return $this->redirect($req, $alternate, 'force-external');
    }

    $benchmark-> lap( 'raw data') if $benchmark;

    my ($mime_type, $data) = $doctype->raw_document_data($doc, $vdoc, $obvius);

    if ($data) {
        $mime_type ||= 'application/octet-stream';
    } else {
        $req = $this->read_request($req);
        return SERVER_ERROR unless ($req);

        $data = $this->generate_page($this, $req, $doc, $vdoc, $doctype, $obvius);
        return $req->status unless (defined $data);

        if ($this->can("output_filter")) {
            $benchmark-> lap( 'filter start') if $benchmark;
            $this->output_filter($req, \$data);
        }

        $mime_type ||= 'text/html';
    }

    $benchmark-> lap( 'making response') if $benchmark;
    $req->content_type($mime_type);
    $req->set_content_length(length($data));
    $req->send_http_header;

    $benchmark-> lap( 'sending data') if $benchmark;
    # XXX should be \$data
    $req->print($data) unless ($req->header_only);

    return OK;
}


########################################################################
#
#       Session handling
#
########################################################################

sub get_session {
    my ($this, $id, $obvius) = @_;

    my %args = ( TableName => "apache_edit_sessions" );

    if($obvius) {
        $args{Handle} = $obvius->dbh;
        $args{LockHandle} = $obvius->dbh;
    } else {
        # If an obvius object was not provided, create new connections
        my $conf = $this->param('obvius_config');
        $args{DataSource} = $args{LockDataSource} = $conf->param('dsn');
        $args{UserName} = $args{LockUserName} = $conf->param('normal_db_login');
        $args{Password} = $args{LockPassword} = $conf->param('normal_db_passwd');
    }

    my %session;
    eval {
        tie %session, 'Apache::Session::MySQL', $id, \%args;
    };
    if ($@) {
        warn "Can't get session data $id: $@\n\t";
        return undef;
    }

    return \%session;
}

sub release_session {
    my ($this, $session) = @_;

    untie %$session;
}

# Public login:

# The different types of expiration on the cookies:
our %cookie_expire_types = (
                                'session' => '',
                                'timebased' => '+20m',
                                'permanent' => '+3y'
                        );

# get_public_login_expire($login_type) -
# Translates login_type from the public_users table
# to an expire time for a cookie.
# Return the expire time.
sub get_public_login_expire {
    my ($this, $type) = @_;

    $type ||= 'session';

    return $cookie_expire_types{$type};
}

# public_login_cookie($req) -
# Checks for the obvius_public_login cookie and if present
# try to look up a public user from the cookie value. If
# a user is found it is placed on the Obvius object for
# later use.
# Previously refreshed the users cookie with a new value
# for each request, but this behavior was changed since
# it gave problem when the user requested two pages from
# the server at the same time (eg. by clicking a link
# before the current page was done loading).
sub public_login_cookie {
    my ($this, $req, $obvius) = @_;

    my $cookies=Apache::Cookie->fetch || {};
    if(my $cookie = $cookies->{obvius_public_login}) {
        my $users = $obvius->get_public_users({cookie => $cookie->value});
        if($users) {
            my $user = $users->[0];
            $obvius->param('public_user' => $user);
        }
    }
}

# set_public_login_cookie($req, $obvius, $user) -
# Sets the cookie used in public login and updates
# the public_user database with the new cookie value.
sub set_public_login_cookie {
    my ($this, $req, $obvius, $user) = @_;

    # Set a new cookie:
    my $cookie_value = md5_hex($req->request_time . $req->the_request);
    my $expire = $this->get_public_login_expire($user->{login_type});

    my %options=(
                 -name    =>  'obvius_public_login',
                 -value   =>  $cookie_value,
                 -path    =>  '/'
                );
    $options{'-expires'}=$expire if ($expire);
    my $domain=$obvius->config->param('cookiedomain');
    $options{'-domain'}=$domain if ($domain);

    my $cookie = Apache::Cookie->new($req, %options);
    $cookie->bake($req);

    #Update the DB with the new cookie value:
    $obvius->update_public_users({cookie => $cookie_value}, {id=>$user->{id}});
}

# expire_public_login_cookie($req, $obvius)
# Expires (removes) the obvius_public_login cookie. Used
# for logging out public users.
sub expire_public_login_cookie {
    my ($this, $req, $obvius) = @_;

    my %options=(
                 -name    =>  'obvius_public_login',
                 -value   =>  '',
                 -expires =>  '-3M',
                 -path    =>  '/'
                 );
    my $domain=$obvius->config->param('cookiedomain');
    $options{'-domain'}=$domain if ($domain);

    my $cookie = Apache::Cookie->new($req, %options);
    $cookie->bake($req);
}


########################################################################
#
#       Translations
#
########################################################################

sub split_language_preferences {
    my ($lang, $default) = @_;

    my %weights;
    for (split(/\s*,\s*/, $lang)) {
        if (/^(.+);\s*q=(.*)/) {
            $weights{$1} ||= int($2*1000);
        } else {
            $weights{$_} ||= $default || 1000;
        }
    }

    return %weights;
}

# xml files are loaded statically and never reloaded, because it is a costly
# operation to reload in every child apache process, and I cannot see how to
# reload xml in the the server apache process. Once it is figured out, xml files
# can be reverted back to automatic loading.

sub L ($) { utf8( $_[0] || '')-> latin1 } # XML::Parser loves UTF8

# static call
sub load_translation_file
{
        my $filename = shift;

        return if $xml_cache{$filename};

        my $xml = eval {
                XMLin( $filename,
                        keyattr      => {translation=>'lang'},
                );
        };
        if ( $@) {
                warn "Translation file $filename: XML error: $@";
                $xml_cache{$filename} = {};
                return;
        }
        # print STDERR "$filename loaded ok\n"

        my $t = {};
        $xml-> {text} = [ $xml->{text} ] if ref $xml->{text} eq 'HASH';
        for my $item ( @{$xml-> {text}}) {
                next unless $item-> {key};
                my $x = $item-> {translation};
                $t-> { L $item->{key} } = {
                        map {
                                $_ => L $x-> {$_}-> {content}
                        } keys %$x
                };
        }

        $xml_cache{$filename} = $t;
}

# XXX detect inode, if file is a link to avoid loading same file twice
sub normalize_path
{
        my $path = shift;
        $path =~ s[//][/]g;
        $path;
}

# read all files, and record path to these files, for each object instance
# should only be run initially ( see comments about apache server above )
sub load_translation_fileset
{
        my ( $self) = @_;

        $self-> {TRANSLATION_FILESET} = [];

        my $file = TRANSLATION_FILENAME;
        my @path = map { $$_[1] } @{$self-> {COMP_ROOT}};

        for my $suffix ( TRANSLATION_SUFFIXES) {

                my $filename;
                for my $path ( @path) {
                        my $f = normalize_path( "$path/$file$suffix");
                        next unless -f $f;
                        push @{$self-> {TRANSLATION_FILESET}}, $filename = $f;
                        last;
                }
                next if not defined $filename;
                print STDERR "load file: $filename\n" if $self-> {DEBUG};
                load_translation_file( $filename);
        }
}

# resets search path for translation xml files, but only allows
# files that are already loaded, to discourage dynamic xml loading
# ( see comments about apache server above )
sub set_translation_fileset
{
        my ( $self, @path) = @_;

        $self-> {TRANSLATION_FILESET} = [];
        unshift @path, map { $$_[1] } @{$self-> {COMP_ROOT}};

        my $file = TRANSLATION_FILENAME;
        for my $suffix ( TRANSLATION_SUFFIXES) {
                for my $path ( @path) {
                        my $f = normalize_path( "$path/$file$suffix");
                        next unless exists $xml_cache{$f};
                        push @{$self-> {TRANSLATION_FILESET}}, $f;
                        last;
                }
        }

}

sub set_language_preferences
{
        my ( $self, $r, $lang) = @_;

        my %lang;
        if ($lang =~ /^=/) {
                %lang = split_language_preferences(substr($lang, 1));
#               print STDERR "$$ force lang $lang\n";
        } elsif ( $r) {
                my $accept_language = $r->headers_in->{'Accept-Language'};

                if ($accept_language) {
#                       print STDERR "$$ accept lang $accept_language\n";
                        %lang = split_language_preferences( $accept_language);

                        my @vary;
                        push @vary, $r-> header_out('Vary') if $r-> header_out('Vary');
                        push @vary, "Accept-Language";
                        $r-> header_out( 'Vary', join(', ', @vary));
                }

                my %site_pref = split_language_preferences( $lang, 1);
                $lang{$_} ||= $site_pref{$_} for keys %site_pref;
        }


        $self-> {LANGUAGE_PREFERENCES} = [ sort { $lang{$b} <=> $lang{$a} } keys %lang ];
#       print STDERR "$$ lang_pref = ", join(",", @{$self-> {LANGUAGE_PREFERENCES}}), "\n";
}

sub translate
{
        my ( $self, $text, $lang) = @_;
#       print STDERR "$$ $self translates $text\n";
        for (keys %xml_cache) {
            next unless exists $xml_cache{$_}->{$text};
            my $k = $xml_cache{$_}->{$text};

            # For backward compatibility, $lang is accepted as undefined
            # and the user's language->preference will then be found...
            # However, this should be ideally be handled much earlier
            # in the request,so $vdoc->Lang should be passed as the
            # second argument in all new code( third if counting self).
            if (defined $lang) {
                return $k->{$lang} if exists ($k->{$lang});
            } else {

                for ( @{$self-> {LANGUAGE_PREFERENCES}}) {
                    return $k->{$_} if exists $k->{$_};
                }
            }
        }
        warn "Cannot find translation for '$text'\n" if $self->{DEBUG};
        return $text;
}

1;
__END__

=head1 NAME

WebObvius::Site - General site object.

=head1 SYNOPSIS

  use WebObvius::Site;

  $site-> set_language_preferences($r, $language);
  $text = $site-> translate($text);

=head1 DESCRIPTION

Please notice that external redirects performed on port 80 _and_ 81 do
not append the port-number to the redirect-URL.

This is to allow having a bunch of cache/static-serving light-weight Apache's
on port 80, and the mod_perl ones on port 81 - without redirecting people
directly to port 81 (NOTE: Isn't this what ProxyPassReverse is supposed to fix
by itself?).

The least simple one is set_language_preferences() that allows the
administration system to read translations from the XML-files. comp_root is
searched for "translations.xml" and "translations_local.xml" - the resulting
translations are used (and cached on a per language-prefs basis (reading it on
every hit is very time consuming)).

Usually you would have a "translations.xml" in the global mason/admin,
and then you could have an optional "translations_local.xml" in
website/mason/admin.

Overriding the global file is possible by placing a "translations.xml" in the
website dir. (Provided the search-path is searched in the proper direction).

Translations are cached, but never reloaded. Restart apache after editing
translation files.

=head2 SESSIONS

If obvius_session_id has a value in the request, WebObvius::Site
retrieves the session and makes it available on the $input-object as
'SESSION'.

If the output-object has a SESSION-hashref, a session is created with
the contents, and the session id is added to the output-object as
SESSION_ID.

Remember that for Apache::Session to notice that a session has been
updated (and therefore needs to be stored) a first-level key must be
changed. Usually one keeps a timestamp and updates that, to let
Apache::Session know. See the 'Behavior'-section of the documentation
for L<Apache::Session>.

=head1 EXPORT

None by default.


=head1 AUTHORS

Jørgen Ulrik B. Krag E<lt>jubk@magenta-aps.dkE<gt>
Peter Makholm E<lt>pma@fi.dk<gt>
René Seindal
Adam Sjøgren E<lt>asjo@magenta-aps.dk<gt>

=head1 SEE ALSO

L<WebObvius>, L<WebObvius::Site::Mason>, L<Apache::Session>.

=cut
