package WebObvius::SOAP::Functions;

use strict;
use warnings;

use Obvius;
use WebObvius;
use WebObvius::SOAP::Server;
use WebObvius::Cache::Flushing;

use Data::Dumper;

my $obvius;


sub new {                                                                                                                                                      
    my $class = shift;
    my $this  = {};

    $obvius = $WebObvius::SOAP::Server::obvius;
    bless ( $this, $class );                                                                                                                                   
}         

sub clear_cache {
   my $this = shift;
   my $options = $WebObvius::SOAP::Server::options;
   WebObvius::Cache::Flushing::immediate_flush( $options->{base} . "/var/document_cacheflush.db", $options->{base} . "/var/document_cache.txt");
   
   return "OK";
}

1;
__END__

=head1 NAME

WebObvius::SOAP::Functions - Object and functions that is avaliable through the SOAP server

=head1 SYNOPSIS

=head1 DESCRIPTION

SOAP server providing a general webservice for Obvius sites

=head1 AUTHORS

Ole Hejlskov <ole@magenta-aps.dk>

=head1 SEE ALSO

=cut
	                 
