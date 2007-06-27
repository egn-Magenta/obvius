package WebObvius::SOAP::Server;

use strict;
use warnings;

use Obvius;
use Obvius::Data;
use WebObvius;
use Data::Dumper;
use SOAP::Transport::HTTP;
use WebObvius::Apache
        Constants       => qw(:common :methods :response),
        File            => '';                                                                                                                                                              

our $obvius;
my $SOAPServer;
our $options;

sub new
{
  my ( $class, %opt ) = @_;
  my $this = {};
  
  bless( $this, $class );
  
  $this->{obvius_config}             = $opt{obvius_config};
  $this->{webobvius_cache_directory} = $opt{webobvius_cache_directory};
  $this->{webobvius_cache_index}     = $opt{webobvius_cache_index};
  $this->{base}                      = $opt{base};
  $this->{sitename}                  = $opt{sitename};
 
  $options = \%opt;
 
  $obvius = new Obvius($this->{obvius_config});
  
  $SOAPServer = SOAP::Transport::HTTP::Apache-> dispatch_to( "WebObvius::SOAP::Functions" );
  
  return $this;
}


sub handler ($$) 
{
    my ($this, $req) = @_;
    
    $SOAPServer->handler($req);
    
    return OK;
}

sub get_param
{
  my ($this, $key) = @_;
  return "hest";
#  return $this->{$key};
}


1;
__END__

=head1 NAME

WebObvius::SOAP::Server - mod_perl module for Obvius webservice.

=head1 SYNOPSIS

=head1 DESCRIPTION

SOAP server providing a general webservice for Obvius sites

=head1 AUTHORS

Ole Hejlskov <ole@magenta-aps.dk>

=head1 SEE ALSO

=cut
	                 
