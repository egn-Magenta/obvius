package WebObvius::CatalystUtils::Controller::Utils;
use Moose;
use namespace::autoclean;

use Obvius::CharsetTools qw(mixed2perl);
use JSON;

BEGIN { extends 'Catalyst::Controller'; }

sub begin :Private {
    my ($self, $c) = @_;

    my $auth_res = $c->siteconfig->{admin}->session_authen_handler(
        $c->fakerequest
    );
    if (my $status = $c->response->status) {
        if (!$auth_res) {
            $auth_res = $status;
        }
    }

    if (! grep { $auth_res == $_ } (0, 200)) {
        return $c->detach();
    }
}


sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    $c->response->body('<pre>' . $c->obvius . '</pre>');
}

sub users :Path('users') :Args(0) {
    my ($self, $c) = @_;

    my $sth = $c->obvius->dbh->prepare(q|
        select * from users order by name
    |);
    $sth->execute;
    my @result;
    while (my $rec = $sth->fetchrow_hashref) {
        # Do not expose passwords, even if they are encrypted
        delete $rec->{passwd};
        push(@result, mixed2perl($rec));
    }

    $c->response->content_type('application/json; charset=utf8');
    $c->response->body(JSON::encode_json(\@result));
}

sub filter_from_query {
    my ($self, $c) = @_;

    my $filter = $c->request->param('q') || $c->request->args->[0];

    if ($filter) {
        $filter = Obvius::CharsetTools::mixed2utf8($filter);
        $filter =~ s{([%\\_])}{\\$1}g;
        $filter = '%' . $filter . '%';
    } else {
        $filter = '%'
    }

    return $filter;
}

sub paged_autocomplete {
    my ($self, $c, $query, $args) = @_;

    my $limit = $c->request->param('limit');
    if (!defined($limit) || $limit !~ m{^\d+$}) {
        $limit = 10;
    }

    my $page = $c->request->param('page') || 1;
    if ($page !~ m{^\d+$} or $page < 1) {
        $page = 1
    }

    my $offset = ($page - 1) * $limit;

    my $count_query = $query;
    $count_query =~ s{\bSELECT\b.*?\bFROM\b}{SELECT COUNT(*) FROM}is;

    my $sth = $c->obvius->dbh->prepare($count_query);
    $sth->execute(@$args);
    my ($total) = $sth->fetchrow_array;

    my $offset_query = $query . " LIMIT ?, ?";
    $sth = $c->obvius->dbh->prepare($offset_query);
    $sth->execute(@$args, $offset, $limit);

    my @result;
    while (my $rec = $sth->fetchrow_hashref) {
        push(@result, mixed2perl($rec));
    }
    $sth->finish;

    $c->response->content_type('application/json; charset=utf8');
    $c->response->body(JSON::encode_json({
        totalresults => $total,
        results => \@result
    }));
}

sub users_autocomplete :Path('users/autocomplete') :CaptureArgs(1) {
    my ($self, $c) = @_;

    my $query = q|
        select
            id id,
            name text
        from
            users
        where
            name like ? OR
            lower(binary name) like lower(?)
        order by
            name
    |;

    my $filter = $self->filter_from_query($c);
    return $self->paged_autocomplete($c, $query, [$filter, $filter]);
}

sub groups :Path('groups') :Args(0) {
    my ($self, $c) = @_;

    my $sth = $c->obvius->dbh->prepare(q|
        select * from groups order by name
    |);
    $sth->execute;
    my @result;
    while (my $rec = $sth->fetchrow_hashref) {
        push(@result, mixed2perl($rec));
    }
    
    $c->response->content_type('application/json; charset=utf8');
    $c->response->body(JSON::encode_json(\@result));
}

sub groups_autocomplete :Path('groups/autocomplete') :CaptureArgs(1) {
    my ($self, $c) = @_;

    my $query = q|
        select
            id id,
            name text
        from
            groups
        where
            name like ? OR
            lower(binary name) like lower(?)
        order by
            name
    |;

    my $filter = $self->filter_from_query($c);
    return $self->paged_autocomplete($c, $query, [$filter, $filter]);
}

__PACKAGE__->meta->make_immutable;

1;
