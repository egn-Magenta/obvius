package WebObvius::Rewriter::RewriteRule;

use strict;
use warnings;

use Exporter;
our @ISA = qw(Exporter);

use constant REWRITE => 'rewrite';
use constant REDIRECT => 'redirect';
use constant REDIRECT_PERMANENT => 'redirect_301';
use constant PASSTHROUGH => 'passthrough';
use constant FORBIDDEN => 'forbidden';
use constant LAST => 'last';
use constant PROXY => 'proxy';

our @EXPORT_OK = qw(
    REWRITE
    REDIRECT
    REDIRECT_PERMANENT
    PASSTHROUGH
    FORBIDDEN
    LAST
    PROXY
);

our %EXPORT_TAGS = (
    all => \@EXPORT_OK,
);

1;

sub new {
    my ($class, %args) = @_;;
    my %ref = (
        is_admin_rewriter => 0,
        %args,
    );
    return bless(\%ref, $class);
}

sub setup {
    my ($this, $rewriter) = @_;
    #put stuff for configuring the module at load here.
}

sub rewrite {
    my ($this, %args) = @_;
    
    # Default to doing nothing
    warn ("Using default rewrite rule in package " . ref($this));
    return (REWRITE, '-');
}

1;