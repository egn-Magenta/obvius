# $Id$

package WebObvius::Template::MCMS;

########################################################################
#
# MCMS.pm - Template class with Obvius-specific callbacks
#
# Copyright (C) 2001-2004 Magenta Aps, Denmark (http://www.magenta-aps.dk/)
#
# Author: René Seindal (rene@magenta-aps.dk),
#         Jørgen Ulrik B. Krag (jubk@magenta-aps.dk),
#         Adam Sjøgren (asjo@magenta-aps.dk)
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

use 5.006;
use strict;
use warnings;

use WebObvius::Template;

our @ISA = qw( WebObvius::Template );
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

use locale;

use WebObvius::Template;

use Apache::Request;
use Apache::Util;
use HTML::Entities;

use HTML::Entities ();

use URI ();
use POSIX qw(strftime);
use Time::Local qw(timelocal);

use Image::Size qw(imgsize html_imgsize);

use XML::Simple;
use Unicode::String qw(utf8 latin1);

use Data::Dumper;

# "##/" is inserted to please the colorcoder of an editor, ignore or delete.


########################################################################
#
#	Utilities
#
########################################################################


sub get_all  { return shift->{PROVIDER}->get_all; }

sub site     { return shift->{PROVIDER}->site; }
sub request  { return shift->{PROVIDER}->request; }
sub obvius   { return shift->{PROVIDER}->obvius; }
sub doc	     { return shift->{PROVIDER}->document; }
sub vdoc     { return shift->{PROVIDER}->version; }
sub doctype  { return shift->{PROVIDER}->doctype; }

sub escape_html {
    my ($string) = @_;

    if (Apache::Util->can('escape_html')) {
	return Apache::Util::escape_html($string);
    }
    else {
	return HTML::Entities::encode($string);
    }
}


########################################################################
#
#	Exporting generic objects and arrays data
#
########################################################################

sub export_object {
    my ($this, $obj, $fields, $fieldmap, $valuemap, %options) = @_;

    $fields ||= [ $obj->param ];
    $fieldmap ||= {};
    $valuemap ||= {};

    for (@{$fields}) {
	my $n = $fieldmap->{$_} || $_;

	unless ($options{no_overwrite} and defined $this->param($n)) {
	    my $v = $obj->param($_);
	    $v = $valuemap->{$_}->($v) if (defined $valuemap->{$_});
	    $this->param($n => $v);
	}
    }
}


sub export_arraydata {
    my ($this, $name, $data, $fields, $postfunc) = @_;

    undef $postfunc unless (ref($postfunc) eq 'CODE');

    my $output = [
		  map {
		      my %d;
		      for my $f (@{$fields}) {
			  $d{$f} = $_->param($f);
		      }
		      $postfunc->(\%d, $_) if ($postfunc);
		      \%d;
		  } @$data
		 ];

    $this->param($name => $output);
    return $output;
}


########################################################################
#
#	General hooks for calculating values
#
########################################################################

sub shorten_common {
    my ($text, $len, $post) = @_;

    return '' unless ($text);
    return $text if (length($text) <= $len);

    $post = '...' unless defined $post;

    substr($text, $len) = '';
    $text =~ s/\W+\w+$/$post/;

    return $text;
}

sub do_shorten_hook {
    my ($this, $name, $len, $post) = @_;

    return escape_html(shorten_common($this->_value_safe($name),
				      $len, $post));
}




########################################################################
#
#	General hooks for managing time/date variables
#
########################################################################

sub db_to_unix {
    my ($dbtime) = @_;

    my ($year, $month, $day, $hour, $min, $sec) =
        ($dbtime =~ m!^(\d\d\d\d)-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d)$!);

    unless (defined $year) {
        ($year, $month, $day) = ($dbtime =~ m!^(\d\d\d\d)-(\d\d)-(\d\d)$!);
        $hour = $min = $sec = 0;
    }

    return undef unless ($year and $month and $day);

    return timelocal($sec, $min, $hour, $day, $month-1, $year-1900);
}

# Use request time if possible, otherwise current time. Cache value.
sub _get_current_time {
    my ($this) = @_;

    return $this->{now} if (defined $this->{now});

    my $req = $this->{PROVIDER}->{REQUEST};
    if ($req) {
	$this->{now} = $req->notes('now');
    } else {
	$this->{now} = POSIX::strftime('%Y-%m-%d %H:%M:%S', localtime);
    }

    return $this->{now};
}

sub do_is_expired_hook {
    my ($this, $n) = @_;
    my $d = $this->_value_safe($n) || '9999-01-01 00:00:00';
    return ($d lt POSIX::strftime('%Y-%m-%d %H:%M:%S', localtime));
}

sub do_date_format_hook {
    my ($this, $n) = @_;
    my $d = $this->_value_safe($n) || '0000-00-00';
    $d = $1 if ($d =~ m/^(\d\d\d\d-\d\d-\d\d)\b/);
    return $d;
}

sub do_time_format_hook {
    my ($this, $n) = @_;
    my $d = $this->_value_safe($n) || '0000-00-00 00:00:00';
    $d = $1 if ($d =~ m/^(\d\d\d\d-\d\d-\d\d \d\d:\d\d):\d\d$/);
    return $d;
}

our %time_periods =
    (
     minute => 60,
     minutes => 60,

     hour => 60*60,
     hours => 60*60,

     day => 24*60*60,
     days => 24*60*60,

     week => 7*24*60*60,
     weeks => 7*24*60*60,

     month => 30*24*60*60,
     months => 30*24*60*60,

     year => 365*24*60*60,
     years => 365*24*60*60,
    );

sub do_time_diff_hook {
    my ($this, $d1, $d2, $period) = @_;

    $d1 = db_to_unix($this->_value_safe($d1) || '0000-00-00 00:00:00');

    if (not $d2 or $d2 eq 'NOW') {
	$d2 = time();
    } else {
	$d2 = db_to_unix($this->_value_safe($d2) || '0000-00-00 00:00:00');
    }

    $period = $time_periods{$period || 'days'} || 1;

    #printf STDERR "d1 %d d2 %d diff %d period %s\n", $d1, $d2, $d2-$d1, $period;

    return int(($d2-$d1)/$period);
}

