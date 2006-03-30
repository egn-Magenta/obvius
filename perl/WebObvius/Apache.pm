# $Id$
package WebObvius::Apache;

# A hackish compatibility layer between Apache1 and Apache2. 

use strict;
require Exporter;
use vars qw(@ISA @EXPORT_OK);
@ISA = qw(Exporter);
@EXPORT_OK = qw(apache_module);

our $MOD_PERL = (exists $ENV{'MOD_PERL'}) ? (
	( $ENV{'MOD_PERL'} =~ /mod_perl\/2/) ? 2 : 1
) : 0;

if ( $MOD_PERL == 2) {
	eval "use Apache2::compat;";
	die $@ if $@;
}

# returns module name with corresponding apache prefix
sub apache_module { (( $MOD_PERL == 2) ? 'Apache2' : 'Apache') . "::$_[0]" }

# support compat-mode import of Apache modules
# such as that:
# use WebObvius::Apache
#      Constants => qw(:common),
#      Utils ;
sub import
{
	my @imports;
	shift;
	for my $mod ( @_ ) {
		if ( not length $mod) {
			next;
		} elsif ( $mod =~ /^[A-Z][a-z]/) {
			push @imports, [ $mod ];
		} elsif ( @imports) {
			push @{$imports[-1]}, $mod;
		} else {
			die "panic: don't know with to do with directive '$mod'\n";
		}
	}

	for my $mod ( @imports) {
		my $module = shift @$mod;
		if ( $MOD_PERL == 2) {
			if ( $module eq 'Constants') {
				@$mod = grep { $_ ne ':response' } @$mod;
				$module = 'Const';
			} elsif ( $module eq 'Access') {
				require Apache2::Access;
			} elsif ( $module eq 'File') {
				next; # in ::compat() already
			}
		}
		
		$module = apache_module( $module);

		my $callpkg = caller;
		eval "package $callpkg; use $module qw(@$mod);";
		die $@ if $@;
	}

	WebObvius::Apache-> export_to_level( 1, '', qw(apache_module) );
}

# various compat methods not covered by Apache2::compat
if ( $MOD_PERL == 2) {
	require Apache2::RequestRec;
	# compat::args() is broken 
	my $req_args = \&Apache2::RequestRec::args;
	*Apache2::RequestRec::args = sub {
		my $req = shift;
		if ( wantarray) {
			return map {
	        		tr/+/ /;
	        		s/%([0-9a-fA-F]{2})/pack("C",hex($1))/ge;
	        		$_;
	    		} split /[=&;]/, $req_args->( $req) || '', -1;
		} else {
			return $req_args->( $req);
		}
	};
	
	# support both Apache1 and Apache2 styles
	my $req_notes = \&Apache2::RequestRec::notes;
	*Apache2::RequestRec::notes = sub {
		my $req = shift;
		if ( 0 == @_ ) {
			# ap2
			return $req_notes->($req);
		} elsif ( 1 == @_ ) {
			if ( ref($_[0])) {
				# ap2
				return $req_notes-> ($req, @_);
			} else {
				# ap1
				if ( wantarray ) {
					my @g = $req_notes-> ($req)-> get( @_);
					@g = (undef) unless @g; # This is to prevent
					# mason errors such as 'Odd number of parameters passed 
					# to component expecting name/value pairs' when notes()
					# is called in array context as a part of component calling
					# routine
					return @g;
				} else {
					return $req_notes-> ($req)-> get( @_);
				}
			}
		} elsif ( 2 == @_ ) {
			# ap1
			return $req_notes-> ($req)-> set( @_);
		} else {
			die "panic: Apache2::RequestRec::notes: Don't know how to handle parameters '@_'\n";
		}
	};
	
	# not present in compat::
	require Apache2::Cookie;
	*Apache::Cookie::fetch = \&Apache2::Cookie::fetch;

	# present in compat:: in Apache2:: namespace, but we need Apache::
	require Apache2::Util;
	*Apache::Util::ht_time = sub {
		my $r = Apache2::compat::request('Apache::Util::ht_time');
		return Apache2::Util::ht_time($r->pool, @_);
	};
}

1;
