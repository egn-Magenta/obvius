package WebObvius::Controller::ListBase;

use strict;
use warnings;
use utf8;
use POSIX qw(ceil);

use URI::Escape;

use base 'WebObvius::Controller::ActionController';

sub default_order_by { "id:asc" }
our %valid_order_by = map { $_ => 1 } qw(asc desc);

sub default_pagesize { 10 }
sub pagesizes {
    return (10, 20, 50, 100, 'all');
}

# List of field to display in the list
sub get_field_list {
    my ($self) = @_;

    return (
        {
            name => "id",
            hashref_name => "id",
            title => "Id",
            order_default => "asc",
        },
        {
            name => "name",
            hashref_name => "name",
            title => "Path name",
            order_default => "asc",
        },
        {
            name => "owner",
            hashref_name => "owner",
            title => "Owner",
            order_default => "desc",
            to_display_value => sub {
                my $rec = shift;
                my $user = $self->obvius->get_user($rec->{owner});
                return (
                    $user ?
                    sprintf(
                        '%s (%s) <%s>',
                        $user->{name}, $user->{login}, $user->{email}
                    ) :
                    $self->translate_raw('Unknown user')
                );
            },
        }
    )
}

# Field list accessor that translates titles, builds sorting links
# etc.
sub field_list {
    my ($self) = @_;

    my $fieldlist = $self->{fieldlist};

    unless($fieldlist) {
        my @fieldlist = $self->get_field_list;
        my $order_data = $self->order_data;
        foreach my $field (@fieldlist) {
            my $title = $field->{title} || $field->{name};
            $field->{untranslated_title} = $title;
            $field->{title} = $self->translate($title);
            $field->{order_by_link} = $self->build_order_link($field);
            $field->{is_ordered} = $order_data->{field} eq $field->{name};
            $field->{order_by_direction} = $field->{is_ordered} ?
                $order_data->{direction} :
                $field->{order_default} || "asc";
        }
        $fieldlist = \@fieldlist;
    }

    return @$fieldlist;
}

sub order_data {
    my ($self) = @_;

    unless($self->{order_data}) {

        my ($default_field, $default_direction) = split(/:/, $self->default_order_by);

        my $order_by = $self->r->param('order_by') || $self->default_order_by;
        my ($name, $direction) = split(/:/, $order_by);
        if(!$valid_order_by{$direction}) {
            $direction = $default_direction || "asc";
        }

        if(!grep { $_->{name} eq $name } $self->get_field_list) {
            $name = $default_field;
        }

        my $sql_field;

        foreach my $field ($self->get_field_list) {
            if($field->{name} eq $name) {
                $sql_field = $field->{sql} || $field->{name};
                last;
            }
        }

        $self->{order_data} = {
            field => $name,
            direction => $direction,
            sql => "$sql_field $direction",
        }
    }

    return $self->{order_data};
}

sub unpropagated_params {
    my @unpropagated;
    return \@unpropagated;
}

sub request_param_hash {
    my ($self) = @_;

    my $r = $self->r;

    unless($self->{request_param_hash}) {
        my %data;
        my @order;
        foreach my $name ($r->param) {
            if (grep { $_ eq $name } @{$self->unpropagated_params}) {
                next;
            }
            my @values = $r->param($name);
            $data{$name} = \@values;
            push(@order, $name);
        }
        $self->{request_param_hash} = {
            order => \@order,
            values => \%data,
        };
    }

    return $self->{request_param_hash};
}

sub build_order_link {
    my ($self, $field) = @_;

    if ($field->{no_ordering}) {
        return undef;
    }

    my $order_data = $self->order_data;
    my $name = $field->{name};
    my $direction = $field->{order_default} || "asc";
    if($field->{name} eq $order_data->{field}) {
        $direction = $order_data->{direction} eq "asc" ?
                     'desc':
                     'asc';
    }

    return $self->build_link(
        remove => "order_by",
        append => "order_by=$name:$direction"
    );
}

sub filter_options {
    return {};
}

# Gets the SQL and the SQL arguments for the main query, without
# ordering and limiting.
sub get_query_sql {
    my ($self) = @_;

    return ('select * from documents', []);
}

sub get_count_sql {
    my ($self) = @_;
    return ('select count(*) from documents', []);
}

# Gets the SQL and the SQL arguments used for ordering the query
sub get_order_by_sql {
    my ($self) = @_;

    my $order = $self->order_data->{sql};

    return ("ORDER BY $order");
}

