package Obvius::DocumentUtils;
use strict;
use warnings;

use Obvius;
use Obvius::Hostmap;
use Obvius::Config;
use Obvius::Log;
use POSIX qw(strftime);

=head1 OBJECT-ORIENTED METHODS

=head2 new

  my $document_utils = Obvius::DocumentUtils->new(
    $obvius_or_config_or_configname
  );

The argument to the new method can be either an instance of L<Obvius>,
an instance of L<Obvius::Config> or a string with the name of an L<Obvius>
configuration.

=cut

sub new {
    my ($classname, $obvius_or_confname, %args) = @_;

    die "You must provide an obvius object or a configuration name as the " .
        "first argument" unless($obvius_or_confname);
    my $self = {
        %args
    };
    my $oref = ref($obvius_or_confname) || '';
    if(!$oref) {
        $self->{_confname} = $obvius_or_confname;
    } elsif($oref eq 'Obvius::Config') {
        $self->{_obvius_config} = $obvius_or_confname;
    } elsif($oref eq 'Obvius') {
        $self->{_obvius} = $obvius_or_confname;
        $self->{_obvius_config} = $self->{_obvius}->config;
    } else {
        die "Don't know how to handle first argument of type $oref";
    }

    my $new = bless($self, $classname);

    return $new;
}

=head2 obvius_config

  my $obvius_config = $document_utils->obvius_config;

returns the associated L<Obvius::Config> object.

=cut

#@returns Obvius::Config
sub obvius_config {
    my ($self) = @_;
    my $config = $self->{_obvius_config};
    unless($config) {
        $config = Obvius::Config->new($self->{_confname});
        $self->{_obvius_config} = $config;
    }
    return $config;
}


=head2 obvius

  my $obvius = $document_utils->obvius;

returns the associated L<Obvius> object.

=cut

#@returns Obvius
sub obvius {
    my ($self) = @_;
    my $obvius = $self->{_obvius};
    unless($obvius) {
        my $config = $self->obvius_config;
        my $log = Obvius::Log->new(qw(notice));
        #my $log = new Obvius::Log qw(notice);
        $obvius = Obvius->new(
            $config,
            undef, undef, undef, undef, undef,
            log => $log
        );
        $obvius->{USER} = 'admin';
        $self->{_obvius} = $obvius;
    }

    return $obvius;
}

=head2 hostmap

  my $hostmap = $document_utils->hostmap;

returns the associated L<Obvius::Hostmap> object.

=cut

#@returns Obvius::Hostmap
sub hostmap {
    my ($self) = @_;
    my $hostmap = $self->{_hostmap};
    unless($hostmap) {
        $hostmap = $self->obvius_config->param('hostmap') ||
            Obvius::Hostmap->new_with_obvius($self->obvius);
        $self->{_hostmap} = $hostmap;
    }
    return $hostmap;
}

=head2 create_new_document_version

  $document_utils->create_new_document_version($docid, $new_vfields, $skip_clear_cache)

creates a new L<Obvius::Version> based on the $new_fields hashref. Default behaviour is to
clear the cache following creation but this can be skipped if updating multiple documents.

=cut

sub create_new_document_version {
    my ($self, $docid, $new_vfields, $skip_clear_cache) = @_;

    my $obvius = $self->obvius;
    my Obvius::Document $doc = $obvius->get_doc_by_id($docid);
    my Obvius::Version $vdoc = $obvius->get_public_version($doc) || $obvius->get_latest_version($doc);
    $obvius->get_version_fields($vdoc, 255);
    my Obvius::Data $vdoc_fields = $vdoc->param('fields') || {};

    # Copy fields
    foreach my $vfield (@{$new_vfields}) {
        $vdoc_fields->param($vfield->{name} => $vfield->{value});
    }

    # Create new version
    my $doctype = $vdoc->Type || $doc->Type;
    my $new_version_string = $obvius->create_new_version($doc, $doctype, $vdoc->Lang, $vdoc_fields);
    die "Could not create new version" unless ($new_version_string);

    #Publish version
    if($vdoc->param('public')) {
        $obvius->get_version_fields($vdoc, 255, 'PUBLISH_FIELDS');
        my $copy_publish_fields = $vdoc->param('publish_fields');

        my Obvius::Version $new_vdoc = $obvius->get_version($doc, $new_version_string);
        $new_vdoc->param('publish_fields', $copy_publish_fields);
        die "Could not get new version" unless $new_vdoc;

        # Set publish time to right now
        $new_vdoc->publish_fields->param(PUBLISHED => strftime('%Y-%m-%d %H:%M:%S', localtime));

        my $error = '';
        $obvius->publish_version($new_vdoc, \$error);
        die "Could not publish new version" unless $error eq '';
    }

    $self->clear_cache unless $skip_clear_cache;
}

sub clear_cache {
    my ($self) = @_;
    my Obvius $obvius = $self->obvius;

    my $cache = WebObvius::Cache::Cache->new($obvius);
    my $modified = $obvius->modified;
    $obvius->clear_modified;
    $cache->find_and_flush($modified) if($modified);

}

1;
