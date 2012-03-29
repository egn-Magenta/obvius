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

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(mixed2utf8 mixed2perl mixed2charset debugstr);
our %EXPORT_TAGS = ( all => \@EXPORT_OK);

our $VERSION="1.0";

sub mixed2utf8 {
    my ($txt) = shift;

    return $txt unless($txt);

    my $out = "";

    # Get the 4 first chars
    my $length = length($txt);
    my @chars = unpack("W*", substr($txt, 0, 4));
    my $index = 4;

    while(@chars) {
        # If highest bit is 0 => ascii
        if(defined($chars[0]) && $chars[0] < 128) {
            $out .= pack("C", shift(@chars));
        }
        # Two-byte unicode char (0b110xxxxx,0b10xxxxxx)
        elsif(
            defined($chars[0]) && $chars[0] < 256 &&
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

        # Get as many new chars as was removed
        my $taken = 4 - @chars;
        push(@chars, unpack("W*", substr($txt, $index, $taken))) if($index < $length);
        $index += $taken;
    }

    return $out;
}

sub mixed2perl {
    my ($txt) = shift;

    return Encode::decode("utf8", mixed2utf8($txt));
}

sub mixed2charset {
    my ($txt, $charset) = @_;
    if($charset =~ m!utf[-]?8!i) {
        return mixed2utf8($txt);
    } else {
        return Encode::from_to(mixed2utf8($txt), 'utf8', $charset);
    }
}

sub debugstr {
    my ($txt) = shift;

    return join("", map {
        $_ < 128 ? chr($_) : sprintf('\\x{%x}', $_);
    } unpack("W*", $txt));
}
1;
