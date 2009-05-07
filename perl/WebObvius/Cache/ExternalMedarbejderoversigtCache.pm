package WebObvius::Cache::ExternalMedarbejderoversigtCache;

use strict;
use warnings;

use Data::Dumper;
use WebObvius::Cache::MedarbejderoversigtCache;
use WebObvius::Cache::SOAPHelper;

our @ISA = qw( WebObvius::Cache::MedarbejderoversigtCache );

sub find_and_flush {
     my ($this, $cache_objects) = @_;
     
     my $dirty = $this->find_dirty($cache_objects);
     
     if (@$dirty) {
          $this->flush($dirty);
          
          WebObvius::Cache::SOAPHelper::send_command($this, 
                                                { cache => 'WebObvius::Cache::MedarbejderoversigtCache',
                                                  commands => $dirty });
     }
}
