package Obvius::CharsetTools;

########################################################################
#
# CharsetTools.pm - encoding fixup tools
#
# Copyright (C) 2011 Magenta Aps, Denmark (http://www.magenta-aps.dk/)
#
# Authors: Jørgen Ulrik B. Krag (jubk@magenta-aps.dk),
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

use utf8;
use Exporter;
use Encode;
use Carp;

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(mixed2utf8 mixed2perl mixed2charset debugstr);
our %EXPORT_TAGS = ( all => \@EXPORT_OK);

our $VERSION="1.0";

our $ascii =      '[\x00-\x7F]';
our $not_ascii =  '[^\x00-\x7F]';
our $two_byte =   '[\xc0-\xdf][\x80-\xbf]';
our $three_byte = '[\xe0-\xef][\x80-\xbf][\x80-\xbf]';
our $four_byte =  '[\xf0-\xf7][\x80-\xbf][\x80-\xbf][\x80-\xbf]';

our $utf8_bytes_match = qr/(?:$two_byte|$three_byte|$four_byte)+/;

sub mixed2perl {
    my ($txt) = shift;

    return $txt unless($txt);

    my $out = '';

    while(length($txt)) {
        # Eat any ascii chars, removing utf8-flag from matched chars
        if($txt =~ s!^(${ascii}+)!!) {
            my $ascii = $1;
            Encode::_utf8_off($ascii);
            $out .= $ascii;
        }

        # Eat any utf8 bytes and convert them to wide characters
        if($txt =~ s/^($utf8_bytes_match)+//) {
            $out .= Encode::decode('utf-8', $1);
        }

        # Output next character, unless it's ascii
        if($txt =~ s!^(${not_ascii})!!) {
            $out .= $1;
        }
    }

    return $out;
}

sub mixed2utf8 {
    my ($txt) = shift;

    return $txt unless($txt);

    my $out = '';
    while(length($txt)) {
        # Eat any ascii chars, removing utf8-flag from matched chars
        if($txt =~ s!^(${ascii}+)!!) {
            my $ascii = $1;
            Encode::_utf8_off($ascii);
            $out .= $ascii;
        }

        # Eat any utf8 chars
        if($txt =~ s/^($utf8_bytes_match)+//) {
            if(Encode::is_utf8($1)) {
                # Repack octets to remove utf8 flag
                $out .= pack('c*', unpack('c*', $1));
            } else {
                $out .= $1;
            }
        }

        # Convert next character to utf8, if present and not asciii
        if($txt =~ s!^(${not_ascii})!!) {
            $out .= Encode::encode('utf-8', $1);
        }
    }

    return $out;
}

sub mixed2utf8_old {
    my ($txt) = shift;

    return $txt unless($txt);

    my $out = "";

    my @chars = unpack("U*", $txt);

    while(@chars) {
        # If highest bit is 0 => ascii
        if($chars[0] < 128) {
            $out .= pack("C", shift(@chars));
        }
        # Two-byte unicode char (0b110xxxxx,0b10xxxxxx)
        elsif(
            $chars[0] < 256 &&
            defined($chars[1]) && $chars[1] < 256 &&
            ($chars[0] & 0b11100000) == 0b11000000 &&
            ($chars[1] & 0b11000000) == 0b10000000
        ) {
            $out .= pack("C*", splice(@chars, 0, 2));
        }
        # Three-byte unicode char (0b1110xxxx,0b10xxxxxx,0b10xxxxxx)
        elsif(
            defined($chars[2]) && $chars[2] < 256 &&
            ($chars[0] & 0b11110000) == 0b11100000 &&
            ($chars[1] & 0b11000000) == 0b10000000 &&
            ($chars[2] & 0b11000000) == 0b10000000
        ) {
            $out .= pack("C*", splice(@chars, 0, 3));
        }
        # Four-byte unicode char (0b11110xxx,0b10xxxxxx,0b10xxxxxx)
        elsif(
            defined($chars[3]) && $chars[3] < 256 &&
            ($chars[0] & 0b11111000) == 0b11100000 &&
            ($chars[1] & 0b11000000) == 0b10000000 &&
            ($chars[2] & 0b11000000) == 0b10000000 &&
            ($chars[3] & 0b11000000) == 0b10000000
        ) {
            $out .= pack("C*", splice(@chars, 0, 4));
        } else {
            # Single wide char that needs to be utf8 encoded
            $out .= Encode::encode("utf8", chr(shift(@chars)));
        }
    }

    return $out;
}

sub mixed2perl_old {
    my ($txt) = shift;
    
    # TODO: Ref. ticket #6000. This function used to work as a destroyer of
    # references. Any array exposed to the encode/decode mechanism will be 
    # reduced to a string representation of the reference pointer.
    # For now, just ignore references, but ideally recurse through them and
    # convert.

    if (ref $txt) {
        return $txt;
    } else {
        return Encode::decode("utf8", mixed2utf8($txt));
    }
}

sub mixed2charset {
    my ($txt, $charset) = @_;
    if($charset =~ m!utf[-]?8!i) {
        return mixed2utf8($txt);
    } else {
        return Encode::encode($charset, mixed2perl($txt));
    }
}

sub debugstr {
    my ($txt) = shift;

    return join("", map {
        $_ < 128 ? chr($_) : sprintf('\\x{%x}', $_);
    } unpack("U*", $txt));
}
1;
