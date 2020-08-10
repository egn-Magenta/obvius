package Obvius::GarbageHandler;

use strict;
use warnings;
use Data::Dumper;
use Obvius;

sub new {
    my ( $class, $obvius ) = @_;
    bless { obvius => $obvius }, $class;
}

sub can_access_all {
    my ( $this, $user ) = @_;

    my $userid = $this->{obvius}->get_userid($user);

    return 1 if ( $userid == 1 );
    return grep { $_ == 1 } @{ $this->{obvius}->get_user_groups($userid) };
}

sub can_access_document {
    my ( $this, $user, $doc ) = @_;
    return 1 if $this->can_access_all($user);
    return $doc->{delete_user} == $this->{obvius}->get_userid($user);
}

sub get_documents {
    my ( $this, $user, $offset, $limit, %options ) = @_;

    my $sort_by = $options{sort_by};
    my $user_id = $user ? $this->{obvius}->get_userid($user) : undef;
    $user_id = undef if defined $user && $this->can_access_all($user);

    my $where = $user_id ? 'where db.delete_user = ? ' : '';
    my $query = "select db.path path, db.id id, db.name name, db.path path, 
                         db.date_deleted date_deleted, db.delete_user, u.login login 
                  from documents_backup db left join users u on 
                  (db.delete_user = u.id) $where";

    $query .= " order by $sort_by " . ( $options{reverse} ? 'asc' : 'desc' )
      if ( $sort_by && $sort_by =~ /^[\d\w_]+$/ );
    $query .= " limit $limit "   if ( $limit  && $limit  =~ /^\d+$/ );
    $query .= " offset $offset " if ( $offset && $offset =~ /^\d+$/ );

    my @args;
    push @args, $user_id if $user_id;
    return $this->{obvius}->execute_select( $query, @args );
}

sub document_count {
    my ( $this, $user ) = @_;
    my $query = 'select count(*) as c from documents_backup';

    $user = $this->{obvius}->get_userid($user);
    $user = undef if defined $user && $this->can_access_all($user);

    my ( @where, @args );
    if ($user) {
        push @where, 'delete_user = ?';
        push @args,  $user;
    }

    if (@where) {
        $query .= ' where ' . ( join ' and ', @where );
    }

    return $this->{obvius}->execute_select( $query, @args )->[0]->{c};
}

sub get_document {
    my ( $this, $docid ) = @_;
    my $docs =
      $this->{obvius}
      ->execute_select( 'select * from documents_backup where id=?', $docid );
    return @{$docs} ? $docs->[0] : undef;
}

sub restore_document {
    my ( $this, $docid, $destination, %options ) = @_;
    my $dest_docid =
      ref $destination ? $destination->param('id') : $destination;
    my $recursive = $options{recursive};
    my $user      = $options{user};

    my $doc = $this->get_document($docid);
    die "Ukendt dokument: $docid" if !$doc;

    if ( $user && !$this->can_access_document( $user, $doc ) ) {
        die "Ingen adgang til dokument: $docid";
    }

    my $dest_doc = $this->{obvius}->get_doc_by_id($dest_docid);
    die 'Destination findes ikke' if !$dest_doc;
    die 'Kan ikke skabe et dokument der'
      if ( !$this->{obvius}->can_create_new_document($dest_doc) );

    my $dest_children = $this->{obvius}->get_docs_by_parent($dest_docid);
    my $dest_name     = $doc->{name};
    my $test_cand     = $dest_name;
    my %dest_names    = map { $_->param('name') => 1 } @$dest_children;
    my $count         = 0;

    while ( $dest_names{$test_cand} ) {
        $test_cand = $dest_name . '_restore' . ( $count > 0 ? $count : '' );
        $count++;
    }

    $doc->{name} = $test_cand;
    $this->{obvius}->db_begin if ( !$options{notransaction} );

    eval {
        my $query = qq|
            insert into documents (
                id, parent, name, type, owner, grp, accessrules
            )
            values
                (?, ?, ?, ?, ?, ?, ?)
        |;
        $this->{obvius}
          ->execute_command( $query, $doc->{id}, $dest_docid, $doc->{name},
            $doc->{type}, $doc->{owner}, $doc->{grp}, $doc->{accessrules} );
        $this->{obvius}->execute_command(
            q|
            insert into versions (
                docid, version, type, public, valid, lang, user
            )
            select
                docid, version, type, public, valid, lang, user
            from
                versions_backup
            where
                docid=?
            |,
            $doc->{id}
        );
        $this->{obvius}->execute_command(
            q|
            insert into vfields(
                 `docid`, `version`, `name`, `text_value`,
                 `int_value`,`double_value`, `date_value`
            )
            select
                 `docid`, `version`, `name`, `text_value`,
                 `int_value`,`double_value`, `date_value`
            from vfields_backup
            where docid=?
            |, $doc->{id}
        );

        $this->{obvius}
          ->execute_command( 'delete from documents_backup where id=?',
            $doc->{id} );
        $this->{obvius}
          ->execute_command( 'delete from versions_backup where docid=?',
            $doc->{id} );
        $this->{obvius}
          ->execute_command( 'delete from vfields_backup where docid=?',
            $doc->{id} );
        if ($recursive) {
            my $children =
              $this->{obvius}->execute_select(
                'select id from documents_backup where parent=?',
                $doc->{id} );
            for my $child (@{$children}) {
                $this->restore_document(
                    $child->{id}, $doc->{id},
                    recursive     => $recursive,
                    notransaction => 1
                );
            }
        }
    };

    if ($@) {
        die $@ if ( $options{notransaction} );
        $this->{obvius}->db_rollback;
        warn $@;
        die
'Fejl i database. Måske har du ikke ret til at genskabe alle dokumenter rekursivt.';
    }
    $this->{obvius}->db_commit if ( !$options{notransaction} );

    return $this->{obvius}->get_doc_by_id( $doc->{id} );
}

42;
