package Obvius::ToolBase;

use strict;
use warnings;
use utf8;

use Obvius;
use Obvius::Config;

=head1 Obvius::ToolBase

Base module that can be used as a base for tool modules that needs easy
access to an Obvius object.

=cut

sub new {
    my ($class, $obvius_or_config) = @_;

    if(!$obvius_or_config) {
        die "You must specify an Obvius object, an Obvius::Config object or " .
            "an Obvius configname";
    }

    if (!ref($obvius_or_config)) {
        $obvius_or_config = Obvius::Config->new($obvius_or_config);
        if (!$obvius_or_config) {
            die "Could not turn '%s' into an Obvius::Config object";
        }
    }

    my %self;

    my $ref = ref($obvius_or_config);

    if ($ref eq 'Obvius::Config') {
        $self{obvius_config} = $obvius_or_config;
    } elsif(ref($obvius_or_config) eq 'Obvius') {
        $self{obvius} = $obvius_or_config;
        $self{obvius_config} = $self{obvius}->config;
    } else {
        die sprintf(
            "Could not turn '%s' into an Obvius object",
            $obvius_or_config
        );
    }

    return bless(\%self, $class);
}

sub obvius_config { $_[0]->{obvius_config} }
sub obvius {
    my $obvius = $_[0]->{obvius};
    if (!$obvius) {
        $obvius = Obvius->new($_[0]->obvius_config);
        $_[0]->{obvius} = $obvius;
    }
    return $obvius;
}
sub hostmap {
    my $hostmap = $_[0]->{hostmap};
    if(!$hostmap) {
        $hostmap = Obvius::Hostmap->new_with_obvius($_[0]->obvius);
        $_[0]->{hostmap} = $hostmap;
    }
    return $hostmap;
}
sub dbh { shift->obvius->dbh(@_) }

sub _lookup_and_cache {
    my ($self, $key, $lookup_method) = @_;

    if(!exists $self->{$key}) {
        $self->{$key} = $lookup_method->()
    }

    return $self->{$key};
}

=item flush_cache

Flushes cache for any documents that has been registered as changed
on the Obvius object.

=cut
sub flush_cache {
    my ($self) = @_;
    my $obvius = $self->obvius;
    my $cache = WebObvius::Cache::Cache->new($obvius);
    my $modified = $obvius->modified;
    if (defined($modified)) {
        $obvius->clear_modified;
        $cache->find_and_flush($modified);
    }
}

1;
