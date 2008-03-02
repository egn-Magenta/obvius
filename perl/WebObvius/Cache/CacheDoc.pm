package WebObvius::Cache::CacheDoc;

use Data::Dumper;
use strict;
use warnings;

sub new {
     my ($class, $obvius, %obj) = @_;

     return if (!($obj{uri} || $obj{docid}));

     my $doc = $obj{docid} ? $obvius->get_doc_by_id($obj{docid}) :
               $obvius->lookup_document($obj{url});
     
     return if (!$doc);
     
     return bless {docid  => $obj{docid} || $doc->Id,
		   uri    => $obj{uri}   || $obvius->get_doc_uri($doc),
		   clear_leftmenu  => $obj{clear_leftmenu}
		   }, $class;
}

1;
