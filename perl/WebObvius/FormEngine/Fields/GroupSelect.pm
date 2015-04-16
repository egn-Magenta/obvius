package WebObvius::FormEngine::Fields::GroupSelect;

use strict;
use warnings;
use utf8;

use WebObvius::FormEngine::Fields;
use Obvius::CharsetTools qw(mixed2perl);

our @ISA = qw(WebObvius::FormEngine::Fields::MultipleBase);

sub type { "groupselect" }
sub edit_component { "groupselect.mason" }

sub new {
    my ($package, $form, $name, %data) = @_;

    unless($data{obvius}) {
        die "You must specify obvius as an option to " .
            "GroupSelect fields";
    }
    my $obj = $package->SUPER::new($form, $name, %data);

    return bless($obj, $package);
}

sub setup_options {
    my ($self, $options) = @_; 

    my $obvius = $self->{obvius};
    my @options;

    my $condition = '1=1';
    my @q_args;
    unless($obvius->can_create_new_user() > 1) {
        my $user_groups = $obvius->get_user_groups(
            $obvius->get_userid( $obvius->{USER} )
        ) || [];
        if(@$user_groups) {
            my $qms = join(",", map { "?" } @$user_groups);
            $condition = "groups.id in ($qms)";
            push(@q_args, @$user_groups);
        } else {
            $condition = "1=0";
        }
    }
    my $sth = $obvius->dbh->prepare(qq|
        select id, name
        from groups
        where $condition
        order by name
    |);
    $sth->execute(@q_args);
    while(my ($id, $name) = $sth->fetchrow_array) {
        push(@options, WebObvius::FormEngine::Option->new(
            $self, text => mixed2perl($name), value => $id
        ));
    }
    
    @options = sort { lc($a->label) cmp lc($b->label) } @options;
    
    $self->{options} = \@options;
}

1;