##/ LANGUAGE SPECIFIC
our %months =
    (
     '01'=>'januar', '02'=>'februar', '03'=>'marts', '04'=>'april',
     '05'=>'maj', '06'=>'juni', '07'=>'juli', '08'=>'august',
     '09'=>'september', '10'=>'oktober', '11'=>'november', '12'=>'december',
    );

##/ LANGUAGE SPECIFIC
sub format_date_helper {
    my ($d, $now) = @_;

    my $year = substr($now, 0, 4);
    if ($d =~ m/^0000-00-00\b/) {
	$d = '';
    } elsif ($d =~ m/^(\d\d\d\d)-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d)$/) {
	$d = sprintf('%d. %s%s kl. %d:%02d',
		     $3, $months{$2}, (($year eq $1) ? '' : " $1"),
		     $4, $5);
    } elsif ($d =~ /^(\d\d\d\d)-(\d\d)-(\d\d)$/) {
	$d = sprintf('%d. %s%s',
		     $3, $months{$2}, (($year eq $1) ? '' : " $1"));
    }
    return $d;
}

sub do_display_date_hook {
    my ($this, $d) = @_;

    return format_date_helper($d, $this->_get_current_time);
}

sub do_display_news_date_hook {
    my ($this, $d1) = @_;

    my $now = $this->_get_current_time;

    my ($y1, $m1, $day1) = ($d1 =~ /^(\d\d\d\d)-(\d\d)-(\d\d)$/);

    my $d2 = substr($now, 0, 10);
    my ($y2, $m2, $day2) = ($d2 =~ /^(\d\d\d\d)-(\d\d)-(\d\d)$/);

    #print STDERR "$d1 <=> $d2\n";
    #print STDERR ((($y1*12)+$m1)*31+$day1), " <=> ", ((($y2*12)+$m2)*31+$day2), "\n";

    if ( (((($y2*12)+$m2)*31+$day2) - ((($y1*12)+$m1)*31+$day1)) < 15) {
	return format_date_helper($d1, $now);
    }
    return '';
}

sub do_display_date_range_hook{
    my ($this, $d1, $d2) = @_;

    my $now = $this->_get_current_time;

    $d1 = substr($this->_value_safe($d1), 0, 10) || '0000-00-00';
    $d2 = substr($this->_value_safe($d2), 0, 10) || '0000-00-00';

    return format_date_helper($d1, $now) if ($d1 eq $d2);

    my ($y1, $m1, $day1) = ($d1 =~ /^(\d\d\d\d)-(\d\d)-(\d\d)$/);
    my ($y2, $m2, $day2) = ($d2 =~ /^(\d\d\d\d)-(\d\d)-(\d\d)$/);

    $day1 += 0;
    $day2 += 0;

    if ($y1 == $y2 and $m1 == $m2) {
	return $day1 . '.-' . format_date_helper($d2, $now);
    } else {
	return (format_date_helper($d1, $now)
		. '-'
		. format_date_helper($d2, $now));
    }
}


########################################################################
#
#	Apache specific hooks
#
########################################################################

sub do_insert_url_hook {
    my ($this, $url) = @_;

    #print STDERR "FETCHING $url\n";

    my $req = $this->{PROVIDER}->{REQUEST};

    my $base = new URI($req->uri, 'http');
    $base->scheme('http');
    $base->host($req->get_server_name);

    if ($url !~ m!^\w+:!) {
	$url = new_abs URI($url, $base)->as_string;
    }

    #print STDERR "FETCHING 2 $url\n";

    my $text = retrieve_uri($url);
    unless ($text) {
	$this->template_error("insert_url failed: $url");
	return '';
    }

    return $text;
}


########################################################################
#
#	HTML generating hooks
#
########################################################################

sub do_urlencode_hook {
    my ($this, $n) = @_;
    return Apache::Util::escape_uri($this->_value_safe($n));
}

sub do_htmlencode_hook {
    my ($this, $n) = @_;
    return escape_html($this->_value_safe($n));
}


########################################################################
#
#	Image-related hooks
#
########################################################################

sub do_insert_image_hook {		# RS 20010806 - ej testet
    my ($this, $image, $alt) = @_;

    return '' unless ($image);

    return html_make_image('IMG', $image,
			   {
			    provider => $this->{PROVIDER},
			    alt => $alt,
			   });
}

sub do_image_size_hook {		# RS 20010806 - ej testet
    my ($this, $img) = @_;

    return html_imgsize($this->req->document_root . $img);
}

sub do_js_image_size_hook {		# RS 20010806 - ej testet
    my ($this, $img) = @_;

    my ($x, $y) = imgsize($this->req->document_root .$img);
    $x += 10;
    $y += 10;
    return "width=$x,height=$y";
}



########################################################################
#
#	Functions for generating HTML and plain-text from the MCMS
#	specific codes.
#
########################################################################/

# Convert L<text; link [; target]> to HTML link
sub html_make_named_anchor {
    my ($tag, $name, $options) = @_;

    return "<a name=\"$name\"></a>";
}

sub ignore {
	return "";
}

