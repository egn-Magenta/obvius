package Obvius::DocType::Newsbox;

########################################################################
#
# Newsbox.pm - document type handling lists of news; documents
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

# $Id$

use strict;
use warnings;

use POSIX qw(strftime);

use Obvius;
use Obvius::DocType;

use Carp;

our @ISA = qw( Obvius::DocType );
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

# action - looks at the mode-parameter to determine what to do; puts
#          stuff on the output-object for the template-system to use;
#          returns OBVIUS_OK unless something fatal happened.
sub action {
    my ($this, $input, $output, $doc, $vdoc, $obvius) = @_;
    return OBVIUS_OK unless ($input->param('is_admin'));

    my $mode=$input->param('mode') || '';

    $mode='add' if ($input->param('add_item'));

    if ($mode eq 'change_type') {
        $this->change_type($input, $output, $doc, $obvius);
        $this->display($input, $output, $doc, $vdoc, $obvius);
    }
    else {
        my $current_type=$this->get_newsbox_type($doc, $obvius);
        $output->param(type=>$current_type);
    }

    if ($mode eq 'change_placements') {
        $this->change_placements($input, $output, $doc, $obvius);
        $this->display($input, $output, $doc, $vdoc, $obvius);
    }
    elsif ($mode eq 'move_up') {
        $this->move_up($input, $output, $doc, $vdoc, $obvius);
        $this->display($input, $output, $doc, $vdoc, $obvius);
    }
    elsif ($mode eq 'move_down') {
        $this->move_down($input, $output, $doc, $vdoc, $obvius);
        $this->display($input, $output, $doc, $vdoc, $obvius);
    }
    elsif ($mode eq 'delete') {
        $this->delete_entry($input, $output, $doc, $vdoc, $obvius);
        $this->display($input, $output, $doc, $vdoc, $obvius);
    }
    elsif ($mode eq 'add') {
        $this->change_placements($input, $output, $doc, $obvius);
        $this->add($input, $output, $doc, $obvius);
        $this->display($input, $output, $doc, $vdoc, $obvius);
    }
    elsif ($mode eq 'change_type') {
        # NOP; just recognize this mode as valid...
    }
    else {
        $this->display($input, $output, $doc, $vdoc, $obvius);
        if ($mode) {
            $output->param(status=>'WARNING');
            $output->param(message=>'Unknown mode');
        }
    }

    return OBVIUS_OK;
}

sub delete_entry {
    my ($this, $input, $output, $doc, $vdoc, $obvius)=@_;

    my $newsitem_num=$input->param('newsitem');
    my $index=$newsitem_num-1;

    my $entries=$this->find_newsbox_entries($doc, $vdoc, $obvius);

    return 0 unless ($index>=0 and $index<scalar(@$entries));

    my $start=0;
    my $before=$index-1;
    my $after=$index+1;
    my $end=scalar(@$entries)-1;
    if ($index eq $end) {
        $after=0; $end=-1; # Removing the last one
    }

    my @new_entries=@$entries[$start..$before,$after..$end];

    $this->delete_news($doc, $obvius);
    $this->create_news(\@new_entries, $obvius);

    $output->param(message=>[ '"', $entries->[$index]->{vdoc}->Title, '" ', 'removed' ]);
}

sub _swap {
    my ($this, $num1, $num2, $entries, $doc, $obvius)=@_;

    return 0 unless ($num1>=0 and $num1<scalar(@$entries) and
                     $num2>=0 and $num2<scalar(@$entries));

    # Swap seq:
    my $entry1=$entries->[$num1];
    my $entry2=$entries->[$num2];

    my $tmp=$entry1->{seq};
    $entry1->{seq}=$entry2->{seq};
    $entry2->{seq}=$tmp;

    $this->delete_news($doc, $obvius);
    $this->create_news($entries, $obvius);

    return 1;
}

sub move_up {
    my ($this, $input, $output, $doc, $vdoc, $obvius)=@_;

    my $newsitem_num=$input->param('newsitem');
    if ($newsitem_num eq '1') {
        $output->param(status=>'WARNING');
        $output->param(message=>"Can't move top item up, sorry");
        return 0;
    }

    my $entries=$this->find_newsbox_entries($doc, $vdoc, $obvius);

    if ($this->_swap($newsitem_num-2, $newsitem_num-1, $entries, $doc, $obvius)) {
        $output->param(message=>[ '"', $entries->[$newsitem_num-1]->{vdoc}->Title, '" ', 'moved up' ]);
    }
}