# Gets the SQL and the SQL arguments used for limiting the query
sub get_limit_sql {
    my ($self) = @_;

    my $r = $self->r;
    my $pagesize = $r->param('pagesize') || '';
    my $page = $r->param('page') || 1;
    my $limit_sql = "";
    my @sql_args;

    if (!(grep { $_ eq $pagesize } $self->pagesizes)) {
        $pagesize = $self->default_pagesize;
    }
    if ($page !~ m{^\d+$} || $page < 1) {
        $page = 1;
    }

    if($pagesize eq "all") {
        $limit_sql = "";
    } else {
        my $offset = ($page - 1) * $pagesize;
        $limit_sql = "LIMIT ?, ?";
        @sql_args = ($offset, $pagesize);
    }

    return (
        $limit_sql,
        \@sql_args
    );
}

sub pager_info {
    my ($self) = @_;

    my $r = $self->r;

    my $pagesize = $r->param('pagesize') || '';
    unless($self->{pager_info}) {
        my $page = $r->param('page') || 1;

        if (!(grep { $_ eq $pagesize } $self->pagesizes)) {
            $pagesize = $self->default_pagesize;
        }
        if($page !~ m{^\d+$} || $page < 1) {
            $page = 1;
        }

        my $first_page = 1;
        my $last_page = $pagesize eq 'all' ? 1 : (ceil($self->{result_count} / $pagesize));

        my $next_page = $page + 1;
        my $prev_page = $page > 1 ? $page - 1 : 1;

        if ($last_page == 0) {
            $page = 0;
            $first_page = 0;
            $next_page = 0;
            $prev_page = 0;
        }

        my @pagesizes;
        for my $pagesize_option ($self->pagesizes) {
            push(
                @pagesizes,
                {
                    text => ($pagesize_option eq 'all') ? $self->translate_raw('all') : $pagesize_option,
                    link => $self->build_link(remove => "pagesize", append => "pagesize=$pagesize_option")
                }
            );
        }

        $self->{pager_info} = {
            pagesize         => $pagesize,
            page             => $page,
            first_page_link  => $first_page != $page ?
                $self->build_link(remove => "page", append => "page=$first_page") :
                "",
            prev_page        => $prev_page,
            prev_page_link   => $prev_page != $page ?
                $self->build_link(remove => "page", append => "page=$prev_page") :
                "",
            next_page        => $next_page,
            next_page_link   => $next_page != $page ?
                $self->build_link(remove => "page", append => "page=$next_page") :
                "",
            last_page        => $last_page,
            last_page_link   => $last_page != $page ?
                $self->build_link(remove => "page", append => "page=$last_page") :
                "",
            pagesize_options => \@pagesizes
        };
    }
    return $self->{pager_info};
}

sub perform_default { shift->perform_search(@_) }

sub perform_search {
    my ($self) = @_;

    my ($query_sql, $query_args, $count_sql) = $self->get_query_sql;
    my ($order_sql, $order_args) = $self->get_order_by_sql;
    my ($limit_sql, $limit_args) = $self->get_limit_sql;

    my $sql = join("\n", $query_sql, $order_sql, $limit_sql);
    my @args = (@{$query_args || []}, @{$order_args || []}, @{$limit_args || []});

    my $sth = $self->obvius->dbh->prepare($sql);
    $sth->execute(@args);
    
    my @result;
    my @fieldlist = $self->get_field_list;

    while(my $rec = $sth->fetchrow_hashref) {
        my @list;
        my %by_name;

        foreach my $field (@fieldlist) {
            my $rec_name = $field->{hashref_name} || $field->{name};
            my $raw_value = $rec->{$rec_name};
            my $data = {
                field => $field,
                rec => $rec,
                value => $raw_value,
                display_value => $field->{to_display_value} ?
                    $field->{to_display_value}($rec):
                    $raw_value
            };
            push(@list, $data);
            $by_name{$field->{name}} = $data;
        }

        push(@result, {
            fieldlist => \@list,
            by_name => \%by_name
        });
    }
    $sth->finish();

    my $count = @result;
    if (defined($count_sql)) {
        $sth = $self->obvius->dbh->prepare($count_sql);
        $sth->execute(@{$query_args || []});
        my $row = $sth->fetchrow_hashref();
        if (defined($row)) {
            my @v = values(%$row);
            $count = $v[0];
        }
        $sth->finish();
    }
    $self->{result_count} = $count;

    return $self->output_template(
        'search',
        results => \@result
    );
}

1;
