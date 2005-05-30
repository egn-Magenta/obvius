#!/usr/bin/perl

use strict;
use warnings;

use Obvius::Config;
use Obvius::Log::Apache;

use WebObvius::Site::Mason;
use WebObvius::Access;
use WebObvius::Admin;

package ${perlname}::Site::Common;
our @ISA = qw( WebObvius::Site::Mason WebObvius::Access );

package ${perlname}::Site::Public;
our @ISA = qw( WebObvius::Site::Mason WebObvius::Access );

package ${perlname}::Site::Admin;
our @ISA = qw( WebObvius::Site::Mason WebObvius::Admin );

# Namespace for running Mason seperately for mason-cache handling:
package ${perlname}::Site::Admin::CacheHandling;
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

package ${perlname}::Site;

print STDERR "Starting ${perlname} ...\n";

my $obvius_config=new Obvius::Config('${dbname}');

my $sitename = '${website}';

my $globalbase ="${wwwroot}";
my $base = "$globalbase/$sitename";
my $log = new Obvius::Log::Apache;

my $subsite='';
our $Common = ${perlname}::Site::Common->new(
                                        debug => $obvius_config->Debug,
                                        benchmark => $obvius_config->Benchmark,
                                        comp_root=>[
                                                    [docroot  =>"$base/docs"],
                                                    [sitecomp =>"$base/mason/common"],
                                                    [globalcommoncomp =>"$globalbase/obvius/mason/common"],
                                                   ],
                                        base => $base,
                                        site => 'common',
                                        sitename => $sitename,
                                        edit_sessions=> "$base/var/edit_sessions",
                                        out_method => \$subsite,
                                        cache_directory => "$base/var",
                                        obvius_config => $obvius_config,
                                        search_words_log => "$base/htdig/log/search_words.log",
                                        log => $log,
                                       );

my $publicsite='';
our $Public = ${perlname}::Site::Public->new(
                                        debug => $obvius_config->Debug,
                                        benchmark => $obvius_config->Benchmark,
                                        out_method => \$publicsite,
                                        cache_directory => "$base/var",
                                        base => $base,
                                        sitename => $sitename,
                                        site => 'public',
                                        webobvius_cache_directory=>"$base/var/document_cache",
                                        webobvius_cache_index=>"$base/var/document_cache.txt",
                                        post_max => 4*1024*1024,
                                        obvius_config => $obvius_config,
                                        subsite => $Common,
                                        comp_root=>[
                                                    [docroot  =>"$base/docs"],
                                                    [sitecomp =>"$base/mason/public"],
                                                    [globalpubliccomp =>"$globalbase/obvius/mason/public"],
                                                    [commoncomp => "$base/mason/common"],
                                                    [globalcommoncomp =>"$globalbase/obvius/mason/common"],
                                                   ],
                                        search_words_log => "$base/htdig/log/search_words.log",
                                        log => $log,
                                       );

our $Admin = ${perlname}::Site::Admin->new(
                                      debug => $obvius_config->Debug,
                                      benchmark => $obvius_config->Benchmark,
                                      obvius_config => $obvius_config,
                                      webobvius_cache_directory=>"$base/var/document_cache",
                                      webobvius_cache_index=>"$base/var/document_cache.txt",
                                      synonyms_file=>"$base/htdig/common/synonyms",
                                      subsite => $Common,
                                      base => $base,
                                      sitename => $sitename,
                                      site => 'admin',
                                      edit_sessions=> "$base/var/edit_sessions",
                                      is_admin => 1,
                                      comp_root=>[
                                                  [docroot  =>"$base/docs"],
                                                  [sitecomp =>"$base/mason/admin"],
                                                  [admincomp=>"$globalbase/obvius/mason/admin"],
                                                  [commoncomp => "$base/mason/common"],
                                                  [globalcommoncomp =>"$globalbase/obvius/mason/common"],
                                                 ],
                                      search_words_log => "$base/htdig/log/search_words.log",
                                      log => $log,
                                     );

1;
