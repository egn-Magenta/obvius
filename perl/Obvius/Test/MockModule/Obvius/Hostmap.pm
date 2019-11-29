package Obvius::Test::MockModule::Obvius::Hostmap;

use strict;
use warnings;
use utf8;

use base 'Obvius::Test::MockModule';

sub mockclass { "Obvius::Hostmap" }

sub new_with_obvius {
    my ($class, $obvius) = @_;

    my $hostmap = {
        roothost => $obvius->config->param("roothost"),
        hostmap => {},
        forwardmap => {},
        non_https_hosts => {},
        regexp => '',
        is_https => {},
        obvius_config => $obvius->config,
        always_https_mode => 1
    };

    foreach my $subsite ($obvius->get_all_subsites) {
        if(my $domain = $subsite->{domain}) {
            if(my $doc = $obvius->get_doc_by_id($subsite->{root_docid})) {
                my $path = $obvius->get_doc_uri($doc);
                $hostmap->{hostmap}->{lc($path)} = $domain;
                $hostmap->{forwardmap}->{lc($domain)} = $path;
            }
        }
    }

    my $siteroot_map = $hostmap->{hostmap};
    $hostmap->{regexp} = "^(" . join("|", reverse sort keys %$siteroot_map) . ")";

    return bless($hostmap, $class);

}


# Make update_non_https_map a noop
sub get_hostmap { return $_[0]->{hostmap} }


1;