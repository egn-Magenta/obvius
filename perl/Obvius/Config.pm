package Obvius::Config;

########################################################################
#
# Config.pm - Obvius configuration parameters.
#
# Copyright (C) 2001-2004 Magenta Aps, Denmark (http://www.magenta-aps.dk/)
#
# Authors: René Seindal (rene@magenta-aps.dk)
#          Jørgen Ulrik Balslev Krag (jubk@magenta-aps.dk)
#          Adam Sjøgren (asjo@magenta-aps.dk)
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
use Carp;

our @ISA = qw( Obvius::Data );
our $VERSION="1.0";

our $confdir = '/etc/obvius';
our $defaults = 'defaults.conf';

our $DEBUG = 0;

my $debug_output = '';

# Formats and adds a line to $debug_output
sub _add_debug_line {
    my ($source, $key, $replaced) = @_;

    if(!$DEBUG) {
        return;
    }

    my ($source_basename) = ($source =~ m{([^/]+$)});

    $debug_output .= sprintf(
        '%-25s: %s %s',
        $source_basename,
        $replaced ? "Replace" : "Set",
        lc $key
    ) . "\n";
}

# use Data::Dumper;
sub parse_file {
     my $file = shift;

     my %data;

     open F, "<", $file or return undef;
     for (grep { ! ( /^\#/ or /^\s*$/ ) } <F>) {
	  chomp;
	  my ($key, $val) = split(/\s*=\s*/, $_, 2);

	  # Remove extra start and ending spaces
	  $key =~ s{^\s+}{};
	  $val =~ s{\s+$}{};
      $val = read_array($val);

	  if($DEBUG) {
	      _add_debug_line($file, $key, exists $data{uc $key});
	  }
	  $data{uc $key} = $val;
     }
     close F;

     return \%data;
}

sub read_array {
    my ($val) = @_;
    if (my ($list) = $val =~ /^\s*\((.*)\)\s*$/) {
        my @vals = grep { $_ and !m/^\s*$/ } split(/\s*,\s*/, $list);
        $val = \@vals;
    }
    return $val;
}

# Loads configuration from files with the given configuration name
# Will attempt to load four files in the following order:
#
#  'defaults.conf'
#  '<name>.conf'
#  '<name>-environment.conf'
#  '<name>-local.conf'
#
# Settings from later files will override those in previous files.
# The method will die if <name>.conf does not exist.
#
sub read_config_file {
    my ($name) = @_;

    my $defaults_file   = "$confdir/$defaults";
    my $main_file       = "$confdir/$name.conf";
    my $env_file        = "$confdir/$name-environment.conf";
    my $local_file      = "$confdir/$name-local.conf";

    if(!-r $main_file) {
        croak "Can not read config file $main_file!";
    }

    my @files = (
        $defaults_file,
        $main_file,
        $env_file,
        $local_file,
    );
    my %data;

    foreach my $filename (@files) {
        if(! -f $filename || ! -r $filename)  {
            next;
        }
        my $new_data = parse_file($filename);
        if ($new_data) {
            %data = (%data, %$new_data);
        }
    }

    return \%data;
}

# Creates a new config object.
#  $name is the name of the configuration file to load
#
#  if $options{debug} is set a list of which settings were
#  loaded from where will be output to STDERR
#
sub new {
    my ($class, $name, %options) = @_;

    my $data = read_config_file($name);
    unless ($data) {
        print STDERR "Couldn't read $confdir/$name.conf\n";
        return undef;
    }

    my $this = $class->SUPER::new($data);
    $this->param(name => $name);

    # Loop through existing config keys and check if they should
    # be overriden by values from %ENV.
    foreach my $key ($this->param) {
        my $env_key = uc("OBVIUS_CONFIG_${name}_${key}");
        if(exists $ENV{$env_key}) {
            $this->param($key => read_array($ENV{$env_key}));
            if($DEBUG) {
                _add_debug_line('%ENV', $key, $this->param($key));
            }
        }
    }

    if($options{debug}) {
        print STDERR $this->debug;
    }

    return $this;
}

# Returns a string with one line for each setting that was added
# or replaced while loading the configuration along with the
# source for the setting.
sub debug {
    my ($this, $confname) = @_;

    local $DEBUG = 1;
    $debug_output = '';

    $confname ||= $this->param('name');

    __PACKAGE__->new($confname);

    my $result = $debug_output;
    $debug_output = '';

    return $result;
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

# Returns text string with a sorted list of all config values
sub get_normalized_text {
    my ($this) = @_;

    foreach my $key (sort $this->param) {
        my $value = $this->param($key);
        if(ref($value) eq 'ARRAY') {
            $value = '(' . join(", ", @$value) . ")";
        }
        print sprintf('%s = %s', lc($key), $value), "\n";
    }
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

René Seindal

=head1 SEE ALSO

L<perl>.

=cut
