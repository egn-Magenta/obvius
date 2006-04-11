package Obvius::DocType::Search;

use 5.006;
use strict;
use warnings;

use Obvius;
use Obvius::DocType;

use Data::Dumper;

use locale; # Danish letters
use Unicode::String qw(utf8 latin1);

our @ISA = qw( Obvius::DocType );
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub htdig_config_name {
    my ($this, $obvius) = @_;

    return $obvius->{OBVIUS_CONFIG}->HTDIG_CONFIG || 'htdig';
}

sub htdig_htsearch_path {
    for (qw( /usr/local/htdig/cgi-bin/htsearch /usr/lib/cgi-bin/htsearch /usr/bin/htsearch )) { # / GRRR
	return $_ if ( -x $_ );
    }
    return undef;
}

sub read_htdig_output {
    my ($args, $part, $keep_part_list, $need_next_page, $obvius) = @_;

    my $htsearch = htdig_htsearch_path();
    return undef unless ($htsearch);

    my $cmd;


    # convert the incoming args to an url like string
    if (ref $args) {
    	my %map;

	if (( $ENV{'MOD_PERL'} || '') =~ /mod_perl\/2/) {
    		my $r = Apache2::RequestUtil->request;
		%map = map {
			my $key = Apache2::Util::escape_path(lc($_), $r-> pool);
			my $value = Apache2::Util::escape_path($$args{$_}, $r-> pool);
			( $key, $value);
		} keys %$args;
	} else {
		%map = map {
			my $key = Apache::Util::escape_uri(lc($_));
			my $value = Apache::Util::escape_uri($$args{$_});
			( $key, $value);
		} keys %$args;
	}
	
        $cmd = join('&',
		    map {
		    	my $value = $map{$_};
			if ( /(the_request|obvius_cookies|now)/) {
			    $value = '';
			}
			( $_ . '=' . $value )
		    } keys %map
	);
    } else {
        $cmd = $args;
    }

    local ($ENV{QUERY_STRING});
    $ENV{QUERY_STRING} = $cmd;

    local ($ENV{REQUEST_METHOD});
    $ENV{REQUEST_METHOD} = 'GET';

    local ($ENV{SCRIPT_NAME});
    $ENV{SCRIPT_NAME} = '@SEARCH_PAGE@';

    local (*INPUT);
    if($obvius->config->param('report_htdig_running')) {
        $obvius->log->error("RUNNING $htsearch '$cmd'| ");
    } else {
        $obvius->log->debug("RUNNING $htsearch '$cmd'| ");
    }
    open(INPUT, "$htsearch |") or return undef;
    my @lines = <INPUT>;
    close(INPUT);

    my ($count) = ($lines[2] =~ m/^<!--\@COUNT=(\d+)\s*-->$/);
    $part->param(count=>$count);

    splice(@lines, 0, 2);

    my $title;

    if($part->{DOCID} and $part->{DOCID}>1) { # XXX Root
        $title = $part->field('short_title') || $obvius->get_version_field($part, 'title');
    } else {
	$title = 'Andet';
    }

    my $x = 1;
    @lines = map {
        # Figure out whether we need a link to a paged results page
        unless ($keep_part_list) {
            if ($_ =~ /<!--\@PAGELIST\s*-->/) {
                $x = 0;
            } elsif ($_ =~ /<!--\/\@PAGELIST\s*-->/) {
                $x = 1;
            }
        }

        if ($x) {
            my $s = $_;

            # Make an url from the string found in the @NEXTPAGE html comment
            if ($need_next_page and /^<!--\@NEXTPAGE (<a href=[^>]+?>).*-->/) {
                $s = "$1$count</a>";
            }

            $s =~ s!http://[^/]+/!/!g;
            $s =~ s/\@TITLE\@/$title/ge;
            $s =~ s/\@SECTION\@/$part->Name/ge;
            $s =~ s/\@SEARCH_PAGE\@\?/sprintf('.\/?op=search_page&amp;part=%s;', $part->Name)/ge;
            $s =~ s/>[^><]+?\s+-\s+/>/g;

            $s;
        } else {
            '';
        }
    } @lines;

    return \@lines;
}

