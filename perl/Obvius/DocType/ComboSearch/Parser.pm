package Obvius::DocType::ComboSearch::Parser;

########################################################################
#
# Parser.pm - Convert combo_search document search strings
#
# Copyright (C) 2000-2004 Magenta Aps, Denmark (http://www.magenta-aps.dk/)
#                         FI, Denmark (http://www.fi.dk/)
#
# Authors: René Seindal (rene@magenta-aps.dk)
#          Peter Makholm (pma@fi.dk)
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

require 5.005_62;
use strict;
use warnings;

use Obvius;

require Exporter;

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(handle_search_expression combo_search_parse);
our @EXPORT = qw(handle_search_expression);
our $VERSION = '0.01';

use Data::Dumper;

sub quoter {
    my $s = shift;
    return 'NULL' unless (defined $s);
    $s =~ s/\'/\'\'/g;
    return "\'$s\'";
}

sub debug {
    my $this = shift;
    my $name = shift;

    my $input = substr($this->{INPUT},0,30);
    $input =~ s/\n/\\n/g;
    Obvius::log()->debug("ComboSearch Parser: $name: «$input»");
}

sub test {
    my (@files) = @_;

    for (@_) {
	local $/;
	my $in;

	open($in, "$_") or next;
	my $text = <$in>;
	close($in);

	my $query = combo_search_parse($text, quote=>\&quoter,
				       docfields => [qw(default_op owner grp)],
				       versionfields => [qw(doctype title version)],
				      );
    }
}


sub combo_search_parse {
    my $text = shift;
    my $parser = new Obvius::DocType::ComboSearch::Parser(@_);

    my $tree = $parser->parse($text);

    return undef unless ($tree);

    my $where = $parser->query($tree);

    # Remove duplicates from required fields
    #my %dups;
    #my @fields = grep { not $dups{$_}++ } @{$parser->{USED_FIELDS}};
    my @fields=@{$parser->{USED_FIELDS}};

    return ($where, @fields);
}

sub handle_search_expression {
    my $program = shift;

    return (undef, undef) unless($program);

    # Remove windows stuff
    $program =~ s/\r//g;

    return (undef, undef) unless($program);

    # Remove start and end
    $program =~ s/^.*?\@search\b//s;
    $program =~ s/\@end\b.*$//s;

    return (undef, undef) unless($program);

    return combo_search_parse($program);
}


sub new {
    my ($class, %options) = @_;

    my %this = (
		OPTIONS => \%options,
		QUOTE => \&quoter,
		FIELDMAP => {},
	       );

    for (qw(quote sort_order)) {
	$this{"\U$_\E"} = $options{$_} if (defined $options{$_});
    }

    return bless \%this, $class;
}

sub quote_function {
    my ($this, $quote_func) = @_;

    my $tmp = $this->{QUOTE};
    if (defined $quote_func) {
	$this->{QUOTE} = $quote_func;
    }
    return $tmp;
}

sub parse {
    my ($this, $text) = @_;

    # $text = \$text unless (ref $text);
    $this->{INPUT} = $text;

    my $tree = eval { $this->combosearch };
    unless ($tree) {
	Obvius::log->error("Parse error: $@");
	Obvius::log->error("Input: " . substr($this->{INPUT},0,50));
	return undef;
    }

    return $tree;
}

sub query {
    my ($this, $tree) = @_;

    $this->{JOIN_ID} = 0;
    $this->{JOINS} = [];
    $this->{USED_FIELDS} = [];

    my $where = $this->_query($tree, 0, 0);

    return $where;
}

sub _query {
    my ($this, $tree, $join, $inc) = @_;

    my $op = shift(@$tree);
    if ($op eq 'OR') {
	return ("("
		. join(" OR ",
		       map { $this->_query($_, $join) } @$tree)
		. ")"
	       );
    }
    elsif ($op eq 'AND') {
	return ("("
		. join(" AND ",
		       map { $this->_query($_, $this->{JOIN_ID}, 1) } @$tree)
		. ")"
	       );
    } else {
	my $field = $tree->[0];

	push(@{$this->{USED_FIELDS}}, $field);

	my $arg = $tree->[1];
	if ($op =~ /\bIN$/) {
	    $arg = '(' . join(',', map {$this->{QUOTE}->($_)} split(/\|/, $arg))  . ')';
	} elsif ($arg =~ /^\s*now\s*([+-]\d+)\s*(year|month|day|hour|minute|second)s?\s*$/i) {
	    $arg = "DATE_ADD(NOW(), INTERVAL $1 \U$2\E)";
	} else {
	    $arg = $this->{QUOTE}->($arg);
	}
	return "($field $op $arg)";
    }
}


########################################################################
#
#	Parser code follows - standard recursive descent
#
#########################################################################

=pod

    Grammar

	combosearch	-> or-term
			 | or-term "OR" combosearch

	or-term		-> and-term
			 | and-term "AND" or-term

	and-term	-> match
			 | "(" combosearch ")"

	match		-> field match-op argument
			 | "NOT" field match-op argument

	field		-> /\w+/

	match-op	-> "="
			 | "=?"
			 | "=1"
			 | "!="
			 | "!?"
			 | "!1"

	argument	-> /"([^"]+|\\")*"/
			 | /'([^']+|\\')*'/
			 | /.*$/


    The handling of NOT can arguably be argued.


