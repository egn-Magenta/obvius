package Obvius::Queue;

########################################################################
#
# Queue.pm - Queue and order-handling for Obvius.
#
# Copyright (C) 2004 Magenta Aps, Denmark (http://www.magenta-aps.dk/)
#
# Authors: Adam Sjøgren (asjo@magenta-aps.dk),
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2, or (at your option)
# any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software Foundation,
# Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
#
########################################################################

use strict;
use warnings;

use Data::Dumper; # Not for debugging.
use POSIX qw(strftime);

our $VERSION="1.0";

# XXX XXX CHECK THAT USER IS USED (duh) CORRECTLY:

# send_order - receives an order and either stores it or performs is
#              depending on the date. The info hash can have these
#              entries:
#                 date    - when to perform the order (if not given or in the past: now).
#                 docid   - identifies the document [mandatory]
#                 user    - identifies the orderer [mandatory]
#                 command - idenfifies the command to perform [mandatory]
#                 args    - hash-ref with arguments, if necessary.
#              Returns a status, message-pair.
sub send_order {
    my ($obvius, %info)=@_;

    die unless (defined $info{docid});
    die unless (defined $info{user});
    die unless (defined $info{command});

    if (defined $info{date}) {
        # XXX Syntax-check date

        # Check whether is is before or after now (with a fuzz of 3 minutes):
        my $now=strftime('%Y-%m-%d %H:%M:%S', localtime(time()+3*60));

        if ($now ge $info{date}) {
            return $obvius->perform_order(%info);
        }
        else {
            return $obvius->store_order(%info);
        }
    }
    else {
        # Do it now:
        return $obvius->perform_order(%info);
    }
}

# perform_order - performs the order specified by the supplied hash
#                 (see send_order). Returns a status, message-pair.
#                 Used internally.
sub perform_order {
    my ($obvius, %info)=@_;

    if ( $info{command} =~ /^SPECIAL:\s+([a-zA-Z][a-zA-Z0-9_]*(::[a-zA-Z][a-zA-Z0-9_]*)*)$/ ) {
	##### Specific module - instantiate and call method from args on it
	my $module = $1;
	my $file = $module . '.pm';
	$file =~ s|::|/|g;
	
	eval {
	    require "$file";
	};
	if ( $@ ) {
	    return ('ERROR', [ 'Unknown cmd-module', ' "', "$module", '" system-err (', $!, ')' ]);
	}
	else {
	    my $method = $info{args}->{method};
	    my $cmdobj = new $module();
	    
	    if ( $cmdobj->can($method) ) {
		return $cmdobj->$method($obvius, $info{docid}, \%info);
	    } 
	    else {
		return ('ERROR', [ 'Unknown command', ' "', "$module->$method", '"' ]);
	    }
	}
    } 
    else {
        ##### Old fashion command - do as always
	my $order_method='perform_command_' . $info{command};
	
	if ($obvius->can($order_method)) {
	    return $obvius->$order_method(%info);
	}
	else {
	    return ('ERROR', [ 'Unknown command', ' "', $info{command}, '"' ]);
	}
    }
}

sub flatten {
    my ($structure)=@_;

    my $dumper=Data::Dumper->new([$structure], [qw(args)]);
    return $dumper->Dump;
}

sub blowup {
    my ($string)=@_;

    my $args;
    eval $string;
    warn $@ if ($@);

    return $args;
}

# store_order - stores the order specified by the supplied hash (see
#               send_order) for later execution. Returns a status,
#               message-pair.
#               Used internally.
#               TODO: Kick off an at-job, that processes the queue on $info{date}!
sub store_order {
    my ($obvius, %info)=@_;

    # Get userid:
    $info{user}=$obvius->get_userid($info{user});

    # Flatten arguments:
    $info{args}=flatten($info{args});

    if (my $queue_id=$obvius->insert_table_record('queue', \%info)) {
        unless($obvius->config->param('use_cron_for_queue')) {
            $info{date}=~/^\s*(\d{4}-\d{2}-\d{2})\s*(\d{1,2}:\d{2})(:\d{2})?\s*$/;
            my $date_part=$1;
            my $time_part=$2;
            local $ENV{PATH}='';
            system "/bin/echo '".
                $obvius->config->param('obvius_dir') . "/bin/perform_order --site " .
                $obvius->config->param('name') . " " . $queue_id . "' | /usr/bin/at '$time_part $date_part'";
        }

        # Notice that we are returning this as a warning, because that
        # will have the side-effect that the command-component won't
        # redirect us to somewhere else (move, rename, for instance),
        # as that is only done on an ok-return.
        # Also it will stand out a little more.

        #return ('WARNING', [ 'Command', ' "', $info{command}, '" ', 'stored for later execution' ]);
        return ('WARNING', [ 'Command', ' ', 'stored for later execution', ' (', $info{date} , ')' ]);
    }
    else {
        return ('ERROR', 'Command not stored');
    }
}