sub get_search_words {
    my ($this, $words)=@_;

    return () unless ($words);

    if ($words =~ /Ã/) {
	$words = lc(utf8($words)->latin1);
    } else {
	$words = lc($words);
    }

    return ($words =~ /\b(\w+[*]?)/g);
}

sub do_search_page {
    my ($this, $input, $output, $obvius) = @_;

    my $part_name = $input->param('part');
    die "No part name in do_search_page\n" unless($part_name);

    $output->param(Obvius_DEPENCIES => 1);
    my $partdoc = $obvius->lookup_document("/$part_name/") || $obvius->lookup_document('/');
    my $partvdoc = $obvius->get_public_version($partdoc);
    $partvdoc->param('name'=>$partdoc->param('name'));

    my $pass_part=$partvdoc || $partdoc;

    my $lines = read_htdig_output(scalar($input), $pass_part, 1, 0, $obvius);

    $output->param(results=>$pass_part->param('count'));
    $output->param(do_search_page => 1);
    $output->param(htdig_results => join('', @$lines));

    return OBVIUS_OK;
}

sub action {
    my ($this, $input, $output, $doc, $vdoc, $obvius) = @_;

    $this->tracer($input, $output, $doc, $vdoc, $obvius) if ($this->{DEBUG});

    my $results = 0;
    my $config = $obvius->OBVIUS_CONFIG;

    # Just show the page if we're not doing a search
    my $op = $input->param('op') || ($input->param('q') ? 'search' : '');
    if($op) {
        unless($op eq 'search') {
            if($op eq 'search_page') {
                return $this->do_search_page($input, $output, $obvius);
            } else {
                $output->param('print_form' => 1);
                return OBVIUS_OK;
            }
        }
    } else {
        $output->param('print_form' => 1);
        return OBVIUS_OK;
    }

    my $advanced = (defined($input->param('advanced'))
		    and $input->param('advanced') eq 'yes');

    my $search_term;
    my $search_method = 'and';

    if ($advanced) {
	my $first = 1;

	my @w1 = $this->get_search_words($input->param('words1'));
	if (@w1) {
	    $search_term = '(' . join(' and ', @w1) . ')';
	    $first = 0;
	}

	my @w2 = $this->get_search_words($input->param('words2'));
	if (@w2) {
	    $search_term .= (' ' . $input->param('bool2') . ' ') unless ($first);
	    $search_term .= '(' . join(' and ', @w2) . ')';
	    $first = 0;
	}

	my @w3 = $this->get_search_words($input->param('words3'));
	if (@w3) {
	    $search_term .= (' ' . $input->param('bool3') . ' ') unless ($first);
	    $search_term .= '(' . join(' and ', @w3) . ')';
	    $first = 0;
	}

	my @w4 = $this->get_search_words($input->param('words4'));
	if (@w4) {
	    $search_term .= (' ' . $input->param('bool4') . ' ') unless ($first);
	    $search_term .= '(' . join(' and ', @w4) . ')';
	    $first = 0;
	}

	return OBVIUS_OK if ($first); # XXX Orig. HTTP_NO_CONTENT

	$search_method = 'boolean';
    } else {
	my @words = $this->get_search_words($input->param('words') || $input->param('q'));
	return OBVIUS_OK unless (@words); # XXX Orig. HTTP_NO_CONTENT

	$search_term = join(' and ', @words);
	$search_method = 'boolean';
    }

    my $search_type=$input->param('search_type');
    # Add _substring to the search_type if it's defined (backwards compability) _and_ there
    # is a truncation marker (*) in there (doesn't work as one would expect truncation to
    # but it's as close as we'll ever get with htdig):
    my $raw_words=join " ", map { defined $_ ? $_ : '' } (
                                                          $input->param('words'),
                                                          $input->param('words1'),
                                                          $input->param('words2'),
                                                          $input->param('words3'),
                                                          $input->param('words3')
                                                         );
    $search_type .= '_substring' if (defined $search_type and ($raw_words =~ /\b[*]/));

    # print STDERR ("Search words _${search_term}_\n");
    $output->param(search_term => $search_term);
    $output->param(words => $input->param('words'));
    $output->param(search_type => $search_type);

    my %args = (
		words => $search_term,
		method => $search_method,
		format => 'short',
		matchesperpage => 10,
		config => $this->htdig_config_name($obvius, $input) . (defined $search_type ? '_' . $search_type : ''),
		restrict => '',
		exclude => '',
	       );

    my @data;

    # When we reach this point we will always do an actually search
    $output->param(Obvius_DEPENCIES => 1);

    if ($advanced and $input->param('restrict')) {
	my $base = $input->param('restrict');
	my $junk;
	my @path = $obvius->get_doc_by_path($base, \$junk);
	my $part = $path[-1];

	$args{restrict} = 'http://' . ($config->param('HTDIG_SITENAME') || $config->param('SITENAME')) . $base;

	my $vpart=$obvius->get_public_version($part);
	$obvius->get_version_fields($vpart, [ 'title' ]);
        # Pass name (for read_htdig_output):
        $vpart->param(name=>$part->Name);

        my $pass_part=$vpart || $part;

	$output->param(OBVIUS_SIDE_EFFECTS => 1); # htdig could do anything....
        my $lines = read_htdig_output(\%args, $pass_part, 1, 0, $obvius);

	push(@data, ({
		      title => $vpart->Title,
		      section => $pass_part->Name,
		      htdig_results => join('', @$lines),
		      count => $pass_part->param('count'),
		     })
	    );
	$results += $pass_part->param('count');

	$output->param(restrict=>$base);
    } else {
	my $base = 'http://' . ($config->param('HTDIG_SITENAME') || $config->param('SITENAME')) . '/';

	my @path = $obvius->get_doc_by_path('/');

	my $rootid = $obvius->{ROOTID} || 1;
	my $top = $obvius->get_doc_by_id($rootid);	# ROOT DEP

	my $doc;
	my $first_level = $obvius->get_document_subdocs($top);

	for (@$first_level) {
	    $obvius->get_version_fields($_);
	    $obvius->get_version_fields($_, [ 'seq' ]);
	    $doc = $obvius->get_doc_by_id($_->param('docid'));
	    $_->param(name=>$doc->param('name'));
	}

	my $watermark=$input->param('watermark') || 0;
	my @main_parts;
	my @other_parts;
	if ($input->param('watermark_exact')) {
	    @main_parts = grep { $_->Seq == $watermark } @$first_level;
	    @other_parts = grep { $_->Seq != $watermark } @$first_level;
	}
	else {
	    @main_parts = grep { $_->Seq >= $watermark } @$first_level;
	    @other_parts = grep { $_->Seq < $watermark } @$first_level;
	}

	my $part;
	foreach $part (@main_parts) {
	    $args{restrict} = $base . lc($part->param('name')) . '/';

	    $output->param(Obvius_SIDE_EFFECTS => 1); # htdig could do anything....
	    my $lines = read_htdig_output(\%args, $part, 1, 1, $obvius);

	    push(@data, ({
			  title => $part->Title,
			  section => $part->Name,
			  htdig_results => join('', @$lines),
			  count => $part->Count,
			 })
		);
	    $results += $part->Count;
	}

	$args{restrict} = '';
	$args{exclude} = join('|',  map {$base . $_->Name . '/';} @main_parts);

	$part = new Obvius::Version({title=>'Andet', name=>'andet'});

	$output->param(Obvius_SIDE_EFFECTS => 1); # htdig could do anything....
	my $lines = read_htdig_output(\%args, $part, 1, 1, $obvius);

	push(@data, ({
		      title => $part->Title,
		      section => $part->Name,
		      htdig_results => join('', @$lines),
		      count => $part->Count,
		     })
	    );
        $results += $part->Count;
    }

    $output->param(results => $results);
    $output->param(search_data => \@data);

    return OBVIUS_OK;
}


1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Obvius::DocType::Search - Interface to htdig

=head1 SYNOPSIS

  use'd by Obvius automatically.

=head1 DESCRIPTION

This module is due for a rewrite. It's incoherent and utterly
incomprehensible. Somebody do a rewrite. Soon. Please.

=head2 EXPORT

None by default.

=head1 AUTHOR

=head1 SEE ALSO

L<Obvius>.

=cut
