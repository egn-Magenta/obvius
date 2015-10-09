# $Id$

package Obvius::FieldType;

use 5.006;
use strict;
use warnings;

use Obvius;
use Obvius::Data;

our @ISA = qw( Obvius::Data );
our $VERSION="1.0";

use Obvius::FieldType::None;
use Obvius::FieldType::Xref;
use Obvius::FieldType::Regexp;
use Obvius::FieldType::Special;
use Obvius::Log;

# new(%hash) - Constructs an object of class Obvius::FieldType.
#
#              The object inherits from Obvius::Data.  If VALIDATE
#              (None|Xref|Regexp|Special) is in the %hash the object
#              is constructed as the corresponding subtype,
#              ie. Obvius::FieldType::Regexp
#

sub new
{
	my $class = shift;
	my $this  = $class-> SUPER::new(@_);

	if ($this) {
		no strict 'refs';

		my $type = $this-> {VALIDATE};
		$type = "\U$1\E\L$2\E" if $type =~ /^(\w)(.*)$/;

		my $tester = "${class}::${type}::VERSION";
		if (defined $$tester) {
			$class .= "::$type";
			bless $this, $class;	# re-bless into subclass
		} else {
			Obvius::Log-> warn("No class for fieldtype $type");
		}
	}

	return $this;
}

sub copy_in
{
	my ($this, $obvius, $fspec, $value) = @_;
	return $value;
}

sub copy_out
{
	my ($this, $obvius, $fspec, $value) = @_;
	if (!defined $value) {
		return $value;
	}
	if ($fspec->param('fieldtype') eq 'date' && $value eq '') {
		return '0000-00-00 00:00:00';
	}
	return $value;
}

sub validate
{
	my ($this, $obvius, $fspec, $value, $input) = @_;
	return $value;
}


1;
