package WebObvius;

use strict;
use warnings;

require Exporter;
our @ISA = qw( Exporter );
our @EXPORT_OK = qw( parse_editpage_fieldlist );

our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub parse_editpage_fieldlist {
    my ($this, $fieldlist, $doctype, $obvius) = @_;

    my @fieldlist;
    foreach (split /\n/, $fieldlist) {
	$_=~/^(\w+)\s?(.*)$/;
	my ($name, $rest)=($1, $2);
        $rest=~s/([^\\]);/$1¤/g; # This is not so nice
	my ($title, $opts) = map { s/\\;/;/g; $_; } split /¤/, $rest;
	my @options;
	if ($opts) {
	    $opts =~ s/\\,/¤/g; # This is quite ugly
	    @options=map { s/¤/,/g; $_ } (split /\s*[,=]\s*/, $opts);
	}
	my %f=(
	       title=>$title,
	       fieldspec=>$obvius->get_fieldspec($name, $doctype),
	      );
	$f{options}={ @options } if (@options);

	die "No fieldspec for $name ($_)!\n" unless ($f{fieldspec});
	push @fieldlist, \%f;
    }
    return \@fieldlist;
}


# Preloaded methods go here.

1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

WebObvius - Top of the web-application part for Obvius.

=head1 SYNOPSIS

  use WebObvius;

  $this->parse_editpages_fieldlist($fieldlist, $doctype, $obvius);

=head1 DESCRIPTION

parse_editpages_fieldlist() - parses the fieldlist from an editpage
and returns a ref to a list with each field nicely included as a hash
with title, fieldspec and options.

=head1 AUTHOR

Adam Sjøgren.

=head1 SEE ALSO

L<WebObvius::Site>.

=cut
