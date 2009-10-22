package Obvius::SolrSearch;

use strict;
use warnings;

use Obvius::Config;
use JSON;
use LWP::UserAgent;
use Data::Dumper;
use Encode;

our @methods = 
  ('path', 
   'query', 
   'doctype',
   'tags', 
   {
    name => 'published_before', 
    validator => \&validate_date,
    type => 'singleton'
   },
   { name => 'published_after',
     validator => \&validate_date,
     type => 'singleton'
   }, 
   { 
    name => 'offset',
    validator => sub { $_[0] =~ /^\d+$/ },
    type => 'singleton'
   },
   { 
    name => 'limit',
    validator => sub { $_[0] =~ /^\d+$/ },
    type => 'singleton'
   });

no strict "refs";
for my $method (@methods) {
     my $name = ref $method ? $method->{name} : $method;
     *{__PACKAGE__ . '::' . $name} = sub {
          my ($this, @args) = @_;
          my ($type, $validator) = ('array', undef);
          
          if (ref $method) {
               ($validator, $type) = @$method{qw( validator type )};
          }
          
          for my $arg (@args) {
               if ($validator && !$validator->($arg)) {
                    die "Illegal value: $arg\n";
               }
               if ($type eq 'singleton') {
                    $this->{$name} = $arg;
               } else {
                    push @{$this->{$name}}, $arg;
               }
          }
          return $this;
     }
}
use strict "refs";

sub sort_by {
     my ($this, $order) = @_;
     $this->{sort_by} = $order;
     return $this;
}

sub new {
     my ($class, %options) = @_;
     
     my $this = bless {}, $class;
     
     for my $option (keys %options) {
          if ($this->UNVERSIAL::can($option)) {
               $this->$option($options{$option});
          } else {
               die "SolrSearch: Unknown option, $option";
          }
     }
     
     for my $method (@methods) {
          if (ref $method eq 'HASH' && $method->{type} ne 'singleton' || !ref $method) {
               $this->{$method} = [];
          }
     }
     return $this;
}


sub validate_date {
     my ($date) = @_;
     
     return $date =~ /\d{4}-\d{2}-\d{2}/;
}


sub escape_special {
     my ($str, $all) = @_;
     
     my $escape_chars = sub {
          my ($chars) = @_;
          $chars =~ s!(.)!\\$1!g;
          return $chars;
     };
     
     my @special_chars = qw'- && || ! ( ) { } [ ] ^ ~ : \ ';
     my @sometimes_special = qw' " + * ? ';
     push @special_chars, @sometimes_special if $all;

     my $special_chars_regex = '(' . (join '|', map { $escape_chars->($_) } @special_chars) . ')';
     $str =~ s!$special_chars_regex!$escape_chars->($1)!ge;

     return $str;
}

sub assemble_subquery {
     my ($array, $prefix, $postfix, $no_full_escape) = @_;
     
     my @elems; 
     for my $elem (@$array) {
          push @elems, ($prefix || "") . escape_special($elem, !$no_full_escape) . ($postfix || "");
     }

     return () if !@elems;
     return @elems if @elems == 1;
     
     return '(' . (join ' OR ', @elems) . ')';
}

sub normalize_path {
     my ($path) = @_;
     $path .= '/';
     $path =~ s!/+!/!g;
     return $path;
}

sub make_solr_filter_query {
     my ($this) = @_;

     my @query;

     my @paths = map { normalize_path($_) } @{$this->{path}};
     push @query, assemble_subquery(\@paths, "path:", '*');
     push @query, assemble_subquery($this->{tags}, 'tags:"', '"');
     push @query, assemble_subquery($this->{doctype},"type:");

     my $published_before = $this->{published_before};
     my $published_after = $this->{published_after};
     if ($published_before || $published_after) {
          $published_before = $published_before ? $published_before . "T00:00:00Z" : '*';
          $published_after = $published_after ? $published_after . "T00:00:00Z" : '*';
          push @query, "published:[$published_after TO $published_before]";
     }
     

     return join ' AND ', @query;
}

sub make_solr_query {
     my ($this) = @_;

     my @query;
     my @fields = (['content', 1], ['title', 3], ['teaser', 2]);

     my @queries = grep { $_ && !/^\s*$/ } @{$this->{query}};

     for my $field_data (@fields) {
          my ($field, $boost) = @$field_data;
          push @query, assemble_subquery(\@queries, "$field:(", ")^$boost", 1);
     }
     my $query = join ' ', @query;
     
     return $query;
}
     
sub search {
     my ($this, $url) = @_;

     die "Invalid url: $url" if !$url;

     my $filter_query = $this->make_solr_filter_query;
     my $query = $this->make_solr_query;
     
     if (!defined $query || $query =~ /^\s*$/) {
          $query = "title:[* TO *]";
     }

     my $start = $this->{offset} || 0;
     my $rows = $this->{limit} || 10;

     my $sort = $this->{sort_by} || "score desc";
     my $ua = LWP::UserAgent->new;
     
     my $res = $ua->post($url,
                    {
                     fq => Encode::encode('UTF-8', $filter_query),
                     q => Encode::encode('UTF-8', $query),
                     fl => "title,id,score,teaser,path,content,tags,published", 
                     sort => $sort,
                     wt => "json",
                     rows => $rows,
                     start => $start
                    });
     
     if ($res->is_success) {
          #Horror of horrors, but we are in a hurry.
          my $decode = sub {
               my ($content) = @_;
               my $temp;
               do {
                    $temp = $content;
                    $content = eval { Encode::decode('utf-8', $content, Encode::FB_CROAK) };
                    
                    $content = $temp if $@;
               } while (!$@ && $temp ne $content);
               return $content;
          };

          my $content = from_json($res->content)->{response};

          return $content if !$content->{docs};
          
          for my $doc (@{$content->{docs}}) {
               for my $key (keys %$doc) {
                    $doc->{$key} = Encode::encode('latin-1', $decode->($doc->{$key}));
               }
          }
          
          return $content;
     } else {
          die $res->content;
     }
}
     
1;
