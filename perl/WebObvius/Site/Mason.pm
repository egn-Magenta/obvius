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

use Apache::Constants qw(:common :methods :response);
use Apache::File;

use HTML::Mason;
use HTML::Mason::ApacheHandler (args_method=>'mod_perl');

use Digest::MD5 qw(md5_hex);

use POSIX qw(strftime);
use Fcntl ':flock';

sub new {
    my ($class, %options) = @_;

    my $new = $class->SUPER::new(%options);

    my $httpd_user = scalar(getpwnam 'www-data');
    my $httpd_group = scalar(getgrnam 'www-data');

    my $basedir=$options{base};
    $new->{parser}=new HTML::Mason::Parser(
					   in_package=>$class,
                       # XXX have both $mcms and $obvius here!
					   allow_globals=>[qw($mcms $obvius $doc $vdoc $doctype $prefix $uri)],
					  );

    my %interp_conf=(
		     parser=>$new->{parser},
		     comp_root=>$options{comp_root},
		     data_dir=>"$basedir/var/$options{site}/",
		     static_file_root=>"$basedir/docs",
		     out_mode=>'batch',
		    );

    if (defined $options{out_method}) {
	$interp_conf{out_method}=$options{out_method};
	$new->param('SITE_SCALAR_REF'=>$options{out_method});
    }
    $new->{interp}=new HTML::Mason::Interp(%interp_conf);

    # If $class ends in ::Common or ::Public, set auto_send_headers to
    # false (we still want headers sent automatically in admin,
    # because less of the handler() is used there (and more is handled
    # in Mason in admin):
    $new->{handler}=new HTML::Mason::ApacheHandler(
						   interp=>$new->{interp},
						   apache_status_title=>'HTML::Mason: ' . $class,
#						   error_mode=> $options{debug} ? 'html' : 'fatal',
						   decline_dirs=>0,
                                                   auto_send_headers=>(scalar($class)=~/::(Common|Public)$/) ? 0 : 1,
						  );

    chown ($httpd_user, $httpd_group, $new->{interp}->files_written);

    $new->{is_admin}=$options{is_admin};

    return bless $new, $class;
}

