use strict;
use warnings;

package WebObvius::Rewriter::ObviusRules::StaticDocs;
use WebObvius::Rewriter::RewriteRule qw(LAST);
our @ISA = qw(WebObvius::Rewriter::RewriteRule);

sub setup {
    my ($this, $rewriter) = @_;

    my $docs_dir = $rewriter->{config}->param('docs_dir');
    die "No docs_dir specified in the config file" unless($docs_dir);

    $docs_dir =~ s!/$!!;
    $this->{docs_dir} = $docs_dir;
}

sub rewrite {
    my ($this, %args) = @_;

    return undef if($args{uri} eq '/');
    
    my $full_path = $this->{docs_dir} . $args{uri};
    
    return (LAST, '-') if(-f $full_path or -d $full_path);
    
    return undef;
}

1;

package WebObvius::Rewriter::ObviusRules::LowerCaser;
use WebObvius::Rewriter::RewriteRule qw(REWRITE);
our @ISA = qw(WebObvius::Rewriter::RewriteRule);

sub rewrite {
    my ($this, %args) = @_;

    return (REWRITE, lc($args{uri}));    
}

1;

package WebObvius::Rewriter::ObviusRules::Navigator;
use WebObvius::Rewriter::RewriteRule qw(PROXY);
our @ISA = qw(WebObvius::Rewriter::RewriteRule);

sub setup {
    my ($this, $rewriter) = @_;
    
    my $config = $rewriter->{config};
    
    $this->{navigator_url} = $config->param('navigator_url');

    die ("Trying to use rewriterule for navigator, but no navigator url specified in config") unless($this->{navigator_url});
    
    $this->{port} = $config->param('navigator_port') || 5000;
    $this->{number_of_servers} = $config->param('navigator_servers') || 3;
    $this->{navigator_server} = $config->param('navigator_server') || 'localhost';
    
    $this->{additional_port} = 0;
}

sub rewrite {
    my ($this, %args) = @_;
    
    return undef unless($args{is_front_server});
    
    my $nav_url = $this->{navigator_url};
    
    if($args{uri} =~ m!^$nav_url(.*)!) {
        $this->{additional_port} += 1;
        $this->{additional_port} %= $this->{number_of_servers};
        my $real_port = $this->{port} + $this->{additional_port};
        my $url = "http://" . $this->{navigator_server} . ":$real_port/$1";
        
        return (PROXY, $url);
    }
    
    return undef;
}

#package WebObvius::Rewriter::ObviusRules::Dispatch;
#use WebObvius::Rewriter::RewriteRule qw(PASSTHROUGH);
#our @ISA = qw(WebObvius::Rewriter::RewriteRule);
#
#sub rewrite {
#    my ($this, %args) = @_;
#    
#    return undef if($args{uri} =~ m!^/cache/!);
#    return (PASSTHROUGH, '-') if($args{uri} =~ m!^/(admin|public|soap|rest|system)/!);
#    return (PASSTHROUGH, "/public/$1") if($args{uri} =~ m!^/(.*)!);
#
#    return undef;    
#}
#
#1;

package WebObvius::Rewriter::ObviusRules::SubSites;

use Obvius::Hostmap;
use WebObvius::Rewriter::RewriteRule qw(REDIRECT REWRITE);

our @ISA = qw(WebObvius::Rewriter::RewriteRule);

sub setup {
    my ($this, $rewriter) = @_;
    
    my $config = $rewriter->{config};
    
    $this->{roothost} = $config->param('roothost');
    die "Trying to use subsite rewrites on a site with no roothost" unless($this->{roothost});
    
    my $map_file = $config->param('hostmap_file');
    die "No 'hostmap_file' defined in config: Can't rewrite subsites" unless($map_file);

    $this->{hostmap} = Obvius::Hostmap->create_hostmap( $map_file, $this->{roothost}, debug => 1 );
}

sub hostmap {
    return shift->{hostmap};
}

sub rewrite {
    my ($this, %args) = @_;
    
    use Data::Dumper;
    print STDERR Dumper(\%args);
    
    return undef unless($args{is_front_server});
    
    my $roothost = $this->{roothost};
    my $hostname = lc($args{hostname}) || '';
    
    #Make sure hostmap is correctly loaded:
    $this->hostmap->get_hostmap;
    
    my $subsite_uri = $this->hostmap->host_to_uri($args{hostname}) || '';
    my $protocol = ($args{https} || '') eq 'on' ? 'https' : 'http';
    
    # Stage one: Redirect admin requests on any host to the proper URI on
    # the roothost:    
    if($args{uri} =~ m!^/admin/(.*)!) {
        # If already on the root we don't need any more subsite rewriting
        return undef if($hostname eq $roothost);
        
        if($subsite_uri) {
            return (REDIRECT, "$protocol://$roothost/admin$subsite_uri$1");
        } else {
            return (REDIRECT, "$protocol://$roothost/admin$1");
        }
    }

    # Skip system URLs
    return undef if($args{uri} =~ m!^/system/!);
    
    # Store original URI for later use
    my $orig_uri = $args{uri};

    my $rewritten = 0;
    
    # Rewrite according to found subsite:
    if($subsite_uri) {
        $args{uri} =~ s!^/!!;
        $args{uri} = "$subsite_uri$args{uri}";
        $rewritten = 1;
    }
    
    # Now, redirect to the correct hostname if we're not already on it:
    my ($new_uri, $new_host, $subsiteuri) = $this->hostmap->translate_uri($args{uri}, $hostname);
    
    # TODO: Handle SSL redirects here? Or maybe in Obvius::Hostmap?
    return (REDIRECT, $new_uri) if($new_host and $new_host ne $hostname);

    if($rewritten) {
        return (REWRITE, $args{uri});
    } else {
        return undef;    
    }
}

1;

package WebObvius::Rewriter::ObviusRules::Cache;

use Fcntl qw( LOCK_EX O_RDONLY O_CREAT );
use WebObvius::Rewriter::RewriteRule qw(REWRITE);

use SDBM_File;

our @ISA = qw(WebObvius::Rewriter::RewriteRule);

sub setup {
    my ($this, $rewriter) = @_;
    
    my $config = $rewriter->{config};
    
    $this->{cache_file} = $config->param('cache_db');
    die "No cache_db specified in the config file" unless($this->{cache_file});
    
    
    $this->{debug} = $rewriter->{debug};
}

sub rewrite {
    my ($this, %args) = @_;
    $args{query_string} ||= '';
    
    return undef if($args{uri} =~ m!^/admin!);
    return undef unless($args{method} =~ m!^(GET|HEAD)$!);
    print STDERR "$args{method} method OK\n" if($this->{debug});
    return undef unless($args{query_string} =~ m!^(size=[0123456789]+x[0123456789]+|)$!);
    print STDERR "query_string '$args{query_string}' OK\n" if($this->{debug});

    my %cache;
    tie (%cache, 'SDBM_File', $this->{cache_file}, O_RDONLY|O_CREAT, 0666);
    my $cached = $cache{$args{uri} . $args{query_string}};
    untie %cache;

    if($cached) {
        print STDERR "Found cached URI: $cached\n" if($this->{debug});
        return (REWRITE, $cached);
    }

    return undef;    
}

1;