sub get_orders {
    my ($obvius)=@_;
}

########################################################################

sub perform_command_unpublish {
    my ($obvius, %info)=@_;

    my $doc=$obvius->get_doc_by_id($info{docid});
    return ('ERROR', [ 'Could not get document', ' (' . $info{docid} . ')' ]) unless ($doc);
    my $vdoc=$obvius->get_version($doc, $info{args}->{version});
    return ('ERROR', [ 'Could not get version', ' (' . $info{args}->{version} . ')' ]) unless ($vdoc);

    if ($obvius->unpublish_version($vdoc)) {
        return ('OK', ['Version hidden', ' (' . $vdoc->Version . ')']);
    }

    return ('ERROR', ['Could not hide version', ' (' . $vdoc->Version . ')']);
}

sub perform_command_publish {
    my ($obvius, %info)=@_;

    my $doc=$obvius->get_doc_by_id($info{docid});
    return ('ERROR', [ 'Could not get document', ' (', $info{docid}, ')' ]) unless ($doc);
    my $vdoc=$obvius->get_version($doc, $info{args}->{version});
    return ('ERROR', [ 'Could not get version', ' (', $info{args}->{version}, ')' ]) unless ($vdoc);

    #  1) Update publish fields:
    $obvius->get_version_fields($vdoc, 255, 'PUBLISH_FIELDS'); # XXX A method should be added for this...
    my $new_publish_fields=$info{args}->{publish_fields};
    $new_publish_fields=Obvius::Data->new(published=>strftime('%Y-%m-%d %H:%M:%S', localtime)) if (!$new_publish_fields);
    map { $vdoc->publish_field($_=>$new_publish_fields->param($_)) } $new_publish_fields->param();

    #  2) Publish:
    if ($obvius->publish_version($vdoc)) {
        return ('OK', ['Version published', ' (' . $vdoc->Version . ')']);
    }
    else {
        return ('ERROR', ['Could not publish version', ' (' . $vdoc->Version . ')']);
    }
}

sub perform_command_perlscript {
    my ($obvius, %info) = @_;
    my %args = %{$info{args}};
    my $sitebase = $obvius->config->param('sitebase');

    if ($args{script} =~ m{(\.\.)|(&&)|(\|)|((^|\s)/)}) {
        return ('ERROR', ["Will not execute script outside $sitebase"]);
    }
    my $script = $sitebase . $args{script};
    if (-e $script) {
        my @params;
        if ($args{params}) {
            @params = @{$args{params}};
        }
        my $exit_code = system("perl $script", @params);
        if ($exit_code != 0) {
            return ('ERROR', ["$script returned non-zero exit code"])
        }
        return ('OK', ["$script executed"]);
    } else {
        return ('ERROR', ["Did not find script $script"]);
    }
    # TODO: create a view for monitoring job status (see MR 149)
}

# Internal method: _delete_documents_recursive - given a
#                  document-object, recursively deletes all documents
#                  below and the document itself. Calls
#                  _delete_single_document, and returns the return
#                  value from there and the number of deleted
#                  documents.
sub _delete_documents_recursive {
    my ($obvius, $doc)=@_;

    my $count=1;
    my $subdocs=$obvius->get_docs_by_parent($doc->Id) || [];
    foreach my $subdoc (@$subdocs) {
        my ($result, $message, $subcount)=_delete_documents_recursive($obvius, $subdoc);
        $count+=$subcount;
        if ($result ne 'OK') {
            return ($result, $message, $count);
        }
    }
    return (_delete_single_document($obvius, $doc), $count);
}

# Internal method: _delete_single_document - given a document-object,
#                  deletes it. Returns the string 'OK' and an
#                  array-ref with a message if successful. On failure
#                  the string 'ERROR' is returned along with an
#                  array-ref with a message.
sub _delete_single_document {
    my ($obvius, $doc)=@_;

    my $ret=undef;
    eval {
        $ret=$obvius->delete_document($doc);
    };
    my $error=$@;
    if ($error) {
        $obvius->log->notice("Error when deleting: $error");
        $ret=undef;
    }

    if ($ret) {
        return ('OK', [ 'The document', ' "', $doc->Name, '" ', 'has been deleted' ]);
    }

    return ('ERROR', [ 'Could not delete document ', $doc->Name ]);
}