sub can_use_cache {
    my ($this, $req, $output) = @_;

    $output ||= $req->pnotes('OBVIUS_OUTPUT');

    return '' if ($output && $output->param('OBVIUS_SIDE_EFFECTS'));
    return '' if ($req->no_cache);
    return '' unless ($req->method_number == M_GET);
    return '' unless ($this->{WEBOBVIUS_CACHE_INDEX} and
		      $this->{WEBOBVIUS_CACHE_DIRECTORY});
    return '' if($req->dir_config('WEBOBVIUS_NOCACHE'));

    my $content_type = $req->content_type;
    return '' unless ($content_type =~ s|^([a-zA-Z0-9.-]+/[a-zA-Z0-9.-]+).*|$1|);
                                            # Not really the RFC2045 definition but should work most of the time
    $req->content_type($content_type);

    my $id = md5_hex($req->the_request);
    $id .= '.gz' if ($req->notes('gzipped_output'));

    $req->notes('cache_id' => $id);
    $req->notes('cache_dir' => join '/', $this->{WEBOBVIUS_CACHE_DIRECTORY}, $req->content_type, substr($id, 0, 2));
    $req->notes('cache_file' => $req->notes('cache_dir') .  '/' . $id);
    $req->notes('cache_url' => join '/', '/cache', $req->content_type, substr($id, 0, 2), $id);

    Obvius::log->debug("Cache file name %s\n", $req->notes('cache_file'));
    return 1;
}

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
	if ($dirs[0] eq '') { $dir = '/'; shift @dirs; } else { $dir = '' }
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
        if($qstring and $qstring =~ /^size=\d+x\d+$/) {
            $extra = $qstring;
        }

	if (! -e $this->{WEBOBVIUS_CACHE_INDEX} . "-off") {
	    # Add to cache-db
	    $fh = new Apache::File('>>' . $this->{WEBOBVIUS_CACHE_INDEX});
	    if (open FH, '>>', $this->{WEBOBVIUS_CACHE_INDEX}) {
		if (flock FH, LOCK_EX|LOCK_NB) {
		    print $fh $req->uri, $extra, "\t", $req->notes('cache_url'), "\n";
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
    my ($this) = @_;

    # Not sure if we can get an $obvius-object from here
    Obvius::log->debug("clear_cache: $this");
    return 0 unless ($this->{WEBOBVIUS_CACHE_INDEX});

    WebObvius::Cache::Flushing::immediate_flush($this->{WEBOBVIUS_CACHE_DIRECTORY} . 'flush.db', $this->{WEBOBVIUS_CACHE_INDEX});
}

sub access_handler ($$) {
    my ($this, $req) = @_;

    return OK unless ($req->is_main);

    # We havn't created the $obvius yet. Fall back on Obvius::log()
    #Obvius::log->debug(" Mason::access_handler ($this : " . $req->uri . ")";

    $this->tracer($req) if ($this->{DEBUG});
    $this->add_benchmark($req, 'Access') if ($this->{BENCHMARK});

    my $uri=$req->uri;
    my $remove = $req->dir_config('RemovePrefix');
    $uri =~ s/^\Q$remove\E// if ($remove);
    # We will allow .html (but don't use it if you don't need it) ...
    #$uri =~ s/\.html?$//;
    $req->notes(prefix=>($req->dir_config('AddPrefix') || ''));
    $req->notes(uri=>$uri);
    $req->uri($uri) unless ($req->dir_config('AddPrefix')); # I'm unsure about this... but I'm guessing it's okay to put here.

    return $this->redirect($req, $req->notes('prefix') . $uri . '/', 'force-external')
	if ($uri !~ m!/$! and $uri !~ /[.]/ and !$this->param('is_admin')); # ... and we auto-slash
                                                                            # any uri without .'s in it
                                                                            # except on admin where it's
                                                                            # handled in Mason ...

    return $this->redirect($req, $req->notes('prefix') . $uri , 'force-external') if (!$this->param('is_admin') and ($uri =~ s![.]html/$!.html!i)); # ... and we auto-deslash any uri which ends in .html.

    my $obvius   =$this->obvius_connect($req, $req->notes('user'), undef, $this->{SUBSITE}->{DOCTYPES}, $this->{SUBSITE}->{FIELDTYPES}, $this->{SUBSITE}->{FIELDSPECS});
    return SERVER_ERROR unless ($obvius);
    $req->pnotes('obvius'    =>$obvius);

    # Cache these structures: (they should be dirtied when the db is updated... XXX)
    map { unless ($this->{SUBSITE}->{$_}) { $obvius->log->debug("$this->{SUBSITE}: CACHING $_"); $this->{SUBSITE}->{$_}=$obvius->{$_}} }
	qw(DOCTYPES FIELDTYPES FIELDSPECS);

    my $doc    =$this->obvius_document($req, $uri);
    return NOT_FOUND unless ($doc);

    $req->pnotes('document'=>$doc);
    $req->pnotes('site'    =>$this);

    return OK;
}

sub handler ($$) {
    my ($this, $req) = @_;

    # Does we need to do this before fetching $obvius-object?
    Obvius::log->debug(" Mason::handler ($this : " . $req->uri . ")");

    $this->tracer($req) if ($this->{DEBUG});
    $this->add_benchmark($req, 'Mason h start') if ($this->{BENCHMARK});

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

	if (my $alternate = $doctype->alternate_location($doc, $vdoc, $obvius)) {
	    return NOT_FOUND if (Apache->define('NOREDIR'));
	    return $this->redirect($req, $alternate, 'force-external');
	}

	my ($mime_type, $data, $filename, $con_disp) = $doctype->raw_document_data($doc, $vdoc, $obvius, $req, $output);

	if ($data) {
	    $mime_type ||= 'application/octet-stream';

	    $obvius->log->debug(" Serving raw_document_data from db: $mime_type");

	    $this->set_expire_header($req);
	    $req->content_type($mime_type);
	    if($filename) {
	        $con_disp ||= 'attachment';
	        $req->header_out("Content-Disposition", "$con_disp; filename=$filename");
	    }
	    $req->set_content_length(length($data));
	    $req->send_http_header;

	    $this->add_benchmark($req, 'Sending data') if ($this->{BENCHMARK});
	    # XXX should be \$data
	    $req->print($data) unless ($req->header_only);
	    $this->add_benchmark($req, 'Data sent') if ($this->{BENCHMARK});

            # Add to cache:
            if ($this->can_use_cache($req,$output)) {
	        # $this->add_benchmark($req, 'Cache save') if ($this->{BENCHMARK});
	        $this->save_in_cache($req, \$data);
	    }
            else {
	        $obvius->log->debug(" NOT ADDED TO CACHE: " . $req->notes('uri'));
	    }

	    $this->report_benchmarks($req, \*STDERR) if ($this->{BENCHMARK});

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

    my $status = $this->{handler}->handle_request($req);
    if (defined $this->{'SITE_SCALAR_REF'}) {
	my $html="Couldn't generate page. Yikes.";
	if ($status==OK) {
	    $html=${$this->{'SITE_SCALAR_REF'}};
        }
        ${$this->{'SITE_SCALAR_REF'}}='';

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

        $req->print(\$html) unless ($req->header_only or $status!=OK);

        # Add to cache:
        if ($this->can_use_cache($req) and $status==OK) {
	    #$this->add_benchmark($req, 'Cache save') if ($this->{BENCHMARK});
	    $this->save_in_cache($req, \$html);
	}
        else {
	    $obvius->log->debug(" NOT ADDED TO CACHE: " . $req->notes('uri'));
	}

    }

    $this->add_benchmark($req, 'Mason h end') if ($this->{BENCHMARK});
    $this->report_benchmarks($req, \*STDERR) if ($this->{BENCHMARK});
    print STDERR "\n" if ($this->{BENCHMARK});
    return $status;
}

sub authen_handler ($$) {
    my ($this, $req) = @_;

    Obvius::log->debug(" Mason::authen_handler ($this : " . $req->uri . ")");

    $this->add_benchmark($req, 'Authen') if ($this->{BENCHMARK});

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
    my $obvius   =$this->obvius_connect($req, $login, $pw, $this->{SUBSITE}->{DOCTYPES}, $this->{SUBSITE}->{FIELDTYPES}, $this->{SUBSITE}->{FIELDSPECS});
    unless ($obvius) {
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

    # XXX Hvordan pokker håndteres dette? XXX
    # Måske kan HTML::Mason::Interp out_method hjælpe?
    # Måske lidt a la dette:

    $req->notes('is_admin'=>$output->param('IS_ADMIN')) if ($output->param('IS_ADMIN'));
    $req->filename($this->{interp}->{comp_root}->[0]->[1] . "/switch");
    $req->pnotes('OBVIUS_OUTPUT'=>$output);

    my $status = $this->{handler}->handle_request($req);

    my $s='We have an anomaly, the subsite centerpiece was unable to generate.';
    # Ou wee, handle this better (subsite_scalar_ref must be emptied for each request):
    if ($status==OK) {
	$s=${$this->{'SITE_SCALAR_REF'}};
    }
    ${$this->{'SITE_SCALAR_REF'}}='';

    $this->add_benchmark($req, 'expand o end') if ($this->{BENCHMARK});
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

=head1 AUTHOR

Jørgen Ulrik B. Krag <jubk@magenta-aps.dk>
Peter Makholm <pma@fi.dk>
René Seindal
Adam Sjøgren <asjo@magenta-aps.dk>

=head1 SEE ALSO

L<WebObvius::Site>, L<Obvius>.

=cut
