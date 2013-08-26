package WebObvius::Cache::MysqlApacheCache::QueryStringMapper;

use strict;
use warnings;

sub new {
    my ($class) = @_;
    
    return bless({}, $class);
}

# Method for changing a querystring into what will be stored / matched in
# the cache. Return value should a list of two values:
#  - A boolean value specifying whether this querystring can be cached
#  - The modified querystring used for saving/matching in the cache.
sub map_querystring_for_cache {
    my ($this, $doctypeid, $doctypename, $querystring) = @_;

    # Allow caching of anything with an empty querystring
    return (1, $querystring) if($querystring eq "");

    # Allow caching of images with a size url parameter
    return (1, $querystring) if($doctypename eq 'Image' and $querystring =~ m!^size=\d+x\d+!);

    # Don't cache anything else
    return (0, "");
}

1;