sub move_down {
    my ($this, $input, $output, $doc, $vdoc, $obvius)=@_;

    my $newsitem_num=$input->param('newsitem');
    my $entries=$this->find_newsbox_entries($doc, $vdoc, $obvius);

    if ($newsitem_num eq scalar(@$entries)) {
        $output->param(status=>'WARNING');
        $output->param(message=>"Can't move last item down, sorry");
        return 0;
    }

    if ($this->_swap($newsitem_num, $newsitem_num-1, $entries, $doc, $obvius)) {
        $output->param(message=>[ '"', $entries->[$newsitem_num-1]->{vdoc}->Title, '" ', 'moved down' ]);
    }
}

sub add {
    my ($this, $input, $output, $doc, $obvius)=@_;

    my $path=$input->param('path');
    if ($path) {
        if ($this->_add_newsbox({ path=>$path }, $output, $doc, $obvius)) {
            # Great
        }
        else {
            $output->param(path=>$path); # Pass path for redisplay
        }
    }
}

sub change_placements {
    my ($this, $input, $output, $doc, $obvius)=@_;

    # First, get hold of the incoming data:
    my %new_data=();
    foreach my $newsitem (grep { /^NEWSITEM_/ } $input->param()) {
        if ($newsitem=~/^NEWSITEM_(\d+)$/) {
            if ($input->param($newsitem)) {
                $new_data{$1}={ newsboxid=>$doc->Id, docid=>$input->param($newsitem) };
            }
        }
    }

    foreach my $incoming ($input->param()) {
        if ($incoming=~/^(START|END)_(\d+)$/) {
            if ($input->param($incoming)) {
                $new_data{$2}->{lc($1)}=$input->param($incoming);
            }
        }
    }

    #  calculate seq (high is first, remember?):
    my $i=1;
    foreach my $no (sort { $b <=> $a } keys %new_data) {
        $new_data{$no}->{seq}=$i;
        $i++;
    }

    # Then delete all the old data:
    $this->delete_news($doc, $obvius);

    # And finally create the new from incoming:
    $this->create_news([map { $new_data{$_} } keys %new_data], $obvius);

    $output->param(message=>'Changes to box saved');
}

# change_type - when the user changes the type of sort, this method is
#               called, updating the type of the newsbox. A message is
#               set on the output-object for the template system to
#               display, and status is also set if something went
#               front. The new type is passed too.
sub change_type {
    my ($this, $input, $output, $doc, $obvius)=@_;

    my $type=$input->param('type');
    return undef unless $type;

    my $current_type=$this->get_newsbox_type($doc, $obvius);
    if ($current_type) {
        if ($current_type eq $type) { # Hah, no change
            $output->param(message=>'Type updated');
            $output->param(type=>$type);
            return 1;
        }

        my $ret=$this->update_newsbox_type($doc, $type, $obvius);
        if ($ret) {
            $output->param(message=>'Type updated');
            $output->param(type=>$type);
        }
        else {
            $output->param(message=>'Could not update type');
            $output->param(type=>$current_type);
            $output->param(status=>'ERROR');
        }
        return $ret;
    }
    else {
        my $ret=$this->create_newsbox_type($doc, $type, $obvius);
        if ($ret) {
            $output->param(message=>'Type registered');
            $output->param(type=>$type);
        }
        else {
            $output->param(message=>'Could not register type');
            $output->param(status=>'ERROR');
        }
        return $ret;
    }
}

sub _add_newsbox {
    my ($this, $ident, $output, $doc, $obvius)=@_;

    my $success=0;
    my $title='Document';

    my $new_news_doc;
    $new_news_doc=$obvius->get_doc_by_id($ident->{docid}) if ($ident->{docid});
    $new_news_doc=$obvius->lookup_document($ident->{path}) if ($ident->{path});

    my $new_news_vdoc;
    $new_news_vdoc=$obvius->get_public_version($new_news_doc) ||
        $obvius->get_latest_version($new_news_doc) if ($new_news_doc);
    if ($new_news_vdoc) {
        $obvius->get_version_fields($new_news_vdoc, [qw(title expires)]);
        $title='"' . $new_news_vdoc->Title . '" ';
        if ($this->create_newsbox(
                                  {
                                   newsboxid=>$doc->Id,
                                   docid=>$new_news_doc->Id,
                                   start=>strftime('%Y-%m-%d %H:%M:%S', localtime),
                                   end=>$new_news_vdoc->field('expires') || '9999-11-11 11:11:11',
                                  },
                                  $obvius)) {
            $success=1;
        }
    }

    if ($success) {
        $output->param(message=>[$title, ' ', 'added to box']);
    }
    else {
        $output->param(status=>'WARNING');
        $output->param(message=>[$title, ' ', 'could not be added to box']);
    }

    return $success;
}

