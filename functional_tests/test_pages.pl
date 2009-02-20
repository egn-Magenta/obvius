#!/usr/bin/env perl
use strict;
use warnings;

package MyUserAgent;
use LWP::UserAgent;

our @ISA = qw( LWP::UserAgent );

sub get_basic_credentials {
     return ('admin', 'OCms4KU!');
}

1;

package Main;
use Obvius;
use Obvius::Config;
use Data::Dumper;
use HTTP::Request;
use Getopt::Long;
my ($server, $reference, $only_testarea);


my $cmd_name = $0;
my $result = GetOptions('server=s' => \$server,
                        'reference' => \$reference,
			'only_testarea' => \$only_testarea);

my $usage = "Usage: $cmd_name --server <server> [--reference] [--only_testarea] \n";

die $usage if !$server;

my $obvius = Obvius->new(Obvius::Config->new('ku'));

my @docids;
my $docids;
if (!$only_testarea) {
	$docids = $obvius->execute_select("select docid from docparms where name='is_subsite' and value=1");
	push @docids, @$docids;
}
$docids = $obvius->execute_select("select id as docid from documents where parent = 277513");
$_->{admin} = 1 for (@$docids);
push @docids, @$docids;

-d "reference" or mkdir "reference" or die "Couldn't create reference-directory";
-d "data" or mkdir "data" or die "Couldn't create data dir";

my $ua = MyUserAgent->new("Test Script for KU");
$ua->credentials("http://cms.ku.dk/", 'ku', 'admin', 'OCms4KU!');
sub http_request {
     my ($data) = @_;
     
     my $doc = $obvius->get_doc_by_id($data->{docid});
     return [] if !$doc;
     my $uri = $obvius->get_doc_uri($doc);
     return [] if !$uri;
     
     
     my $server_uri = "http://$server$uri?1";
     my @res = {req => HTTP::Request->new("GET" => $server_uri), 
                server_uri => $server_uri,
                filename => $data->{docid}};
       
     return \@res if (!$data->{admin});
     
     $server_uri = "http://$server/admin$uri";
     push @res,{req => HTTP::Request->new("GET" => $server_uri), 
                server_uri => $server_uri,
                filename => $data->{docid} . "_admin"};
     
     return \@res;
}
                
my %seen;
my $status;
open $status, ">", "status";
for my $doc (@docids) {
     next if $seen{$doc->{docid}}++;
     
     my $reqs = http_request($doc);
     for my $req (@$reqs) {
          my $data = $ua->request($req->{req});
          
	  if (!$data->is_success) {
               my @nonnotable_fault_codes = (404);
               next if grep { $data->code == $_ } @nonnotable_fault_codes;
               print "$req->{server_uri} ", $data->status_line . "\n";
               print $status "$req->{server_uri} ", $data->status_line . "\n";
               next;
          }
          my $filename = $reference ? "reference/$req->{filename}" : "data/$req->{filename}";
          
          my $fh;
          open $fh, ">", $filename;
          print $fh $data->content;
          close $fh;
     
          if (!$reference) {
               my $diff = `diff reference/$req->{filename} data/$req->{filename}`;
               if ($diff) {
                    print "Error: $doc->{docid} $req->{server_uri}\n$diff\n";
                    print $status "Error: $doc->{docid} $req->{server_uri}\n$diff\n";
               }
          }
     }
}
close $status;  
