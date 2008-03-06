package Obvius::Config;

########################################################################
#
# Config.pm - Obvius configuration parameters.
#
# Copyright (C) 2001-2004 Magenta Aps, Denmark (http://www.magenta-aps.dk/)
#
# Authors: Ren� Seindal (rene@magenta-aps.dk)
#          J�rgen Ulrik Balslev Krag (jubk@magenta-aps.dk)
#          Adam Sj�gren (asjo@magenta-aps.dk)
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

use Data::Dumper;
use Obvius::Data;

our @ISA = qw( Obvius::Data );
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

our $confdir = '/etc/obvius';
our $defaults = 'defaults';

# use Data::Dumper;
sub parse_file {
     my $file = shift;
     
     my %data;

     open F, "<", $file or return undef;
     for (grep { ! ( /^\#/ or /^\s*$/ ) } <F>) {
	  chomp;
	  my ($key, $val) = split(/\s*=\s*/, $_, 2);
	  if (my ($list) = $val =~ /^\s*\((.*)\)\s*$/) {
	       my @vals = grep { $_ and !/^\s*$/ } split /\s*,\s*/, $list;
	       $val = [@vals];
	  }
	  $data{uc $key} = $val;
     }
     close F;
     
     return \%data;
}
     

sub read_config_file {
    my ($name) = @_;

    my @files = ("$confdir/$defaults", "$confdir/$name.conf");
    my %data;
    
    for (@files) {
	 my $data = parse_file($_);
	 %data = (%data, %$data) if ($data);
    }

    #print STDERR "read_config_file: ", Dumper(\%data);
    return \%data;
}

sub new {
    my ($class, $name) = @_;

    my $data = read_config_file($name);
    unless ($data) {
        print STDERR "Couldn't read $confdir/$name.conf\n";
        return undef;
    }

    my $this = $class->SUPER::new($data);
    $this->param(name => $name);

    return $this;
}

sub read_roothost_conf
{
	my ( $self, $conf) = @_;

	return unless -f $conf;

	open F, '<', $conf or die "Cannot open $conf:$!\n";
	my ($roothost) = (<F> =~ m!:([^\]]+)!);
	close F;

	die "Cannot extract roothost from $conf\n" unless $roothost;

	$roothost;
}



1;
__END__

=head1 NAME

Obvius::Config - Class for Obvius configuration parameters.

=head1 SYNOPSIS

  use Obvius::Config;

  $c = new Obvius::Config($confname);

  @names = $c->param;
  $value = $c->param($name);
  $oldvalue = $c->param($name, $value);

=head1 DESCRIPTION

Simple class for holding a number of key, value pairs.  Initial values
are read from an external source (currently files
/etc/obvius/$confname.conf).

The format of the configuration files are "key = value" lines.  Lines
starting with C<#> are comments and blank lines are ignored.  If
multiple values for a given key are given, the last value wins.

The constructor fails if it cannot read the configuration file.

Values can be read and set using the param() method in the usual way.

The configuration files are read from the directory given by
$Obvius::Config::confdir.

=head2 EXPORT

None by default.

=head1 AUTHOR

Ren� Seindal

=head1 SEE ALSO

L<perl>.

=cut
