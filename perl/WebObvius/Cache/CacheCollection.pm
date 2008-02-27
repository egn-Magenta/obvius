package WebObvius::Cache::CacheCollection;

sub new {
     my ($class, @coll) = @_;

     return bless [ @coll ], $class;
}

sub AUTOLOAD {
     my ($this, @args) = @_;
     our $AUTOLOAD;

     my ($method) = $AUTOLOAD =~ /::([^:]+)$/;
     my @result;

     for my $cache (@$this) {
	  if (my $sub = UNIVERSAL::can($cache, $method)) {
	       push @result, &$sub($cache,@args);
	  }
     }
     
     return \@result;
}

1;
