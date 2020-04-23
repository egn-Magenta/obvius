use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'Obvius',
    'VERSION_FROM'	=> 'Obvius.pm', # finds $VERSION
    'PMLIBDIRS'	=> [ qw(Obvius WebObvius)],
    'PREREQ_PM'		=> {}, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM => 'Obvius.pm', # retrieve abstract from module
       AUTHOR     => 'A. U. Thor <a.u.thor@a.galaxy.far.far.away>') : ()),
);

# Since Apache2.so includes symbols that are only set when running under
# apache we have to disable the PERL_DL_NONLAZY=1 flag when running tests.

package MY;

sub test_via_harness {
    my ($self, $perl, $tests) = @_;

    my $result = $self->SUPER::test_via_harness($perl, $tests);

    $result =~ s{PERL_DL_NONLAZY=1\s+}{};

    return $result;
}

sub test_via_script {
    my($self, $perl, $script) = @_;

    my $result = $self->SUPER::test_via_script($perl, $script);

    $result =~ s{PERL_DL_NONLAZY=1\s+}{};

    return $result;
}
