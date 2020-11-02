package WebObvius::Cache::CacheSyncHelper;

use warnings;
use strict;

use Data::Dumper;
use WebObvius::Cache::SOAPHelper;


sub new {
     my ($class, $obvius, %options) = @_;
     return bless({
         %options,
         obvius => $obvius
     }, $class);
}

# We call flush on all cache-objects that has synchronized set.
sub find_and_flush {
     my ($self, $cacheobjects) = @_;
     if ($cacheobjects) {
          my @objects = grep {
               $_->{synchronized}
          } @{ $cacheobjects->{collection} || []};
          $self->flush(\@objects);
     }
}

# This method will be called alongside other Cache classes' flush methods
# when we find an object with the 'synchronized' flag set, we run the action
# and send out signals to other servers. These other servers will run the same
# methods, eventualle coming here, and run the action as well
sub flush {
     my ($self, $objects) = @_;

     my @commands;
     foreach my $obj (@$objects) {
          if ($obj->{synchronized}) {
               my $action = $obj->{action};
               if ($self->UNIVERSAL::can($action)) {
                    $self->$action($obj);
                    if (!$obj->{local_only}) {
                         push(@commands, { %$obj, local_only => 1 });
                    }
               }
          }
     }
     if (@commands) {
          my $command = { cache => __PACKAGE__, commands => \@commands };
          WebObvius::Cache::SOAPHelper::send_command($self, $command);
     }

}

# Et antal metoder til cache-rydning

sub dynamic_redirects {
     my ($self) = @_;
     my $fh;
     my $filename = $self->{obvius}->config->param('dynamic_redirect_timestamp_file');
     open($fh, ">$filename") or die("Cannot touch $filename: $!");
     # Have to write something to the file to actually update the timestamp
     print $fh  "";
     close($fh);
}

sub update_subsite_files {
     system("/var/www/www.ku.dk/bin/update_subsite_files.pl");
}

1;
