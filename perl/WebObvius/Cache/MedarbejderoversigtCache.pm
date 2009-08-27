package WebObvius::Cache::MedarbejderoversigtCache;

use strict;
use warnings;

use WebObvius::Cache::FileCache;

our @ISA = qw( WebObvius::Cache::FileCache );

sub new {
     my ($class, $obvius) = @_;
     
     my $ns = "medarbejderoversigtcache";
     my $this = $class->SUPER::new($obvius, $ns, default_expires_in => 86400);
     return $this;
}

sub save {
     my ($this, $doc, $data) = @_;
     
     my $uri = $this->{obvius}->get_doc_uri($doc);
     return $this->get_cache()->set($uri, $data);
}

sub get {
     my ($this, $doc) = @_;
     
     my $uri = $this->{obvius}->get_doc_uri($doc);

     return $this->get_cache()->get($uri);
}

sub find_dirty {
     my ($this, $cache_objects) = @_;
     
     my @cos = grep { $_->{docid} } @{$cache_objects->request_values('docid')};
     
     my $obvius = $this->{obvius};
     my @dirty;
     for my $co (@cos) {
          my $doc = $obvius->get_doc_by_id($co->{docid});
          next if !$doc;
          
          my $uri = $obvius->get_doc_uri($doc);
          push @dirty, $uri;
     }
     return \@dirty;
}
1;
