package Obvius::Test::MockModule;

use strict;
use warnings;

use Test::MockModule;

our %mocked;

my %skip_methods = map { $_ => 1 } qw(
    import
    BEGIN
    END
    INIT
    UNIT_CHECK
    CHECK
    mock
    unmock
    mockclass
);

sub mockclass { die "You must define which class to mock" }

sub mock {
    my $class = shift;
    $class = ref($class) || $class || '';

    return if($mocked{$class});

    my $mocked = Test::MockModule->new($class->mockclass);

    no strict 'refs';
    my @methods = keys %{$class . '::'};
    use strict 'refs';

    foreach my $key (@methods) {
        next if $skip_methods{$key};
        # Skip methods that start with _;
        next if $key =~ m{^_};

        my $method = $class . "::" . $key;
        next unless defined(&{$method});

        # print("Mocking: $key in $class\n");
        my $sub = \&{$method};
        $mocked->mock($key => $sub);
    }

    $mocked{$class} = $mocked;

    return $mocked;
}

sub unmock {
    my $class = shift;
    $class = ref($class) || $class || '';

    delete $mocked{$class};
}

sub is_mocked {
    my $class = shift;

    return $mocked{$class};
}

1;