sub perform_command_delete {
    my ($obvius, %info)=@_;

    my $doc=$obvius->get_doc_by_id($info{docid});
    return ('ERROR', [ 'Could not get document', ' (', $info{docid}, ')' ]) unless ($doc);

    if ($info{args}->{recursive}) {
        my ($status, $message, $count)=_delete_documents_recursive($obvius, $doc);
        if ($status eq 'OK') {
            # This manipulation depends on the message set by _delete_single_document above.
            $message=[ @$message[0..3], ' and ', $count-1, ' subdocuments', ' ', $message->[4] ];
        }
        return ($status, $message);
    }
    else {
        return _delete_single_document($obvius, $doc);
    }
}

sub _copy_documents_recursive {
    my ($obvius, $source_doc, $dest_doc, $new_doc_name, %options)=@_;

    my $count=0;
    my ($result, $message, $new_dest_doc)=$obvius->_copy_single_document(
	$source_doc, $dest_doc, $new_doc_name, %options
    );
    return ($result, $message, $count) if ($result ne 'OK');
    $count++;

    my $subdocs=$obvius->get_docs_by_parent($source_doc->Id) || [];
    foreach my $subdoc (@$subdocs) {
        my ($result, $message, $subcount)=_copy_documents_recursive(
	    $obvius, $subdoc, $new_dest_doc, $subdoc->Name, %options
	);
        $count+=$subcount;
        if ($result ne 'OK') {
            return ($result, $message, $count);
        }
    }
    my $dest_uri=$obvius->get_doc_uri($new_dest_doc);
    #                                                                           XXX Prefix?
    my $source_vdoc=$obvius->get_public_version($source_doc) || $obvius->get_latest_version($source_doc);
    $obvius->get_version_fields($source_vdoc, ['title']);
    return('OK', ['The page', ' "' . $source_vdoc->field('title') . '" ', 
		  '(and all its subdocuments) has been copied successfully to', 
		  " <a href=\"/admin$dest_uri\">$dest_uri</a> "], $count);
}

sub _copy_single_document {
    my ($obvius, $source_doc, $dest_doc, $new_doc_name, %options) = @_;
    $new_doc_name ||= $source_doc->Name;

    if(my $new_lang = $options{change_langauge_to}) {
	die "Invalid language '$new_lang'" unless($new_lang =~ m!^\w\w$!);
    }

    my $source_vdoc=$obvius->get_public_version($source_doc) ||
        $obvius->get_latest_version($source_doc);

    $obvius->get_version_fields($source_vdoc, 255);
    my $source_title = $source_vdoc->field('title');
    if ($options{new_title}) {
        $source_vdoc->field('title', $options{new_title});
    }

    my $error ='';

    my ($new_docid, $new_version)=$obvius->create_new_document(
	$dest_doc, $new_doc_name, $source_vdoc->Type,
	$options{change_language_to} || $source_vdoc->Lang,
	$source_vdoc->Fields, $source_doc->Owner,
	$source_doc->Grp, \$error
    );

    if ($new_docid) {
        my $new_doc=$obvius->get_doc_by_id($new_docid);
        my $dest_uri=$obvius->get_doc_uri($new_doc);
        #                                                                           XXX Prefix?
        return('OK', ['The page', ' "' . $source_title . '" ',
		      'has been copied successfully to', 
		      " <a href=\"/admin$dest_uri\">$dest_uri</a> "], $new_doc);
    }
    else {
        return('ERROR', ['Copy of', 
			 ' ' . $obvius->get_doc_uri($source_doc) . ' ', 
			 'to', 
			 ' ' . $obvius->get_doc_uri($dest_doc) . $new_doc_name . '/ ', 
			 'failed']);
     }
}

sub perform_command_copy {
    my ($obvius, %info)=@_;

    my $doc=$obvius->get_doc_by_id($info{docid});
    return ('ERROR', [ 'Could not get document', ' (', $info{docid}, ')' ]) unless ($doc);

    my $destination=$info{args}->{destination};
    my $destdoc=$obvius->lookup_document($destination);
    my $dest_name = $info{args}->{new_name};

    my $dest_uri = '/' . $destination . '/' . $dest_name . '/';
    $dest_uri =~ s{/+}{/}g;

    return ('ERROR', [ 'Could not get destination document', ' (', $destination, ')' ]) unless ($destdoc);

    return ('ERROR', [ 'No permission to create documents under', ' ', $destination ]) unless ($obvius->can_create_new_document($destdoc));

    if ($info{args}->{recursive}) {
        return ('ERROR', ['Can not recursively copy a document underneath itself']) if ($obvius->is_doc_below_doc($destdoc, $doc) or $destdoc->Id eq $doc->Id);

        my ($status, $message)=_copy_documents_recursive(
	    $obvius, $doc, $destdoc, $dest_name, %{ $info{args} }
	);
        if($info{args}->{change_owner_to}) {
            if($obvius->lookup_document($dest_uri)) {
                $obvius->db_chown(
                    $info{args}->{change_owner_to},
                    $info{args}->{change_group_to},
                    uri => $dest_uri,
                    recursive => 1,
                )
            }
        }
        return ($status, $message);
    }
    else {
        my @result = $obvius->_copy_single_document(
	    $doc, $destdoc, $dest_name, %{ $info{args} }
	);
        if($info{args}->{change_owner_to}) {
            my $dest_uri = sprintf('%s/%s/', $destination, $dest_name);
            if(my $d = $obvius->lookup_document($dest_uri)) {
                $obvius->db_chown(
                    $info{args}->{change_owner_to},
                    $info{args}->{change_group_to},
                    docid => $d->Id,
                )
            }
        }
	return @result;
	
    }
}