=cut


# Remove the previous leading match from the input
sub gobble_match {
    my $this = shift;
    substr($this->{INPUT},0,pos($this->{INPUT})) = '';
}

sub combosearch {
    my $this = shift;

    $this->debug("COMBO");

    my @tree = ('OR', $this->or_term );
    while ($this->{INPUT} =~ /^\s*[Oo][Rr]\s*/g) {
	$this->gobble_match;
	push(@tree, $this->or_term);
    }

    return scalar(@tree) == 2 ? $tree[1] : \@tree;
}

sub or_term {
    my $this = shift;

    $this->debug("OR-TERM");

    my @tree = ( 'AND', $this->and_term );
    while ($this->{INPUT} =~ /^\s*[Aa][Nn][Dd]\s*/g) {
	$this->gobble_match;
	push(@tree, $this->and_term);
    }

    return scalar(@tree) == 2 ? $tree[1] : \@tree;
}

sub and_term {
    my $this = shift;

    $this->debug("AND-TERM");

    if ($this->{INPUT} =~ /^\s*\(\s*/g) {
	$this->gobble_match;

	my @tree = $this->combosearch;

	if ($this->{INPUT} =~ /^\s*\)\s*/g) {
	    $this->gobble_match;
	} else {
	    die "Missing )\n";
	}

	return scalar(@tree) == 1 ? $tree[0] : \@tree;
    }

    return $this->match;
}

sub match {
    my $this = shift;

    $this->debug("MATCH");

    my $negate;
    if ($this->{INPUT} =~ /^\s*NOT\s*/g) {
	$this->gobble_match;
	$negate = 1;
    }

    my @tree;
    push(@tree, $this->field);
    unshift(@tree, $this->match_op($negate));
    push(@tree, $this->argument);

    # Eliminate matching on non-patterns - what a waste of cycles
    if ($tree[0] =~ /LIKE/ and $tree[2] !~ /[%_]/) {
	$tree[0] = { $tree[0] => $tree[0], 'LIKE' => '=', 'NOT LIKE' => '!=' }->{$tree[0]};
    }

    return \@tree;
}

sub field {
    my $this = shift;

    $this->debug("FIELD");

    if ($this->{INPUT} =~ /^\s*(\w+)\s*/g) {
	my $field = $1;
	$this->gobble_match;
	return $field;
    }

    die "Not a legal field-name\n";
}

my %operators =
    (
     '=' => '=',
     '!=' => '!=',
     '<' => '<',
     '>' => '>',
     '<=' => '<=',
     '>=' => '>=',
     '=?' => 'LIKE',
     '!?' => 'NOT LIKE',
     '=1' => 'IN',
     '!1' => 'NOT IN',
    );

my %negated_operators =
    (
     '=' => '!=',
     '!=' => '=',
     '<' => '>=',
     '>' => '<=',
     '<=' => '>',
     '>=' => '<',
     '=?' => 'NOT LIKE',
     '!?' => 'LIKE',
     '=1' => 'NOT IN',
     '!1' => 'IN',
    );

my $operator_regex;

sub match_op {
    my $this = shift;
    my $negate = shift;

    $this->debug("MATCH_OP");

    my @operators = sort { length $b <=> length $a } keys(%operators); # The single char operators should be last.
    unless ($operator_regex) {
	$operator_regex = ('^\s*('
			   . join('|', map {quotemeta($_)} @operators)
			   . ')\s*'
			  );
    }

    if ($this->{INPUT} =~ /$operator_regex/go) {
	my $op = $1;
	$this->gobble_match;
	return $negate ? $negated_operators{$op} : $operators{$op};
    }

    die "Not a legal operator\n";

}

sub argument {
    my $this = shift;

    $this->debug("ARGUMENT");

    if ($this->{INPUT} =~ /^\s*"((\Q\"\E|[^\"]+)*?)"\s*/g) {
	my $argument = $1;
	$argument =~ s/\\\"/\"/g;

	$this->gobble_match;
	return $argument;
    }

    if ($this->{INPUT} =~ /^\s*'((\\\'|[^\'])*?)'\s*/g) {
	my $argument = $1;
	$argument =~ s/\\\'/\'/g;
	$this->gobble_match;
	return $argument;
    }

    if ($this->{INPUT} =~ /^\s*(.*)$/gm) {
	my $argument = $1;
	$this->gobble_match;
	return $argument;
    }

    die "Not a legal argument string\n";
}



1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Obvius::DocType::ComboSearch::Parser - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Obvius::DocType::ComboSearch::Parser;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Obvius::DocType::ComboSearch::Parser, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head2 EXPORT

None by default.


=head1 AUTHOR

A. U. Thor, a.u.thor@a.galaxy.far.far.away

=head1 SEE ALSO

perl(1).

=cut