# display - used to display the current newsbox type and content; the
#           output object is populated with type, entries and if there
#           is a docid on the input-object also new_doc/new_vdoc.
sub display {
    my ($this, $input, $output, $doc, $vdoc, $obvius)=@_;

    my $type=$this->get_newsbox_type($doc, $obvius);
    $output->param(type=>$type);

    # If a new document is passed, it's because we want to add it:
    $this->_add_newsbox({ docid=>$input->param('docid') }, $output, $doc, $obvius) if ($input->param('docid'));

    my $entries=$this->find_newsbox_entries($doc, $vdoc, $obvius);
    $output->param(entries=>$entries);
}

##
## Methods called from mason-components; utility-functions:
##

sub get_entries_vdocs {
    my ($this, $url, $obvius)=@_;

    my $vdocs=[];

    my $newsbox_doc=$obvius->lookup_document($url);
    carp "Newsbox on $url not found" unless ($newsbox_doc);
    my $newsbox_vdoc;
    $newsbox_vdoc=$obvius->get_public_version($newsbox_doc) if ($newsbox_doc);
    carp "Newsbox on $url not public" unless ($newsbox_vdoc);

    my $entries;
    $entries=$this->find_newsbox_entries($newsbox_doc, $newsbox_vdoc, $obvius) if ($newsbox_vdoc);
    carp "Entries for newsbox on $url not found" unless ($entries);

    $vdocs=[ map { $_->{vdoc} } @$entries ] if ($entries);

    return $vdocs;
}

##
## Internal methods:
##

# find_newsbox_entires - given a doc/vdoc returns an array-ref with
#                        hash-refs of the entries (including doc and
#                        vdoc-objects) in the newsbox defined by the
#                        doc/vdoc. The entries are sorted according to
#                        type. Returns an empty array-ref if there is
#                        nothing in the newsbox.
#                        Please note that all entries are returned -
#                        it's up the the caller to limit to
#                        max_entries from the vdoc when displaying.
sub find_newsbox_entries {
    my ($this, $doc, $vdoc, $obvius)=@_;

    $obvius->get_version_fields($vdoc, [qw(max_entries show_date show_teaser)]);

    my $type=$this->get_newsbox_type($doc, $obvius);

    my %data_options=(
                 'where'=>'newsboxid=' . $doc->Id,
                );
    $data_options{'sort'}='seq DESC' if ($type eq 'manual_placement');

    my $table_entries=$obvius->get_table_data('news', %data_options);

    # Find public vdocs, and set before_start/expired:
    my $now=strftime('%Y-%m-%d %H:%M:%S', localtime);
    my @entries=grep { defined } map {
        my $entry_doc=$obvius->get_doc_by_id($_->{docid});
        my $entry_vdoc;
        $entry_vdoc=$obvius->get_public_version($entry_doc) if ($entry_doc);
        my %info;
        if ($entry_doc and !$entry_vdoc) {
            $info{not_public}=1;
            $entry_vdoc=$obvius->get_latest_version($entry_doc);
        }
        $info{before_start}=1 if ($_->{start} gt $now);
        $info{expired}=1 if ($_->{end} lt $now);
        $entry_vdoc ? { %info, %$_, doc=>$entry_doc, vdoc=>$entry_vdoc } : undef;
    } @$table_entries;

    # What fields do we need to retrieve?
    my @fields=qw(title);
    push @fields, 'docdate' if ($type ne 'manual_placement' or $vdoc->field('show_date'));
    push @fields, 'teaser' if ($vdoc->field('show_teaser'));
    map { $obvius->get_version_fields($_->{vdoc}, \@fields) } @entries;

    # If sort isn't manual_placement, sort by docdate:
    if ($type ne 'manual_placement') {
        @entries=sort {
            my $cmp=$a->{vdoc}->field('docdate') cmp $b->{vdoc}->field('docdate');
            $cmp=-$cmp if ($type eq 'reverse_chronological'); # Reverse sort
            $cmp=$a->{vdoc}->Title cmp $b->{vdoc}->Title if ($cmp==0);
            $cmp;
        } @entries;
    }

    return \@entries;
}

##
## Access to the newsboxes and news-tables:
##

# get_newsbox_type - given a document-object for a Newsbox-document,
#                    returns the type of that Newsbox - or undef if no
#                    type is registred.
sub get_newsbox_type {
    my ($this, $doc, $obvius)=@_;

    my $rec=$obvius->get_table_record('newsboxes', { docid=>$doc->Id });

    return defined $rec ? $rec->{type} : undef;
}