sub perform_command_rename {
    my ($obvius, %info)=@_;

    my $doc=$obvius->get_doc_by_id($info{docid});
    return ('ERROR', [ 'Could not get document', ' (', $info{docid}, ')' ]) unless ($doc);

    if ($obvius->rename_document($doc, $info{args}->{new_uri})) {
        return ('OK', ['Document renamed']);
    }

    return ('ERROR', 'Could not rename document');
}

sub perform_command_move {
    my ($obvius, %info)=@_;

    my $doc=$obvius->get_doc_by_id($info{docid});
    return ('ERROR', [ 'Could not get document', ' (', $info{docid}, ')' ]) unless ($doc);
    my $parent=$obvius->get_doc_by_id($doc->Parent);
    my $parent_uri=$obvius->get_doc_uri($parent);

    my $dest_uri=$info{args}->{new_uri};
    my $prefix='/admin'; # XXX This is a little ugly.
    if ($obvius->rename_document($doc, $dest_uri)) {
	# Change language for if requested
	if(my $chlang = $info{args}->{change_language_to}) {
	    $obvius->db_chlang($chlang, uri => $dest_uri, recursive => 1);
	}

	if(my $owner = $info{args}->{change_owner_to}) {
            my $group = $info{args}->{change_group_to};
            $obvius->db_chown(
                $owner, $group, uri => $dest_uri, recursive => 1
            );
	}

        return ('OK',
                [
                 'Document moved from',
                 " <a href='$prefix$parent_uri'>$parent_uri</a>" . $doc->Name . " ",
                 'to',
                 " $dest_uri/ ",
                 '(here)',
                ]);
    }



    return ('ERROR', 'Could not move document');
}

sub perform_command_new_version {
    my ($obvius, %info)=@_;

    my $doc=$obvius->get_doc_by_id($info{docid});
    return ('ERROR', [ 'Could not get document', ' (', $info{docid}, ')' ]) unless ($doc);

    # XXX This command does NOT support delayed execution
    
    if (my $new_version=$obvius->create_new_version($doc, $info{args}->{doctypeid}, $info{args}->{lang}, $info{args}->{fields})) {
        return ('OK', ['New version created', ' (', $new_version, ')'], $new_version);
        # XXX The format of this message is used by admin/action/edit!
    }

    return ('ERROR', 'Could not create new version');
}

sub perform_command_new_document {
    my ($obvius, %info)=@_;

    my $parent=$obvius->get_doc_by_id($info{docid});
    return ('ERROR', [ 'Could not get parent document', ' (', $info{docid}, ')' ]) unless ($parent);

    # XXX This command does NOT support delayed execution
    #  info: docid, user, command, args
    #   args: name, grpid, lang, doctypeid, fields

    my $ret=$obvius->create_new_document($parent, $info{args}->{name}, $info{args}->{doctypeid},
                                         $info{args}->{lang}, $info{args}->{fields},
                                         $obvius->get_userid($info{user}), $info{args}->{grpid});

    if ($ret) {
        return ('OK', ['New document', ' ' . $info{args}->{name} . ' (' . $info{args}->{fields}->param('short_title') || $info{args}->{fields}->param('title'), ') ', 'created under', ' <a href="../">' . ($info{docid} eq $obvius->get_root_document->Id ? '/' : $parent->Name) . '</a>']);
    }

    return ('ERROR', 'Could not create document', ', ', $info{args}->{name});
}

1;
__END__

=head1 NAME

Obvius::Queue - handling the order-queue.

=head1 SYNOPSIS

  use Obvius::Queue;

  $obvius->send_order(); # Performed now
  $obvius->send_order(); # Queued for later execution

=head1 DESCRIPTION

=head2 Delayed execution

Later execution works by using at(1) to start a script at the
specified time. This means that the user the webserver is run as
(usually 'www-data') must be allowed to use at(1). Per default this is
usually prohibited by listing 'www-data' in /etc/at.deny. To enable
queuing, please remove 'www-data' from /etc/at.deny.

=head1 AUTHOR

Adam Sjøgren E<lt>asjo@magenta-aps.dkE<gt>

=head1 SEE ALSO

L<Obvius>, at(1).

=cut
