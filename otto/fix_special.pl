#!/usr/bin/perl

#
# fix_special.pl - take care of special fields that import_new.pl doesn't handle.
#                  (base is of type path, which refers to a place in the hierarchy,
#                   but that part may not be there yet during import_new.pl, as it
#                   doesn't convert by hierarchy.
#
# $Id$
#

use strict;
use warnings;

use POSIX qw(strftime);

use Obvius;
use Obvius::Config;

use Data::Dumper;

my ($configname)=shift @ARGV;
die "Usage: fix_base.pl <configname>\n" unless ($configname);

my $conf = new Obvius::Config($configname);
my $obvius = new Obvius($conf);

my $base_set=DBIx::Recordset -> SetupObject ({'!DataSource' => $conf->{DSN},
					      '!Username'   => $conf->{PRIVILEGED_DB_LOGIN},
					      '!Password'   => $conf->{PRIVILEGED_DB_PASSWD},
					      '!Fields'     => 'name, int_value, text_value',
					      '!Table'      => 'vfields',
					      '!Debug'      => 0,
					     });
$base_set->Search({'$where' => 'name="base"'});
my $c=0;
my $e=0;
while (my $rec=$base_set->Next()) {
    next unless (defined $rec->{text_value});
    if (my $doc=$obvius->lookup_document($rec->{text_value})) {
	$rec->{int_value}=$doc->Id;
	$rec->{text_value}=undef;
	$c++;
    }
    else {
	print STDERR "Couldn't locate $rec->{text_value}!\n";
	$e++;
    }
}

$base_set->Disconnect;

print STDERR "Fixed $c base-fields\n";
print STDERR "Couldn't fix $e base-fields :-(\n" if ($e);