# update_newsbox_type - given a document-object for a Newsbox-document
#                       and a string containing a valid type, updates
#                       that Newsbox-documents type.
sub update_newsbox_type {
    my ($this, $doc, $type, $obvius)=@_;

    return $obvius->update_table_record('newsboxes', { docid=>$doc->Id, type=>$type }, { docid=>$doc->Id });
}

# create_newsbox_type - given a Newsbox-document object and a string
#                       containing a type, creates an entry that
#                       registers the type for the Newsbox.
sub create_newsbox_type {
    my ($this, $doc, $type, $obvius)=@_;

    return $obvius->insert_table_record('newsboxes', { docid=>$doc->Id, type=>$type });
}


# get_newsboxes - given a document-object, returns an array-ref of
#                 hash-refs to the newsboxes the document is put
#                 on. If it is not active on any, and empty array-ref
#                 is returned.
sub get_newsboxes {
    my ($this, $doc, $obvius)=@_;

    return $obvius->get_table_data('news', where=>'docid=' . $doc->Id);
}

# delete_newsboxes - given a document-object, deletes all the related
#                    newsitems. Returns false if there was nothing to
#                    delete, and on error.
sub delete_newsboxes {
    my ($this, $doc, $obvius)=@_;

    return $obvius->delete_table_record('news', { docid=>$doc->Id }, { docid=>$doc->Id });
}

# replace_newsboxes - given a document-object and an array-ref
#                     containing hash-refs to newsitems that are to
#                     replace the existing ones.
#                     Returns true if there were no errors, returns
#                     false if anything failed.
sub replace_newsboxes {
    my ($this, $doc, $newsboxes, $obvius)=@_;

    $this->delete_newsboxes($doc, $obvius);
    my $error=0;
    my $ret;
    foreach my $newsbox (@$newsboxes) {
        $ret=$this->create_newsbox($newsbox, $obvius);
        $error++ unless (defined $ret);
    }

    return ($error ? 0 : 1);
}

# create_newsbox - given a hash-ref containing newsboxid, docid,
#                  start, end and optionally a seq adds that
#                  information to the database. If seq isn't given,
#                  the max seq is determined and the seq used is then
#                  one higher.
#                  Because high value means first, it is easy to add
#                  items to the top of the newsbox - just call this
#                  without seq, and badaboom.
#                  Returns undef on error/failure.
sub create_newsbox {
    my ($this, $newsbox, $obvius)=@_;

    if (!exists $newsbox->{seq}) { # Calculate seq
        # Find max seq, add one, use that (possibly problematic; no locking):
        $newsbox->{seq}=$this->get_max_seq($newsbox->{newsboxid}, $obvius)+1;
    }

    return $obvius->insert_table_record('news', $newsbox);
}

# get_max_seq - given a numerical newsboxid, finds the maximum
#               seq-value and returns it. If no maximum-value is
#               found, 0 is returned.
sub get_max_seq {
    my ($this, $newsboxid, $obvius)=@_;

    my $max_newsitem=$obvius->get_table_data('news',
                                             where=>'newsboxid=' . $newsboxid,
                                             max=>1,
                                             sort=>'seq DESC');

    return (scalar(@$max_newsitem) ? $max_newsitem->[0]->{seq} : 0);
}


# delete_news - given a Newsbox document-object, deletes all the
#               newsitems that are on that newsbox.
sub delete_news {
    my ($this, $doc, $obvius)=@_;

    return $obvius->delete_table_record('news', { newsboxid=>$doc->Id }, { newsboxid=>$doc->Id });
}

# create_news - given an array-ref to hash-refs with newsitem data,
#               creates those newsitems in the database.
sub create_news {
    my ($this, $entries, $obvius)=@_;

    foreach my $entry (@$entries) {
        $this->create_newsbox($entry, $obvius);
    }
}

1;
__END__

=head1 NAME

Obvius::DocType::Newsbox - Perl module that implements handling of a newsbox.

=head1 SYNOPSIS

  used automatically.

  # The internal methods are relevant for use from the administration
  # system, like this:

  #  First obtain a Newsbox-document type object (you should
  #  complain/abort if it does not exist):
  my $newsbox_doctype=$obvius->get_doctype_by_name('Newsbox');
  #  Then you can call methods - remember to pass the obvius object:
  $newsbox_doctype->create_newsbox(\%newsbox_hash, $obvius);

=head1 DESCRIPTION

This module provides the methods used when interacting with a document
of the type Newsbox and also provides the necessary internal methods
for the administration system/public system to use for
administrating/displaying the newsbox-system

=head1 AUTHOR

Adam Sjøgren, E<lt>asjo@magenta-aps.dkE<gt>

=head1 SEE ALSO

L<Obvius::DocType>.

=cut
