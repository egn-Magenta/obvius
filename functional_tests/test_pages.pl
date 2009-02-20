#!/usr/bin/env perl
use strict;
use warnings;

use LWP::UserAgent;
use Obvius;
use Obvius::Config;
use HTTP::Request;

use Getopt::Long;
my ($server, $reference);

my $cmd_name = $0;
my $result = GetOptions('server=s' => \$server,
                        'reference' => \$reference);

my $usage = "Usage: $cmd_name --server <server> [--reference]\n";

die $usage if !$server;

my $obvius = Obvius->new(Obvius::Config->new('ku'));

my $docids = $obvius->execute_select("select docid from docparms where name='is_subsite' and value=1");
my @docids = map { $_->{docid} } @$docids;

-d "reference" or mkdir "reference" or die "Couldn't create reference-directory";
-d "data" or mkdir "data" or die "Couldn't create data dir";

my $ua = LWP::UserAgent->new("Test Script for KU");

my %seen;
for my $docid (@docids) {
     next if $seen{$docid}++;
     my $doc = $obvius->get_doc_by_id($docid);
     next if !$doc;
     my $uri = $obvius->get_doc_uri($doc);
     next if !$uri;
     
     my $server_uri = "http://$server$uri?1";
     my $req = HTTP::Request->new("GET" => $server_uri);
     my $data = $ua->request($req);
     
     
     if (!$data->is_success) {
          my @nonnotable_fault_codes = (401, 404);
          next if grep { $data->code == $_ } @nonnotable_fault_codes;
          print "$server_uri ", $data->status_line . "\n";
          next;
     }
     my $filename = $reference ? "reference/$docid" : "data/$docid";
     
     my $fh;
     open $fh, ">", $filename;
     print $fh $data->content;
     close $fh;
     
     if (!$reference) {
          my $diff = `diff reference/$docid data/$docid`;
          if ($diff) {
               print "Error: $docid $server_uri\n$diff\n";
          }
     }
}
            
