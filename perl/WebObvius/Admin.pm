package WebObvius::Admin;

########################################################################
#
# Admin.pm - support module for the Obvius administration system
#
# Copyright (C) 2001-2005 Magenta Aps, Denmark (http://www.magenta-aps.dk/)
#                         aparte A/S, Denmark (http://www.aparte.dk/),
#                         FI, Denmark (http://www.fi.dk/)
#
# Authors: Jørgen Ulrik B. Krag (jubk@magenta-aps.dk)
#          Peter Makholm (pma@fi.dk)
#          René Seindal,
#          Adam Sjøgren (asjo@magenta-aps.dk),
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

use WebObvius;

our @ISA = qw( WebObvius );
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

use Apache::Session;
use Apache::Session::File;

use XML::Simple;
use Unicode::String qw(utf8 latin1);


########################################################################
#
#	Set up an editing session:
#
########################################################################

sub prepare_edit {
    my ($this, $req, $doc, $vdoc, $doctype, $obvius) = @_;

    my $session=$this->get_session();
    die "No session available - fatally wounded.\n" unless ($session);

    my $editpages=$obvius->get_editpages($doctype);

    my @pages;
    map {
	my $editpage=$editpages->{$_};
	my %page=(
		  title=>$editpage->Title,
		  help=>'page/' . $editpage->Page,
		  description=>$editpage->Description,
		  comp=>'/edit/edit', # For this particular purpose.
		 );
	$page{fieldlist}=$this->parse_editpage_fieldlist($editpage->Fieldlist, $doctype, $obvius);
	push @pages, \%page;
    } sort {$a <=> $b} grep { /^\d+$/ } keys %$editpages;

    $session->{pages}=\@pages;
    $obvius->get_version_fields($vdoc, 255); # All fields
    #use Data::Dumper;
    # It's not a good idea that fields that are optional and don't have a value are
    # inserted into fields_in as empty fields ('') instead of undef (or not there at all).
    # (this has been fixed in get_version_fields, I think).
    #print STDERR " prepare_edit: " . Dumper($vdoc->{FIELDS});
    $session->{fields_in}=$vdoc->{FIELDS};
    $session->{fields_out}=new Obvius::Data;
    $session->{document}=$doc;
    $session->{version}=$vdoc;
    $session->{doctype}=$doctype;
    $session->{done_comp}='/edit/validate/version';

    my $sessionid=$session->{_session_id};
    $this->release_session($session);

    return $sessionid;
}


########################################################################
#
#	Session handling
#
########################################################################

sub get_session {
    my ($this, $id) = @_;

    my %session;
    eval {
	tie %session, 'Apache::Session::File',
	    $id, { Directory => $this->{EDIT_SESSIONS},
		   LockDirectory => $this->{EDIT_SESSIONS} . '/LOCKS',
		 };
    };
    if ($@) {
	warn "Can't get session data $id: $@\n\t";
	return undef;
    }

    return \%session;
}

sub release_session {
    my ($this, $session) = @_;

    untie %$session;
}


########################################################################
#
#	Translations
#
########################################################################

sub utf8_to_latin1 {
    return utf8(shift || '')->latin1;
}

sub split_language_preferences {
    my ($lang, $default) = @_;

    my %weights;
    for (split(/\s*,\s*/, $lang)) {
        if (/^(.+);\s*q=(.*)/) {
            $weights{$1} ||= int($2*1000);
        } else {
            $weights{$_} ||= $default || 1000;
        }
    }

    return %weights;
}

