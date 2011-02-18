package WebObvius::Rewriter;

use strict;
use warnings;

use Scalar::Util qw (blessed);
use WebObvius::Rewriter::RewriteRule qw(REWRITE);

sub new {
    my ($class, $config, %args) = @_;

    die "You must specify a Obvius::Config object" unless($config and ref($config) eq 'Obvius::Config');

    my %data = (
        %args,
        rewriters => [],
        config => $config,
    );
    
    return bless \%data, $class;
}

sub rewriters {
    my ($this) = @_;
    
    return @{$this->{rewriters}};
}

sub add_rewriter {
    my ($this, $rewriter) = @_;
    
    if(blessed($rewriter) && $rewriter->isa("WebObvius::Rewriter::RewriteRule") ) {
        $rewriter->setup($this);
        push(@{$this->{rewriters}}, $rewriter);
    } else {
        warn "Rewriter object with ref '" . (ref($rewriter) || '') . "' is not a RewriteRule, skipping it";
    }
}

sub add_rewriters {
    my ($this, @list) = @_;
    
    for my $rw (@list) {
        if(ref($rw) eq 'ARRAY') {
            map {$this->add_rewriter($_)} @$rw;
        } else {
            $this->add_rewriter($rw);
        }
    }
}

sub rewrite {
    my ($this, $input) = @_;
    my %args = split(/[?]/, $input);
    
    my $rewritten = 0;
    for my $rw ($this->rewriters) {
        my ($action, $url) = $rw->rewrite(%args);
        if($this->{debug}) {
            my $a = $action || 'no action';
            my $class = ref($rw);
            my $u = $url || $args{uri};
            print STDERR "'$args{uri}' => '$u', $a from $class\n";
        }
        next unless($action);

        $rewritten = 1;
        $args{uri} = $url unless($url eq  '-');

        return ("$action:$args{uri}") if($action ne REWRITE);
    }
    
    return $rewritten ? (REWRITE . ":$args{uri}") : "NULL";
}

1;