sub html_make_link {			# RS 20010806 - ej testet
    my ($tag, $link, $options) = @_;
    my $text;
    my $target;

    # A non-terminated L<> should not make a link, as it can cause problems.
    return $link if ($options->{NOT_TERMINATED});

    $link = HTML::Entities::decode($link);

    my @data = split(';\s*', $link, -1);
    if (scalar(@data) > 1) {
	$text = $data[0];
	$link = $data[1];
	if (defined($data[2])) {
	    $target = $data[2] || '_blank';
	}
    } else {
	$text = $link;
    }

    unless ($link =~ m!^\w+://!) {
	if ($link =~ m!^www\.!) {
	    $link = "http://$link";
	}
	elsif ($link =~ m!^ftp\.!) {
	    $link = "ftp://$link";
	}
	elsif ($link =~ m!\w@\w! and $link !~ /mailto:/) {
	    $link = "mailto:$link";
	}
	elsif ($link =~ m!^javascript:!) {
	    # nop
	}
	elsif (length($link) == 0) {
	    my $server_admin = $ENV{SERVER_ADMIN} || 'webmaster';
	    my $message = 'Sorry, but no destination has been specified for this link!';
	    $link = "javascript:alert('$message\\nPlease notify $server_admin')";
	}
	else {
	    #my $req = $options->{provider}->request;
	    #my $prefix = $req->notes('prefix') || '';
	    #my $uri = $req->uri;

	    $link .= '/' unless ($link =~ /\/$/ or $link =~ /[\#\?]/ or $link =~ /^mailto:/);
	    #$link = "$uri$link" unless ($link =~ m!^/!);
	    $link = "$link" if ($link =~ m!^/!);

            #Remove ending slash for links to docs with an extension
            $link =~ s!\.(\w{2,4})/$!\.$1!;
	}
    }

    if (defined $target) {
	$target = " target=$target";
    } else {
	$target = '';
    }

    return "<a href=\"$link\"$target>$text</a>";

}

# Convert L<text; link [; target]> to "text".

sub text_make_link {
    my ($tag, $link, $options) = @_;
    my $text;
    my $target;

    # A non-terminated L<> should not make a link, as it can cause problems.
    return $link if ($options->{NOT_TERMINATED});

    return (split(';\s*', HTML::Entities::decode($link), -1))[0];
}

sub html_make_image {
    my ($tag, $link, $options) = @_;

    $link = HTML::Entities::decode($link);
    $link =~ s/\" (\w)/\"; $1/g; # XXX Quick'n'dirty
    my ($img, @data) = split (';\s*', $link, -1);
    my %default;
    fill_in_options(\@data, \%default); # These should be considered when imgdoc is found as well...

    my $alt = escape_html($options->{alt} || $img);

    $default{BORDER}=0;
    $default{ALT} ||= $alt;

    #use Data::Dumper;
    #print STDERR " html_make_image: [$tag] [$link] [$img]\n";
    #map { print STDERR "  $_\n" } keys %$options;
    #print STDERR "  default: " . Dumper(\%default);
    #print STDERR "  data: " . Dumper(\@data);

    my $req = (defined $options->{provider}->{request} ? $options->{provider}->{request} : $options->{provider}->request);

    if (-r $req->document_root . $img) {
	my $alt = escape_html($options->{alt} || $img);

	my ($w, $h) = imgsize($req->document_root . $img);
	if (defined($w) and defined($h)) {
	    # print STDERR "STATIC IMAGE $img, $w $h\n";

	    ($default{width}, $default{height})=($w, $h);
	    my @attr = map {
		sprintf('%s="%s"', lc $_, escape_html($default{$_}))
	    } sort {
		$a cmp $b
	    } grep {
		defined $default{$_}
	    } keys %default;

	    return sprintf('<img src="%s" ' . join(' ', @attr)  . '>', $img, $alt);
	}
    }

    my $obvius = (defined $options->{provider}->{obvius} ? $options->{provider}->{obvius} : $options->{provider}->obvius);

    # There might be some GET options on the image_url
    my $img_options = '';
    if($img =~ /^[^\?]+(.*)/) {
      $img_options = $1;
    }
    # Remove ending / in image URL
    my $tmp_replace = $img_options;
    # Escape for regexp use
    $tmp_replace =~ s/\?/\\?/;
    $tmp_replace =~ s/\+/\\+/;
    $img =~ s/\/$tmp_replace$/$img_options/;

    $img = $req->uri . $img unless ($img =~ m!^(/|http[s]?://|ftp://)!);
    my $realimg=$img;
    $realimg =~ s!^/admin/!/!;
    my @path = $obvius->get_doc_by_path($realimg);
    my $imgdoc = $path[-1];

    if ($imgdoc) {
	my $vdoc = $obvius->get_public_version($imgdoc);
	if ($vdoc) {
	    my $fields = $obvius->get_version_fields($vdoc);

	    my %attr = ( src => $img, border => 0 );

	    $attr{width} = $fields->param('width');
	    $attr{height} = $fields->param('height');

	    # XXX Defaults to use some attrs from tag
	    $attr{align} = $default{ALIGN} || $fields->param('align');
	    $attr{alt} = $default{ALT} || $fields->param('title');
	    $attr{hspace} = $default{HSPACE} if($default{HSPACE});
    	    $attr{vspace} = $default{VSAPCE} if($default{VSPACE});


	    if (my $scale = $fields->param('scale')) {
		$attr{width} = int($attr{width} * $scale / 100) if ($attr{width});
		$attr{height} = int($attr{height} * $scale / 100) if ($attr{height});
	    }

	    if($img_options and $img_options =~ /size=(\d+)x(\d+)/i) {
		$attr{width} = $1;
		$attr{height} = $2;
	    }

	    if($default{PICTURETEXT}) {
		# Spacing is half of hspace
		my $spacing = $attr{hspace} || 8;
		$spacing = sprintf("%d", ($spacing / 2));


		# The table provides spacing
		$attr{hspace} = undef;
		$attr{vspace} = undef;

		# And alignment
		my $align = $attr{align} || 'center';
		$attr{align} = undef;

		my @attr = map {
		    sprintf('%s="%s"', lc $_, escape_html($attr{$_}))
		} sort {
		    $a cmp $b
		} grep {
		    defined $attr{$_}
		} keys %attr;

		#print STDERR "DYNAMIC IMAGE WITH TABLE/PICTURETEXT: $img\n";
		return '<table border="0" align="' . $align . '" width="' . $attr{width} . '" cellpadding="' . $spacing . '" cellspacing="0">' .
		        '<tr><td><img ' . join(' ', @attr) . '></td></tr>' .
		        '<tr><td><span class="pictext">' . $default{PICTURETEXT} . '</span></td></tr>' .
		       '</table>';

	    } else {

		my @attr = map {
		    sprintf('%s="%s"', lc $_, escape_html($attr{$_}))
		} sort {
		    $a cmp $b
		} grep {
		    defined $attr{$_}
		} keys %attr;

		# print STDERR "DYNAMIC IMAGE $img\n";
		return '<img ' . join(' ', @attr) . '>';
	    }
	}
    }

    if($default{PICTURETEXT}) {
	# Spacing is half of hspace
	my $spacing = $default{HSPACE} || 8;
	$spacing = sprintf("%d", ($spacing / 2));


	# The table provides spacing
	$default{HSPACE} = undef;
	$default{VSPACE} = undef;

	# And alignment
	my $align = $default{ALIGN} || 'center';
	$default{ALIGN} = undef;

	# Dont print picture text as an attr on the image
	my $picturetext = $default{PICTURETEXT};
	$default{PICTURETEXT} = undef;

	print STDERR "FALL THRU IMAGE WITH TABLE/PICTURETEXT $img\n";
	my @attr = map {
	    sprintf('%s="%s"', lc $_, escape_html($default{$_}))
	} sort {
	    $a cmp $b
	} grep {
	    defined $default{$_}
	} keys %default;
	return '<table border="0" align="' . $align . '" width="' . ($default{WIDTH} || 1) . '" cellpadding="' . $spacing . '" cellspacing="0">' .
	        '<tr><td>' . sprintf('<img src="%s" ' . join(' ', @attr)  . '>', $img, $alt) . '</td></tr>' .
		'<tr><td><span class="pictext">' . $picturetext . '</span></td></tr>' .
		'</table>';


    } else {
	print STDERR "FALL THRU IMAGE $img\n";
	my @attr = map {
	    sprintf('%s="%s"', lc $_, escape_html($default{$_}))
	} sort {
	    $a cmp $b
	} grep {
	    defined $default{$_}
	} keys %default;
	return sprintf('<img src="%s" ' . join(' ', @attr)  . '>', $img, $alt);
    }
}


# Convert IMG<image.xxx> to a suitable text-representation

sub text_make_image {
    my ($tag, $img, $options) = @_;

    return $options->{alt} || '';
}


sub html_make_simple {
    my ($tag, $text) = @_;

    $tag=lc($tag);
    return $text ? "<$tag>$text</$tag>" : '';
}

sub text_make_simple {
    my ($tag, $text) = @_;

    return $text;
}

sub html_make_break {
    my ($tag, $text, $options) = @_;

    return "\n<br>" unless $text;
    $text = lc($text);

    return (($text =~ /^(all|left|right)$/i) ? "\n<br clear=\"$text\">" : "\n<br>");
}

sub text_make_break {
    return "\n\n";
}


sub html_make_header {
    my ($tag, $text, $options) = @_;

    $tag=lc($tag);
    return $text ? "\n<$tag>$text</$tag>\n\n" : '';
}

# add_anchor(anchor, text, tag, options) - adds anchor-name to the
#     hash anchors on pnotes, and anchor-name and text to the list
#     anchorslist on pnotes, for later retrieval by
#     do_make_anchors_hook and do_make_anchors_html_hook. Returns the
#     name of the added anchor.
#
#     add_anchor() is called when an anchor is added or encountered by
#     the HTML-parser run in create_anchorized_content(), triggered by
#     the using one of the related hooks, do_htmlanchorize_hook or
#     do_anchorizehtml_hook.
#
#     If the option FORCE is given, anchors with the same name
#     overwrite eachother (otherwise a number is added to the end of
#     the anchor). (This is used for anchors that aren't added
#     automatically, but are specified by the user in the MCMS-codes).
#
#     Used internally by the module.
#
sub add_anchor {
    my ($req, $anchor, $text, $tag, %options) = @_;
    $tag=lc($tag);

    my $anchors=$req->pnotes('anchors');
    unless ($anchors) { # Make it if it doesn't exist
	$anchors={};
	$req->pnotes('anchors'=>$anchors);
    }
    my $anchorslist=$req->pnotes('anchorslist');
    unless ($anchorslist) {
	$anchors=();
	$req->pnotes('anchorslist'=>$anchorslist);
    }

    my $newanchor=$anchor;

    unless( $options{'FORCE'} ) {
	my $i=1;
	while( ($anchors->{$newanchor}) ) # While already in table, try next name
	{
	    $i++;
	    $newanchor=$anchor . $i;
	}
    }

    $anchors->{$newanchor}=$tag ? $tag : 1; # Not used for anything
    push @{$anchorslist}, { anchor=>$newanchor, subtitle=>$text };

    return $newanchor;
}

sub create_anchor_from_text {
    my ($req, $tag, $text) = @_;
    $tag=lc($tag);

    my $anchor=lc($text);
    my %translit=qw(æ ae ø oe å aa); # Others? General function somewhere?
    map { $anchor=~s/$_/$translit{$_}/ge; } keys(%translit);
    $anchor=~s/[^\d\w]//g;

    return add_anchor($req, $anchor, $text, $tag);
}

sub html_make_header_with_anchor {
    my ($tag, $text, $options) = @_;

    my $anchor = create_anchor_from_text($options->{provider}->request, $tag, $text);

    return $text ? "\n<$tag><a name=\"$anchor\">$text</a></$tag>\n\n" : '';
}

sub text_make_header {
    my ($tag, $text, $options) = @_;

    $tag=lc($tag);
    return '' unless $text;

    my $uline = ($tag eq 'h1'
		 ? '=' x length($text)
		 : ( $tag eq 'h2'
		    ? '-' x length($text)
		    : ''
		   )
		);
    $text .=  "\n$uline" if ($uline);

    return "\n\U$text\E\n\n";
}

sub html_make_paragraph {
    my ($tag, $text, $options) = @_;

    $tag=lc($tag);
    return '' unless ($text and $text !~ /^\s*$/);

    my $c = $options->{pclass} ? " class=$options->{pclass}" : '';
    $text = "<$tag$c>$text</$tag>\n\n";
    $text =~ s/(.{62}.*?) +/$1\n/g unless ($options->{dont_wrap});
    return $text;
}

sub text_make_paragraph {
    my ($tag, $text, $options) = @_;

    return '' unless ($text and $text !~ /^\s*$/);
    return $text . "\n\n";
}

# Make indents

sub html_make_indent {
    my ($tag, $text, $options) = @_;

    return '' unless ($text and $text !~ /^\s*$/);

    my $c = $options->{pclass} ? " class=$options->{pclass}" : '';
    if ($tag eq 'BULLET') {
	$text = "<ul$c compact=\"compact\"><li>$text</li></ul>\n\n";
    } elsif ($tag eq 'SQUARE') {
	$text = "<ul$c type=\"square\" compact=\"compact\"><li>$text</li></ul>\n\n";
    } elsif ($tag eq 'CIRCLE') {
	$text = "<ul$c type=\"circle\" compact=\"compact\"><li>$text</li></ul>\n\n";
    } elsif ($tag eq 'EXDENT' or $tag eq 'HANG') {
	my $hang;
	if ($text =~ /^([^:]+)\s*:\s/s) {
	    $hang = $1;
	    $text =~ s/^[^:]+\s*:\s+//s;
	} else {
	    ($hang, $text) = split(/\s+/, $text, 2);
	}
	$text = "<dl$c><dt>$hang<dd>$text</dl>\n\n";
    } else {
	my $type;
	my $start;

	if ($text =~ /^(\d+)[.: \t]\s/) {
	    $start = $1;
	    $type = '1';
	    $text =~ s/^\d+[.: \t]\s+//;
	} elsif ($text =~ /^([a-z])\.\s/) {
	    $start = ord($1) - ord('a') + 1;
	    $type = 'a';
	    $text =~ s/^.\.\s+//;
	} elsif ($text =~ /^([A-Z])[.: \t]\s/) {
	    $start = ord($1) - ord('A') + 1;
	    $type = 'A';
	    $text =~ s/^.\.\s+//;
	}
	if (defined $start and defined $type) {
	    $text = "<ol$c type=\"$type\" start=\"$start\" compact=\"compact\"><li>$text</li></ol>\n\n";
	} else {
	    $text = "<dl$c><dt><dd>$text</dl>\n\n";
	}
    }
    $text =~ s/(.{62}.*?) +/$1\n/g;
    return $text;
}

sub text_make_indent {
    my ($tag, $text, $options) = @_;

    return '' unless ($text and $text !~ /^\s*$/);
    return $text . "\n\n";
}


# Convert FR<link; width; height; [; EXTRA=10; ANOTHER="whatever" ]> to HTML link

sub fill_in_options {
    my($data, $default)=@_;

    while( my $option=shift @{$data} ) {       # Assumes pretty and wellformed options...
	my($key, $value)=split /=/, $option;
	$key=uc($key);
	$value=$1 if $value=~/^"(.*)"$/;
	$default->{$key}=$value if $key and $value;
    }

}

sub html_make_iframe {
    my ($tag, $link, $options) = @_;

    my %default=(
		 FRAMEBORDER=>0,
		 MARGINWIDTH=>0,
		 MARGINHEIGHT=>0,
		 SCROLLING=>0,
		 WIDTH=>160,
		 HEIGHT=>300,
		);

    $link = HTML::Entities::decode($link);

    my($src, $width, $height, @data) = split(';\s*', $link, -1);
    fill_in_options(\@data, \%default);
    $default{WIDTH}=$width if $width;
    $default{HEIGHT}=$height if $height;

    my $text='<iframe src="' . $src . '"';
    map { $text.=" " . lc($_) . "=\"$default{$_}\"" } keys %default;
    $text.=">";
    # This, or something similar, could be used for browsers that do not grok <IFRAME>:
    # $text.='<A HREF="javascript:OpenWin(\'' . $src . '\');">IFRAME</A>';
    $text.='<a href="' . $src . '">[LINK]</a>';
    $text.="</iframe>\n\n";

    return $text;
}

sub text_make_iframe {
    my ($tag, $link, $options) = @_;

    my %default;

    $link = HTML::Entities::decode($link);

    my ($src, $width, $height, @data) = split(';\s*', $link, -1);
    fill_in_options(\@data, \%default);

    my $text='';
    my($title, $longdesc)=($default{TITLE}, $default{LONGDESC});
    if( $title or $longdesc ) {
	$text= "[";
	$text.=$title if $title;
	$text.=": " if $title and $longdesc;
	$text.=$longdesc if $longdesc;
	$text.="]\n\n";
    }

    return $text; # Should perhaps wrap nicely...?
}

sub format_text {
    my ($text, %options) = @_;

    my $inline_map = $options{inline_elements};
    my $block_map = $options{block_elements};
    my $escape_text_func = $options{escape_text_func};

    my @tokens =
	map {
	    my @res = ( $_ );
	    if ($_ eq "\n") {
		;
	    } elsif (/\n/) {
		if (defined($block_map) and defined($block_map->{P})) {
		    @res = ( [ $block_map->{P} ], 'P<');
		}
	    } elsif (/^([A-Z][A-Z0-9]*)<$/) {
		my $tag = $1;
		if (defined($block_map) and defined($block_map->{$tag})) {
		    @res = ( [ $block_map->{$tag} ], $_);
		}
	    } elsif (length == 0) {
		@res = ();
	    }

	    @res;
	} split(/([A-Z][A-Z0-9]*<|<|>|\n[\n ]*)/, $text);

    if (not ref($tokens[0]) and defined($block_map) and defined($block_map->{P})) {
	unshift(@tokens, [ $block_map->{P} ], 'P<');
    }

    my @output;

    while (@tokens) {
	my @stack;			# stack of unfinished elements
	my @paroutput;			# output of this paragraph so far
	my $current;			# content of current element

	# remove whitespace in front of paragraphs
	while (@tokens and ($tokens[0] eq ''
			    or $tokens[0] eq "\n"
			    or $tokens[0] =~ /^\s+$/)) {
	    shift(@tokens);
	}

	my $token;
	while (defined($token = shift(@tokens))) {
	    #print STDERR "TOKEN «$token»\n";
	    last if (ref $token);

	    if ($token =~ /^([A-Z][A-Z0-9]*)<$/) {
		my $func = $1;
		push(@stack, $current);
		$current = [ $func ];
	    } elsif ($token eq '<') {
		push(@stack, $current);
		$current = [ '<' ];
	    } elsif ($token eq '>' and $current and @$current) {
		my $func = shift(@$current);
		#print STDERR "CALLING $func\n";

		my $handler = $inline_map->{$func};
		my $result = join('', @$current);
		if (defined $handler) {
		    #print STDERR "CALL $func($result)\n";
		    $result = $handler->($func, $result, \%options);
		    #print STDERR "RESULT $func -> $result\n";
		} elsif ($func eq '<') {
		    #print STDERR "CALL < ($result)\n";
		    $result = "<$result>";
		    #print STDERR "RESULT $func -> $result\n";
		} else {
		    #print STDERR "NO FUNCTION FOR $func\n";
		    unshift(@$current, $func);
		    last;
		}

		$current = pop @stack;
		push(@{$current ? $current : \@paroutput}, $result) if ($result);
	    } elsif ($token eq "\n" and defined($inline_map->{BR})) {
		my $handler = $inline_map->{BR};

		#print STDERR "CALL BR()\n";
		$token = $handler->('BR', '', \%options);
		#print STDERR "RESULT BR -> $token\n";

		push(@{$current ? $current : \@paroutput}, $token) if ($token)
	    } elsif ($token) {
		if (defined $escape_text_func) {
		    $token = $escape_text_func->($token);
		}
		push(@{$current ? $current : \@paroutput}, $token);
	    }
	}

	# Clean up the stack for non-finished inline elements
	my $func;
	while (@stack) {
	    $func = shift(@$current);
	    #print STDERR "FINAL CALLING $func\n";

	    my $handler = $inline_map->{$func};
	    my $result = join('', @$current);
	    if (defined $handler) {
		#print STDERR "FINAL CALL $func($result)\n";
		$result = $handler->($func, $result, { NOT_TERMINATED=>1, %options });
		#print STDERR "FINAL RESULT $func -> $result\n";
	    } else {
		#print STDERR "FINAL NO FUNCTION FOR $func\n";
		unshift(@$current, $func);
		last;
	    }

	    $current = pop @stack;
	    push(@{$current ? $current : \@paroutput}, $result) if ($result);
	}

	# Finish the paragraph
	my $result;
	if (defined($block_map)) {
	    $func = shift(@$current) || 'P';
	    #print STDERR "PAR CALLING $func\n";

	    my $handler = $block_map->{$func};
	    $result = join("", @paroutput, @{$current || []});
	    if (defined $handler) {
		#print STDERR "PAR CALL $func($result)\n";
		$result = $handler->($func, $result, \%options);
		#print STDERR "PAR RESULT $func -> $result\n";
	    } else {
		#print STDERR "PAR NO FUNCTION FOR $func\n";
	    }
	} else {
	    $result = join("", @paroutput, @{$current || []});
	}
	push(@output, $result) if ($result);
    }

    #print STDERR "COMPLETE OUTPUT\n", join('', @output), "\nEND COMPLETE OUTPUT\n";

    return join('', @output);
}

my $html_inline_elements = {
			    B=>\&html_make_simple,
			    I=>\&html_make_simple,
			    U=>\&html_make_simple,
			    CODE=>\&html_make_simple,
			    BR=>\&html_make_break,
			    IMG=>\&html_make_image,
			    L=>\&html_make_link,
			    A=>\&html_make_named_anchor,
			    INSERTHTMLDOC=>\&html_make_insert_html_doc,
			   };

my $text_inline_elements = {
			    B=>\&text_make_simple,
			    I=>\&text_make_simple,
			    U=>\&text_make_simple,
			    CODE=>\&text_make_simple,
			    BR=>\&text_make_break,
			    IMG=>\&text_make_image,
			    L=>\&text_make_link,
			    A=>\&ignore,
			    INSERTHTMLDOC=>\&text_make_insert_html_doc,
			   };

my $html_block_elements = {
			   P=>\&html_make_paragraph,
			   H1=>\&html_make_header,
			   H2=>\&html_make_header,
			   H3=>\&html_make_header,
			   H4=>\&html_make_header,
			   H5=>\&html_make_header,
			   H6=>\&html_make_header,
			   FR=>\&html_make_iframe,
			   BULLET=>\&html_make_indent,
			   CIRCLE=>\&html_make_indent,
			   SQUARE=>\&html_make_indent,
			   INDENT=>\&html_make_indent,
			   EXDENT=>\&html_make_indent,
			   HANG=>\&html_make_indent,
		  };

my $html_block_elements_h2_anchors = {
			   P=>\&html_make_paragraph,
			   H1=>\&html_make_header,
			   H2=>\&html_make_header_with_anchor,
			   H3=>\&html_make_header,
			   H4=>\&html_make_header,
			   H5=>\&html_make_header,
			   H6=>\&html_make_header,
			   FR=>\&html_make_iframe,
			  };

my $text_block_elements = {
			   P=>\&text_make_paragraph,
			   H1=>\&text_make_header,
			   H2=>\&text_make_header,
			   H3=>\&text_make_header,
			   H4=>\&text_make_header,
			   H5=>\&text_make_header,
			   H6=>\&text_make_header,
			   FR=>\&text_make_iframe,
			   BULLET=>\&text_make_indent,
			   CIRCLE=>\&text_make_indent,
			   SQUARE=>\&text_make_indent,
			   INDENT=>\&text_make_indent,
			   EXDENT=>\&text_make_indent,
			   HANG=>\&text_make_indent,
			  };



########################################################################
#
#	H2 Anchor hooks
#
########################################################################

sub create_anchorized_content {
    my ($this, $n, $c) = @_;

    my $req = $this->request;

    if( !($req->pnotes('content_with_anchors')) ) { # Create it if it doesn't exist.
	my $acontent=$this->format_text_common($n,
					       $html_inline_elements,
					       $html_block_elements_h2_anchors,
					       escape_text_func => \&escape_html,
					       pclass => $c||'',
					      );
	$req->pnotes('content_with_anchors'=>$acontent);
	return 1;
    }

    return 0;
}

use HTML::Parser ();

sub add_anchor_to_html_start {
    my ($self, $tagname, $attr, $text) = @_;

    if( $tagname eq "h2" ) { # Doesn't handle nested h2's properly
	$self->{'IN_H2'}=1;
    }
    elsif( $tagname eq "a" and ($self->{'IN_H2'}) ) {
	$self->{'HAS_ANCHOR'}=$attr->{'name'};
    }

    $self->{'TEXT'}.=$text;
}

sub add_anchor_to_html_text {
    my ($self, $text) = @_;

    if( $self->{'IN_H2'} ) {
	if( !($self->{'HAS_ANCHOR'}) ) {
	    $self->{'NEW_ANCHOR'}=create_anchor_from_text($self->{'REQUEST'}, 'h2', $text);
	}
	$self->{'ANCHOR_TEXT'}=$text;
    }
    else {
	$self->{'TEXT'}.=$text;
    }
}

sub add_anchor_to_html_end {
    my ($self, $tagname, $text) = @_;

    if( $tagname eq "a" and ($self->{'IN_H2'}) and ($self->{'HAS_ANCHOR'}) ) {
	add_anchor($self->{'REQUEST'}, $self->{'HAS_ANCHOR'}, $self->{'ANCHOR_TEXT'},
		   'h2', FORCE=>1);
	delete $self->{'HAS_ANCHOR'};
	$text=$self->{'ANCHOR_TEXT'} . $text;
    }

    if( $tagname eq "h2" ) {
	if( ($self->{'NEW_ANCHOR'}) ) {
	    $text="<a name=\"$self->{'NEW_ANCHOR'}\">$self->{'ANCHOR_TEXT'}</a>" . $text;
	    delete $self->{'NEW_ANCHOR'};
	}
	delete $self->{'IN_H2'};
    }

    $self->{'TEXT'}.=$text;
}

sub add_anchors_to_html {
    my ($this, $n) = @_;

    my $text = $this->_value_safe($n);
    return '' unless ($text);

    my $p=HTML::Parser->new(api_version => 3,
			    start_h => [\&add_anchor_to_html_start, "self, tagname, attr, text"],
			    text_h  => [\&add_anchor_to_html_text,  "self, text"],
			    end_h   => [\&add_anchor_to_html_end,   "self, tagname, text"],
			    marked_sections => 1,
			   );
    $p->{'REQUEST'}=$this->request;
    $p->parse($text);
    $p->eof;

    return $p->{'TEXT'};
}

sub create_anchorized_content_html {
    my ($this, $n) = @_;

    my $req = $this->request;

    if( !($req->pnotes('content_with_anchors')) ) { # Create it if it doesn't exist.
	my $acontent=$this->add_anchors_to_html($n);
	$req->pnotes('content_with_anchors'=>$acontent);
	return 1;
    }

    return 0;
}

# do_make_anchors_hook - provides a #make_anchors command to the
#                        template (I think), that fills in the
#                        list-variable "anchors" with the anchors
#                        created by calling create_anchorized_content
#                        (if any); passed from there to here via
#                        pnotes.
sub do_make_anchors_hook {
    my($this, $n, $c)=@_;

    $this->create_anchorized_content($n, $c);

    my $req=$this->{PROVIDER}->{REQUEST};
    my $anchorslist=$req->pnotes('anchorslist');
    $this->param(anchors => [ @{$anchorslist} ]) if $anchorslist;

    return '';
}

# do_make_anchors_hook_html - same as do_make_anchors_hook, except it
#                             calls create_anchorized_content_html,
#                             thusly this is for HTML-documents, the
#                             one before for MCMS-coded documents.
sub do_make_anchors_html_hook {
    my($this, $n)=@_;

    $this->create_anchorized_content_html($n);

    my $req=$this->{PROVIDER}->{REQUEST};
    my $anchorslist=$req->pnotes('anchorslist');
    $this->param(anchors => [ @{$anchorslist} ]) if $anchorslist;

    return '';
}



########################################################################
#
#	Formatting hooks
#
########################################################################

sub format_text_common {
    my ($this, $n, $inline_elements, $block_elements, @rest) = @_;

    my $text = $this->_value_safe($n);

    return '' unless ($text);

    $text =~ tr/\r//d;
##/
    return format_text($text,
		       provider => $this->{PROVIDER},
		       inline_elements => $inline_elements,
		       block_elements => $block_elements,
		       @rest
		      );
}

sub do_htmlize_hook {
    my ($this, $n, $c, %options) = @_;

    return $this->format_text_common($n,
				     $html_inline_elements,
				     $html_block_elements,
				     escape_text_func => \&escape_html,
				     pclass => $c||'',
				     %options,
				    );
}

sub do_htmlanchorize_hook {
    my ($this, $n, $c) = @_;

    $this->create_anchorized_content($n, $c);

    my $req = $this->request;
    return $req->pnotes('content_with_anchors');
}

sub do_anchorizehtml_hook {
    my ($this, $n) = @_;

    $this->create_anchorized_content_html($n);

    my $req = $this->request;
    return $req->pnotes('content_with_anchors');
}

sub do_htmlmap_hook {
    my ($this, $n) = @_;

    return $this->format_text_common($n, $html_inline_elements, undef,
				     escape_text_func => \&escape_html
				    );
}

sub do_htmlunmap_hook {
    my ($this, $n) = @_;

    my $text = $this->format_text_common($n, $text_inline_elements);
    return escape_html($text);
}

sub do_shorten_html_hook {
    my ($this, $n, $len, $post) = @_;

    my $text = $this->format_text_common($n, $text_inline_elements);
    return escape_html(shorten_common($text, $len, $post));
}



sub do_textify_hook {
    my ($this, $n, $wrap, $indent) = @_;

    my $text = $this->format_text_common($n,
					 $text_inline_elements,
					 $text_block_elements);
    $text =~ s/\n+$//s;

    if ($wrap and $wrap =~ /^\d+$/) {
        $wrap = '.' x $wrap;
        $text =~ s/($wrap.*?) +/$1\n/g;
    }

    if ($indent and $indent =~ /^\d+$/) {
        $indent = ' ' x $indent;
        $text =~ s/^/$indent/mg;
##/
    }

    return $text;
}

sub do_textmap_hook {
    my ($this, $n) = @_;

    return $this->format_text_common($n, $text_inline_elements);
}

sub do_shorten_text_hook {
    my ($this, $n, $len, $post) = @_;

    my $text = $this->format_text_common($n, $text_inline_elements);
    return shorten_common($text, $len, $post);
}


########################################################################
#
#	List hidden subdocs-hook
#
########################################################################

sub get_list_of_subdocs {
    my ($this, $site, $doc) = @_;

    my @subdocs=$doc->get_subdocs();
    my @data;
    map {
	my $subdoc=$site->fetch_doc_id($_);
	my $vdoc  =$subdoc->public_version($site->{VERSIONTYPE});
	if( $vdoc )
	{
	    my %data;
	    $data{short_title}=$vdoc->short_title;
	    $data{uri}=$site->get_doc_uri($subdoc);
	    push @data, \%data;
	}
    } @subdocs;

    return \@data;
}

sub do_findhiddensubdocs_hook {
    my ($this) = @_;

    my $site = $this->{PROVIDER}->{SITE};
    my $doc = $this->{PROVIDER}->{DOCUMENT};
    if( !$doc ) {
        $this->template_error('No document (check template flow logic).');
	return "";
    }

    my @subdocs=$doc->get_subdocs(-1);
    my @subdata=();
    map {
	my $subdoc=$site->fetch_doc_id($_);
	my $vdoc  =$subdoc->public_version($site->{VERSIONTYPE});
	if( $vdoc and $vdoc->seq <= -1 ) # Hidden...
	{
	    my %data;
	    $data{short_title}=$vdoc->short_title;
	    $data{uri}=$site->get_doc_uri($subdoc);
	    $data{subdocs}=$this->get_list_of_subdocs($site, $subdoc);
	    push @subdata, \%data;
	}
    } @subdocs;

    $this->param(hiddensubdocs=>\@subdata);

    return "";
}

#######################################################################
#                                                                     #
#                   Insert HTML from a HTML doc                       #
#                                                                     #
#######################################################################

sub html_make_insert_html_doc {
    my ($tag, $link, $options) = @_;

    $link = HTML::Entities::decode($link);

    my $obvius = (defined $options->{provider}->{obvius} ? $options->{provider}->{obvius} : $options->{provider}->obvius);
    my $req=(defined $options->{provider}->{request} ? $options->{provider}->{request} : $options->{provider}->request);
    my $is_admin=$req->notes('is_admin');

    my $doc = $obvius->lookup_document($link);
    unless($doc) {
        print STDERR "Warning: WebObvius::Template::MCMS::html_make_insert_html_doc - cannot find doc for $link\n";
        return ($is_admin ? "<div class='obviuswarning'>INSERTHTMLDOC: Document $link to be inserted here does not exist.</div>" : "");
    }

    # Notice: Obvius::get_public_version doesn't check if the doc Obvius::is_public_document!
    my $vdoc;
    $vdoc=$obvius->get_public_version($doc) if ($obvius->is_public_document($doc));

    unless ($vdoc) { # Check if we're in admin, if so use latest_version
        $vdoc=$obvius->get_latest_version($doc) if ($is_admin);
    }

    unless($vdoc) {
        print STDERR "Warning: WebObvius::Template::MCMS::html_make_insert_html_doc - cannot find vdoc for $link\n";
        return '';
    }
    unless($obvius->get_doctype_by_id($vdoc->Type)->Name eq 'HTML') {
        print STDERR "Warning: WebObvius::Template::MCMS::html_make_insert_html_doc - $link not of type HTML\n";
        return ($is_admin ? "<div class='obviuswarning'>INSERTHTMLDOC: The document located at $link is not a HTML document; can't insert.</div>" : "");
    }

    return "<!-- html inserted from $link -->\n" . $obvius->get_version_field($vdoc, 'html_content') || '' . "<!-- end html inserted from $link -->\n";
}

sub text_make_insert_html_doc {
    my ($tag, $link, $options) = @_;

    $link = HTML::Entities::decode($link);

    my $req = (defined $options->{provider}->{request} ? $options->{provider}->{request} : $options->{provider}->request);

    return 'http://' . $req->hostname . "$link\n";

}


1;
__END__

=head1 NAME

WebObvius::Template::MCMS - Methods that convert MCMS-encoded text to
                            HTML and plain text

=head1 SYNOPSIS

  use WebObvius::Template::MCMS;

  # Used internally:
  $newanchor=add_anchor($req, $anchor, $text, $tag, OPTION=>'value', ...);

=head1 DESCRIPTION

=head2 EXPORT

None by default.

=head1 AUTHORS

René Seindal,
Jørgen Ulrik Balslev Krag,
Adam Sjøgren.

=head1 SEE ALSO

L<perl>.

=cut
