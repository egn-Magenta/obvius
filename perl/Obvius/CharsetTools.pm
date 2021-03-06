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

our $utf8_bytes_match = qr/(?:$two_byte|$three_byte|$four_byte)/;

=head2 mixed2perl

  my $perl_wide_string = mixed2perl($mixed_input);

Converts a string with mixed data (wide-characters, latin1 and utf8 encoding
in the same string) into a string containing only perl wide characters. If the
input is a reference to a simple data structure a deep copy of the data
structure will be made, running the mixed2perl method on all elements.

=cut

sub mixed2perl {
    my ($txt) = shift;

    return $txt unless($txt);

    return _deep_copy($txt, \&mixed2perl) if(ref($txt));

    my $out = '';

    while($txt =~ m{
        \G
        (?:
            (${ascii}+) |
            (${utf8_bytes_match}{1,32000}) |
            ($not_ascii+)
        )
    }gx) {
        if(defined($1)) {
            my $ascii = $1;
            Encode::_utf8_off($ascii);
            $out .= $ascii;
        } elsif(defined($2)) {
            $out .= Encode::decode('utf-8', $2);
        } else {
            $out .= $3;
        }
    }

    return $out;
}

=head2 mixed2utf8

  my $utf8_encoded_string = mixed2utf8($mixed_input);

Converts a string with mixed data (wide-characters, latin1 and utf8 encoding
in the same string) into a string containing only utf8-octet encoding. If the
input is a reference to a simple data structure a deep copy of the data
structure will be made, running the mixed2utf8 method on all elements.

=cut

sub mixed2utf8 {
    my ($txt) = shift;

    return $txt unless($txt);

    return _deep_copy($txt, \&mixed2utf8) if(ref($txt));

    my $out = '';
    while($txt =~ m{
        \G
        (?:
            (${ascii}+) |
            (${utf8_bytes_match}{1,32000}) |
            ($not_ascii+)
        )
    }gx) {
        if(defined($1)) {
            my $ascii = $1;
            Encode::_utf8_off($ascii);
            $out .= $ascii;
        } elsif(defined($2)) {
            if(Encode::is_utf8($2)) {
                # Repack octets to remove utf8 flag
                $out .= pack('c*', unpack('c*', $2));
            } else {
                $out .= $2;
            }
        } else {
            $out .= Encode::encode('utf-8', $3);
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
        return Encode::decode("utf8", mixed2utf8_old($txt));
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

sub _deep_copy {
    my ($val, $method, $ref_cache) = @_;

    $ref_cache ||= {};

    my $ref = ref($val);
    my $cache_key = $ref ? scalar($val) : '';
    if(my $v = $ref_cache->{$cache_key}) {
        return $v;
    }

    if (ref $val eq 'ARRAY') {
        my @v;
        $ref_cache->{$cache_key} = \@v;
        @v = map { _deep_copy($_, $method, $ref_cache) } @$val;
        return \@v;
    } elsif (ref $val eq 'HASH') {
        my %v;
        $ref_cache->{$cache_key} = \%v;
        %v = map { _deep_copy($_, $method, $ref_cache) } %$val;
        return \%v;
    } elsif (ref $val eq 'SCALAR') {
        my $scal = _deep_copy($$val, $method, $ref_cache);
        $ref_cache->{$cache_key} = \$scal;
        return \$scal;
    } elsif (ref $val) {
	warn "Can not deep-copy unknown reference type '$ref': " .
            "Returning orignal reference instead";
        return $val;
    } else {
	return $method->($val);
    }
}

1;