# read_translations - given a request object, a string with a
#                     file-prefix ("translations"), an optional lang
#                     string and an obvius-object, makes sure that the
#                     translations relevant for the language is on the
#                     site-object (by checking the cache and reading
#                     $file.xml and $file_local.xml on a miss).
#                     The return-value does not signify anything.
#                     Note that the function does not check if the
#                     files have been updated, the only way to
#                     invalidate the cache is to restart Apache.
sub read_translations {
    my ($this, $r, $file, $lang, $obvius) = @_;

    return if($obvius->{TRANSLATIONS});

    my %lang;
    if ($lang =~ /^=/) {
        %lang = split_language_preferences(substr($lang, 1));
    } else {
        if ($r) {
            my $accept_language = $r->headers_in->{'Accept-Language'};
            #print STDERR "Accept-Language = $accept_language\n";
            if ($accept_language) {
                %lang = split_language_preferences($accept_language);

                my @vary;
                push(@vary, $r->header_out('Vary')) if $r->header_out('Vary');
                push @vary, "Accept-Language";
                $r->header_out('Vary', join(', ', @vary));

            }

	    my %site_pref = split_language_preferences($lang, 1);
	    for (keys %site_pref) {
		$lang{$_} ||= $site_pref{$_};
	    }
        }
	
    }

#    for (keys %lang) {
#        print STDERR "LANG WEIGHT $_ => $lang{$_}\n";
#    }

    # If the translation cache-index doesn't exist, create an empty one:
    $r->pnotes('site')->{TRANSLATIONS}={} unless (defined $r->pnotes('site')->{TRANSLATIONS});

    # Determine key to cache-index:
    my $lang_fingerprint=join ":", map { "$_:$lang{$_}" } sort (keys %lang);

    if($r->pnotes('site')->{TRANSLATIONS}->{$lang_fingerprint}) {
        $obvius->{TRANSLATIONS} = $r->pnotes('site')->{TRANSLATIONS}->{$lang_fingerprint};
        return;
    }

    my @path;
    foreach (@{$r->pnotes('site')->{COMP_ROOT}}) {
	foreach my $a ($_) {
	    push @path, $a->[1];
	}
    }

    my $xmldata = eval {
        XMLin($file . ".xml",
              searchpath=>\@path,
              keyattr=>{translation=>'lang'},
              parseropts => [ ProtocolEncoding => 'ISO-8859-1' ]
             );
    };
    if ($@) {
        warn "Translation file $file: XML error: $@";
        return;
    }
    $xmldata->{text}=[$xmldata->{text}] if (ref $xmldata->{text} eq 'HASH');

    # Read the _local.xml if it's there:
    my $local_xmldata = eval {
        XMLin($file . "_local.xml",
              searchpath=>\@path,
              keyattr=>{translation=>'lang'},
              parseropts => [ ProtocolEncoding => 'ISO-8859-1' ]
             );
    };
    unless ($@) {
	if (my $ref=ref $local_xmldata->{text}) {
	    # Merge it:
	    my $local=($ref eq 'HASH' ? [$local_xmldata->{text}] : $local_xmldata->{text});
	    $xmldata->{text}=[ @{$xmldata->{text}}, @{$local} ];
	}
    }

    $obvius->{TRANSLATIONS} = {} unless defined($obvius->{TRANSLATIONS});
    my $translations = $obvius->{TRANSLATIONS};

    for my $text (@{$xmldata->{text}}) {
        next unless ($text->{key});

        my $weight = 0;
        my $language;

        for (keys %lang) {
            if ($lang{$_} > $weight and exists $text->{translation}->{$_}) {
                $weight = $lang{$_};
                $language = $_;
            }
        }

        if (defined $language and exists $text->{translation}->{$language}) {
            my $s = utf8_to_latin1($text->{translation}->{$language}->{content});
            $s =~ tr/{}/<>/;
            $translations->{utf8_to_latin1($text->{key})} = $s;
        } else {
            $obvius->log->debug("Translation file $file: no translation for $text->{key} " .
		(defined $language ? $language : ''));
        }
    }

    $r->pnotes('site')->{TRANSLATIONS}->{$lang_fingerprint} = $translations;
}

1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

WebObvius::Admin - support module for the Obvius administration system.

=head1 SYNOPSIS

  use WebObvius::Admin;

  $admin_site->read_translations($r, $filename, $language, $obvius);

  ...

=head1 DESCRIPTION

WebObvius::Admin contains various support-functions for the
admin-system.

The least simple one is read_translations() that allows the
administration system to read translations from the
XML-files. comp_root is searched for "$filename.xml" and
"$filename_local.xml" - the resulting translations are used (and
cached on a per language-prefs basis (reading it on every hit is very
time consuming)).

Usually you would have a "translations.xml" in the global mason/admin,
and then you could have an optional "translations_local.xml" in
website/mason/admin.

Overriding the global file is possible by placing a "$filename.xml" in
the website dir. (Provided the search-path is searched in the proper
direction).

Because of the caching, changes to the translation files require a
restart of Apache.

=head1 EXPORT

None by default.

=head1 AUTHOR

Jørgen Ulrik B. Krag <lt>krag@aparte.dk<gt>
René Seindal
Adam Sjøgren <lt>asjo@aparte-test.dk<gt>

=head1 SEE ALSO

L<WebObvius::Site>, L<mason/autohandler>.

=cut
