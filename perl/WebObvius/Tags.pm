package WebObvius::Tags;

use strict;
use warnings;

sub new {
     my ($class, $obvius) = @_;
     bless {obvius => $obvius}, $class;
}

sub get_tags_recursive {
     my ($this, $doc, $filter, $doctypes) = @_;

     my $uri = $obvius->get_doc_uri($doc);

     if (!$uri) {
          die "$doc does apparently not exist";
     }

     $uri .= '%';
     my @where = ("v.public = 1", "vf.name = 'tags'", "dp.path like ?");
     my @params = ($uri);

     if ($filter && @$filter) {
          my $template = join ",", (("?") x @$filter);
          push @where, "vf.text_value in ($template)";
          push @params, @$filter;
     }
     
     if ($doctypes && @$doctypes) {
          my $template = join ",", (("?" x @$doctypes));
          push @where, "v.type in ($template)";
          push @params, @$doctypes;
     }

     my $where = join ' and ', @where;
     my $query = "select 
                         vf.text_value tag, count(*) count
                  from 
                         docid_path dp natural join versions v natural join vfields vf
                  where 
                         $where
                  group by 
                         vf.text_value 
                  order by count desc";
     
     my $tags = $this->{obvius}->execute_select($query, @params);
     return $tags;
}


sub get_tags_from_closest_subsite {
     my ($this, $doc, @args) = @_;
     
     my $closest_subsite = $this->{obvius}->find_closest_subsite($doc);

     if (!$closest_subsite) {
          warn "No closest subsite for $doc";
          $closest_subsite = $doc;
     }
     
     return $this->get_tags_recursive($closest_subsite, @args);
}

42;
