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

use Data::Dumper;
use WebObvius::Site;

our @ISA = qw( WebObvius::Site );
our $VERSION="1.0";

use WebObvius::Template::MCMS;
use WebObvius::Template::Provider;

#use WebObvius::Cache::Flushing;
use WebObvius::Cache::Cache;
use WebObvius::RequestTools;
use Encode;

use WebObvius::Apache
  Constants       => qw(:common :methods :response),
  File            => ''
  ;

use Digest::MD5 qw(md5_hex);

use HTML::Mason;
# Support Mason before version 1.10 and after simultaneously:
my $new_mason;
BEGIN {
     # The way to specify args_method was changed from version 1.10 and onwards:
     if ($HTML::Mason::VERSION < 1.10) {
          eval "use HTML::Mason::ApacheHandler (args_method=>'mod_perl');";
          $new_mason=0;
     } else {
          eval "use HTML::Mason::ApacheHandler;";
          $new_mason=1;
     }
}

use Digest::MD5 qw(md5_hex);

use POSIX qw(strftime);
use Fcntl ':flock';


########################################################################
#
#       Construction
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
                       );

     if ($new_mason) {
          $interp_conf{autoflush}        = 0;
          $interp_conf{data_cache_api}   = '1.0'; # XXX This won't be supported by Mason forever, but
          # we need it for compability with the old admin.
          $interp_conf{preamble}         =
            "my \$benchmark = Obvius::Benchmark->new( __FILE__) if \$obvius->{BENCHMARK};\n";
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
                                  apache_status_title   => 'HTML::Mason: ' . $class,
                                  error_mode            => 'fatal',
                                  error_format          => 'line',
                                  decline_dirs          => 0,
                                  auto_send_headers     => (scalar ($class) =~ /::(Common|Public)$/) ? 0 : 1,
                                 );

     if ($new_mason) {
          %apachehandler_options = ( %apachehandler_options, %interp_conf);
          $apachehandler_options{allow_globals} = [
                                                   qw($mcms $obvius $doc $vdoc $doctype $prefix $uri)
                                                  ];
          $apachehandler_options{args_method}   = 'mod_perl';
     } else {
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
#       Handlers
#
########################################################################

sub access_handler ($$) {
     my ($this, $req) = @_;

     return OK unless ($req->is_main);

     my $benchmark = Obvius::Benchmark-> new('mason::access') if $this-> {BENCHMARK};

     my $uri=$req->uri;
     my $remove = $req->dir_config('RemovePrefix');
     
     $uri =~ s/^\Q$remove\E// if ($remove);
     
     $req->notes(prefix=>($req->dir_config('AddPrefix') || ''));
     $req->notes(uri=>$uri);
     $req->uri($uri) unless ($req->dir_config('AddPrefix'));

     my $orig_uri = $uri;

     my $obvius   = $this->obvius_connect($req, undef, undef,
                                          $this->{SUBSITE}->{DOCTYPES},
                                          $this->{SUBSITE}->{FIELDTYPES},
                                          $this->{SUBSITE}->{FIELDSPECS});
                                          
                                          
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

sub shave_of_tails {
     my ($uri) = @_;
     
     my @parts = split '/', $uri;
     my $cur = '/';
     my @uris = ('/');
     
     for my $part (@parts) {
          next if ($part eq "" || ! defined $part);
          $cur .= $part . '/';
          push @uris, $cur;
     }
     
     return \@uris;
}

sub convert_ip_to_number {
     my ($ip) = @_;
     my ($p1, $p2, $p3, $p4, $subnet) = ($ip =~ m!^\s*(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})(?:\/(\d{1,2}))?\s*$!);
     
     if ($p1) {
          return ($p1 * (1 << 24) + $p2 * (1 << 16) + $p3 * (1 << 8) + $p4, $subnet);
     } else {
          return undef;
     }
}

sub check_ip {
     my ($rules, $r) = @_;

     my $ip = get_origin_ip_from_request($r);
     return 0 if !$ip;

     my ($ipn) = convert_ip_to_number($ip);
     return 0 if (!$ipn);

     for my $rule (@$rules) {
          my ($num, $significance) = convert_ip_to_number($rule);
          my $subnet = 0;
          next if !$num;
          
          if (!defined $significance) {
               $significance = 32;
               my $bits = 255;
               while ($bits ) {
                    last if ($bits & $num);
                    $bits <<= 8;
                    $significance -= 8;
               }
          }

          for (my $i = 31; $i >= (32 - $significance); $i--) {
               $subnet += 1 << $i;
          }

          return 1 if (($ipn & $subnet) == ($num & $subnet));
     }

     return 0;
}

sub public_authen_handler {
     my ($this, $req) = @_;
     
     return OK if !$req->is_main;
     
     my $obvius = $this-> obvius_connect($req, undef, undef, 
                                         $this->{SUBSITE}->{DOCTYPES},
                                         $this->{SUBSITE}->{FIELDTYPES},
                                         $this->{SUBSITE}->{FIELDSPECS});
     
     return SERVER_ERROR if !$obvius;
     
     my $uri = $req->notes('uri');
     $uri = "/" . $uri . "/";
     $uri =~ s!/+!/!g;
     
     my $uris = shave_of_tails($uri);

     if (!@$uris) {
          warn "NO URI: $uri\n";
          return SERVER_ERROR;
     }
     my $params = join ',', (('?') x @$uris);
     
     my $forbidden = $obvius->execute_select(
              "select docid from docid_path dp join forbidden_docs using (docid) where
               dp.path in ($params) order by dp.path desc limit 1", @$uris);
     return OK if !@$forbidden;

     my $docid = $forbidden->[0]{docid};
     
     $req->notes(nocache =>  1);
     $req->notes(OBVIUS_SIDE_EFFECTS =>  1 );
     $req->no_cache(1);          
          
     my $allowed_ips = $obvius->execute_select("select ip from forbidden_docs_ips 
                                                     where docid=?", $docid);
     my @ips = grep { $_ } map { $_->{ip} } @$allowed_ips;
     return OK if check_ip(\@ips, $req);

     my $res = $this->session_authen_handler($req);
     return $res if ($res ne OK); 
     
     return OK if $obvius->is_admin;
     
     my $users = $obvius->execute_select("select user from forbidden_docs_users 
                                          where docid=?", $docid);
     
     my $cur_user = $obvius->get_user($obvius->{USER});
     for my $user (@$users) {
          return OK if $user->{user} == $cur_user->{id};
     }

     my $groups = $obvius->execute_select("select grp from forbidden_docs_groups 
                                                 where docid = ?", $docid);

     my %user_groups;
     my $user_groups = $obvius->{USER_GROUPS}{$cur_user->{id}};
     if ($user_groups) {
          $user_groups{$_->{grp}} = 1 for (@$user_groups);
     }

     for my $grp (@$groups) {
          return OK if $user_groups{$grp->{grp}};
     }

     # If no specific access-choices have been made, allow everybody that is logged in. 
     return !@$groups && !@$users && !@ips ? OK : FORBIDDEN;
}
     
# handler - Handles incoming Apache requests when using Mason as template system.
sub handler ($$) {
     my ($this, $req) = @_;

     my $obvius = $this->obvius_connect($req);
     $req->no_cache(1) if $obvius->{OBVIUS_CONFIG}{CACHE_OFF};     
     
     my $is_admin = $this->param('is_admin');
     $req->notes(is_admin => $is_admin);
     
     $this->tracer($req) if ($this->{DEBUG});
     my $benchmark = Obvius::Benchmark-> new('mason::handler') if $this-> {BENCHMARK};
     
     $req->notes(now => strftime('%Y-%m-%d %H:%M:%S', localtime($req->request_time)));

     my $doc=$req->pnotes('document');
     return NOT_FOUND if (!$obvius->is_public_document($doc) && !$is_admin);
     my $vdoc = $this->obvius_document_version($req, $doc);
     
     return NOT_FOUND unless ($vdoc);
     
     return FORBIDDEN if (!$is_admin && ($vdoc->Expires lt $req->notes('now')));
     return FORBIDDEN if ($is_admin && !$obvius->can_view_document($doc));
     
     my $doctype = $obvius->get_version_type($vdoc);
     
     my $output = $this->create_output_object($req,$doc,$vdoc,$doctype,$obvius);
     
     # The document can have a "alternate_location" method if the user
     # should be redirected to a different URL.
     # The method should return a path or URL to the new location.
     my $alternate;
     $alternate = $doctype->alternate_location($doc, $vdoc, $obvius, $req->uri) if (!$is_admin);
     if($alternate) {
          return NOT_FOUND if (Apache->define('NOREDIR'));
          return $this->redirect($req, $alternate, 'force-external');
     }
     # For collecting newsletter statistics:
     my $collect_newsletter_stats = ($obvius->config->param('newsletter_collect_stats') || 0);
     if ($collect_newsletter_stats) {
	 eval { 
	     require KU::Newsletter::Stats;
	     KU::Newsletter::Stats::click(WebObvius::Apache::apache_module('Request')-> new($req));
	 };
	 if ($@) {
	     warn $@;
	 }
     }
     
     # Documents returning data which shouldnt be handled by the portal 
     # (eg. a download document), but directly
     # by the browser should have a method called "raw_document_data"
     # Please also note that a slash at the end of an uri in admin signifies
     # that we are getting the *raw* resource, not the obvius-wrapper (where that is appropriate)
     #
     # Now extended to also include the "internal_redirect" method which makes
     # it possible to serve a static file already present beneath the document
     # root.
     if (!$is_admin || $req->uri !~ m|/$|) {
          my $upgraded_req = WebObvius::Apache::apache_module('Request')-> new($req);
          
          # Check if we should just serve data using an internal redirect:
          my $other_path = $doctype->internal_redirect($doc, $vdoc, $obvius, $upgraded_req, $output);
          if($other_path) {
               $upgraded_req->internal_redirect($other_path);
               return OK;
          }
          
	  my ($mime_type, $data, $filename, $con_disp, $path, $extra_headers) = 
	    $doctype->raw_document_data($doc, $vdoc, $obvius, $upgraded_req, $output);

	  if ($data || $path) {
	       my %args = (mime_type => $mime_type, 
			   data => $data, 
			   output_filename => $filename, 
			   con_disp => $con_disp,
			   path => $path);
               if ($extra_headers){
                    $req->header_out($_ => $extra_headers->{$_}) for keys %$extra_headers;
               }
	       my $status = defined $data ? 
		 $this->output_data($req, %args) : 
		 $this->output_file($req, %args);

	       $req->no_cache(1) if ($is_admin);
	       execute_cache($obvius, $req, $data, $filename) if ($status == OK);
               
	       return $status;
	  }
     }
     
     if ($output->param("redirect")) {
	 return $this->redirect($req, $output->param("redirect"), 'force-external');
     }
     
     $req->content_type('text/html') unless $req->content_type;
     $req->content_type('text/html') if $req->content_type =~ /directory$/;
     if ($req->content_type ne 'text/html') {
          execute_cache($obvius, $req);
          return -1;
     }
     
     $obvius->log->debug("  Mason on " . $req->document_root . $req->notes('prefix') . "/dhandler");
     $req->filename($req->document_root . $req->notes('prefix') . "/dhandler"); # default handler
     
     my $status=$this->execute_mason($req);
     my $html;
     if (defined $this->{'SITE_SCALAR_REF'}) {
          # This, out_method, is not used in admin; only for public.
          $html = ${$this->{'SITE_SCALAR_REF'}} if ($status == OK);
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
     }

     execute_cache($obvius, $req, \$html);

     return $status;
}

sub execute_cache {     
     my ($obvius, $req, $data, $filename ) = @_;
     
     my $cache = WebObvius::Cache::Cache->new($obvius);
     if ($data) {
          my $new_data = ref $data ? $data : \$data;
          $cache->save_request_result_in_cache($req, $new_data, $filename);
     }
     $cache->quick_flush($obvius->modified) if ($obvius->modified);
}    

sub execute_mason {
     my ($this, $req)=@_;

     return $this->{handler}->handle_request($req);
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
     my $obvius = $this->obvius_connect($req, $login, $pw, 
                                        $this->{SUBSITE}->{DOCTYPES}, 
                                        $this->{SUBSITE}->{FIELDTYPES}, 
                                        $this->{SUBSITE}->{FIELDSPECS});
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

sub already_logged_in {
     my ($this, $obvius, $req) = @_;
     
     my $session_id;
     my %cookies = Apache::Cookie->fetch;
     $session_id = $cookies{obvius_login_session}->value if($cookies{obvius_login_session});
     
     return 0 if not $session_id;

     my $session_timeout = ($obvius->config->param('login_session_timeout') || 30) * 60;
     my $session_result = $obvius->execute_select("select login, UNIX_TIMESTAMP() as now, 
                                                   last_access from login_sessions where 
                                                   session_id=?", $session_id);
     my $res = $session_result->[0];
     return 0 if not $res;
     $obvius->{USER} = $res->{login};
     $obvius->read_user_and_group_info;
     
     $req->notes(user => $res->{login});

     # If more than a minute has passed since last login update the 
     # timestamp in the database as well:
     $obvius->execute_transaction("UPDATE login_sessions SET last_access=UNIX_TIMESTAMP() 
                                   where session_id=?", $session_id) 
       if($res->{now} - $res->{last_access} > 60);
     
     return 1;
}

     
sub session_authen_handler ($$) {
    my ($this, $req) = @_;

    return OK if not $req->is_initial_req;
    my $benchmark = Obvius::Benchmark-> new('mason::session_authen_handler') 
      if $this-> {BENCHMARK};

    my $obvius = $this->obvius_connect($req, 
                                       undef, 
                                       undef, 
                                       $this->{SUBSITE}->{DOCTYPES}, 
                                       $this->{SUBSITE}->{FIELDTYPES}, 
                                       $this->{SUBSITE}->{FIELDSPECS});

    return SERVER_ERROR if not $obvius;

    return OK if $this->already_logged_in($obvius, $req);
    
    my $r = WebObvius::Apache::apache_module('Request')-> new($req);

    my $login = $r->param('obvius_sessionlogin_login');
    my $password = $r->param('obvius_sessionlogin_password');
    my $secret = $r->param('obvius_sessionlogin_secret') || '';

    goto redirect if 
      !$r->param('obvius_sessionlogin_submit');
    goto login_failed if !$password || !$login;

    my $userdata = $obvius->{USERS}->{$login};
    goto redirect if not $userdata;
    
    my $hash = md5_hex($login . $userdata->{passwd} . $secret);
    
    if ($hash ne $password) {
         $obvius->{USER} = $login;
         $obvius->{PASSWORD} = $password;
         goto login_failed if not $obvius->validate_user;
         $this->register_session($obvius, $r, $login);
         return OK;
    } 
    
    $this->register_session($obvius, $r, $login);
    
    return OK;

  login_failed:
    $req->notes(login_failed => 1);

  redirect:
    return $this->redirect($r, '/system/login');
}

sub register_session {
     my ($this, $obvius, $req, $login) = @_;
     my $benchmark = Obvius::Benchmark-> new('mason::register_session') if $this-> {BENCHMARK};
     
     my $remember_me = !!$req->param('obvius_sessionlogin_remember_me');
     my $try_n_times = 10;
     my $session_id;
     do {
	  $session_id = md5_hex(time . rand);
	  
	  eval {
               $obvius->execute_command("insert into login_sessions
                                           (login, session_id, last_access, permanent) values
                                           (?, ?, UNIX_TIMESTAMP(), ?)", 
                                           $login, $session_id, $remember_me
                                       );
               };
     } while ($try_n_times-- and $@);
 
     die "Can't create session, maybe because of: $@" if $@;
     
     my $expires = $remember_me ? "Expires=Fri, 21-Nov-2036 06:00:00 GMT" : '';
     $req->headers_out->add("Set-Cookie", 
                            "obvius_login_session=$session_id; path=/;${expires};  HttpOnly");
     $req->notes(user => $login);
     $obvius->{USER} = $login;

     return $session_id;
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
                                      $login = 'nobody', 
                                      undef,
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

     if ( $uid-> {can_manage_users} < 2) {
          $caps = $obvius-> compute_user_capabilities( $doc, $uid->{id});
          goto AUTH_FAIL unless $caps->{view};
     }

     # finally, turn server cache off for the protected documents
     $req-> notes(nocache => 1);
     $req-> notes(OBVIUS_SIDE_EFFECTS => 1 );
     $req->no_cache(1);

     return OK;

   AUTH_FAIL:
     $req-> note_basic_auth_failure;
     return AUTH_REQUIRED;
}


#######################################################################
#
#       Public handling functions
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

sub set_mime_type_and_content_disposition {
     my ($this, $req, %options) = @_;
     
     my $mime_type = $options{mime_type} || 'application/octet-stream';
     
     $req->content_type($mime_type);
     $this->set_expire_header($req, expire_in=>30*24*60*60); # 1 month
     
     my @con_disps;
     push @con_disps, $options{con_disp} if $options{con_disp};
     push @con_disps,  "filename=$options{output_filename}" if $options{output_filename};
     
     if (@con_disps) {
          my $con_disp_header = join '; ', @con_disps;
          $req->header_out('Content-Disposition', $con_disp_header);
     }

     # Microsoft Internet Explorer/Adobe Reader has
     # problems if Vary is set at the same time as
     # Content-Disposition is(!) - so we unset Vary if we
     # set Content-Disposition.
     $req->header_out('Vary'=>undef);
}

sub output_data {
     my ($this, $req, %options) = @_;
     
     my $con_disp = $options{con_disp};
     my $new_data = $options{data};
     
     my $data_ref = ref $new_data ? $new_data : \$new_data;
     if ( Encode::is_utf8($$data_ref)) {
        Encode::_utf8_off($$data_ref);
     }
     $this->set_mime_type_and_content_disposition($req, %options);

     $req->no_cache(0);

     # The spec. says that it is not necessary to advertise this:
     # $req->header_out('Accept-Ranges'=>'bytes');
     
     # Handle Range: N-M
     my $range=$req->headers_in->{Range};
     
     my $len = length($$data_ref);
     
     if (defined $range and $range=~/^bytes=(\d*)[-](\d*)$/) {
          my ($start, $stop)=($1 || 0, $2 || $len);
          
          # Sanity check range:
          if ($start>$len or $stop>$len or $start>$stop) {
               $req->header_out('Content-Range'=>'0-0/' . $len);
               $req->status(416); # "Requested range not satisfiable"
               $req->send_http_header;
               return OK;
          }
          
          $req->header_out('Content-Range'=>'bytes ' . $start . '-' . $stop . '/' . $len);
          $req->set_content_length($stop-$start);
          $req->status(206); # "Partial content"
          $req->send_http_header;
          $req->print(substr($$data_ref, $start, $stop-$start));
	  $req->rflush;
     } else {
          $req->set_content_length($len);
          $req->send_http_header;
          my $p = $req->print($$data_ref) unless ($req->header_only);
	  $req->rflush;
     }

     return OK;
}

sub output_file {
     my ($this, $req, %options) = @_;
     $this->set_mime_type_and_content_disposition($req, %options);
     
     my $path = $options{path};
     
     my @file_stats = stat($path);
     die "Couldn't find file" if not @file_stats;
     my $size = $file_stats[7];

     my $range=$req->headers_in->{Range};
     if (defined $range and $range=~/^bytes=(\d*)[-](\d*)$/) {
          my ($start, $stop)=($1 || 0, $2 || $size);
          
          # Sanity check range:
          if ($start >= $stop || $stop > $size ) {
               $req->header_out('Content-Range'=>'0-0/' . $size);
               $req->status(416); # "Requested range not satisfiable"
               $req->send_http_header;
               return OK;
          }
               
          $req->header_out('Content-Range'=>'bytes ' . $start . '-' . $stop . '/' . $size);
          $req->set_content_length($stop-$start);
          $req->status(206); # "Partial content"
          $req->send_http_header;
          $req->sendfile($path, $start, $stop - $start);
          return OK;
     } 
     
     $req->set_content_length($size);
     $req->send_http_header;
     $req->sendfile($path) unless ($req->header_only);
     return OK;

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
