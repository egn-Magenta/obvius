package Obvius::DocType::KeywordSearch;

use 5.006;
use strict;
use warnings;

use Obvius;
use Obvius::DocType;

use Date::Calc qw( Week_of_Year Add_Delta_YMD Monday_of_Week);

our @ISA = qw( Obvius::DocType );
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub action {
    my ($this, $input, $output, $doc, $vdoc, $obvius) = @_;


    $output->param(input => $input);


    $this->tracer($input, $output, $doc, $vdoc, $obvius) if ($this->{DEBUG});


    my $session = $input->param('session') || {};
    my $sesdocs = $session->{docs};

    if($sesdocs and scalar(@$sesdocs)) {
        # Carry on session ID
        $output->param('SESSION_ID' => $session->{_session_id}) if($session->{_session_id});

        my $pagesize = $session->{pagesize};
        my $require = $session->{require};
        if($pagesize) {
            my $page = $input->param('p') || 1;
            $this->export_paged_doclist($pagesize, $sesdocs, $output, $obvius,
                                        name=>'kwdocs',
                                        page=>$page,
                                        require=>$require,
                                        include_images=>1,
                                    );
        } else {
            $this->export_doclist($sesdocs,  $output, $obvius,
                                    name=>'kwdocs',
                                    #prefix => $prefix,
                                    require=>$require,
                                    include_images=>1,
                        );
        }

        return OBVIUS_OK;
    }


    my $prefix = $output->param('PREFIX');
    my $is_admin = $input->param('IS_ADMIN');

    $obvius->get_version_fields($vdoc, [qw(search_expression base search_type show_hidden pagesize)]);
    my %args=(base=>$vdoc->Base);
    my $search_expression = $vdoc->field('search_expression');
    if($search_expression) {
	$search_expression =~ s/\r//g;
	$search_expression =~ s/\n+$//g;
    }
    $args{$vdoc->Search_type}= $search_expression if ($vdoc->field('search_type'));

    my $basedoc=$doc;
    my $baseid=$doc->Id;
    $output->param(Obvius_DEPENCIES => 1);
    if ($basedoc=$obvius->lookup_document($args{base}))
    {
	$baseid=$basedoc->Id;
    }

    $args{base} = $input->param('base') if (defined $input->param('base'));
    $args{keyword} = $input->param('kw') if (defined $input->param('kw'));
    $args{category} = $input->param('cat') if (defined $input->param('cat'));
    $args{month} = $input->param('month') if (defined $input->param('month'));
    $args{weeks} = $input->param('weeks') if (defined $input->param('weeks'));

    my @kwdocs;
    my $kwdocs;

    my %options=(
		 needs_document_fields => [ 'parent' ],
		 sortvdoc => $vdoc,
		 notexpired=>!$is_admin,
		 public=>!$is_admin,
		);
    if (my $kw = $args{keyword}) {
        $kw =~ s/'/\\'/g;
        $kwdocs = $obvius->search(
                                    [ 'keyword' ],
                                    "keyword LIKE '$kw' and parent = ". $baseid,
                                    %options,
                                );
    }
    elsif ($args{category}) {
	$kwdocs = $obvius->search(
				[ 'category' ],
				"category = '$args{category}' and parent = ". $baseid,
				%options,
			       );
    }
    elsif ($args{month}) {
        $args{month} =~ tr/ \t//d;
##/
        if ($args{month} =~ /^(\d{4})-(\d{2})$/) {

	    # Argh! Lots of unholy magic to get the weekmin and weekmax parameters
	    my $year = $1;
	    my $month = $2;
	    my $day = '01';
	    my ($weekmin, $weekmax);
	    ($weekmin, $year) = Week_of_Year($year, $month, $day);
	    my ($year2, $month2, $day2) = Add_Delta_YMD($year, $month, $day, 0, 1, -1);
	    ($weekmax, $year2) = Week_of_Year($year2, $month2, $day2);

	    $weekmin = sprintf("%4.4d%2.2d", $year, $weekmin);
	    $weekmax = sprintf("%4.4d%2.2d", $year2, $weekmax);
            $output->param(weekmin => $weekmin);
            $output->param(weekmax => $weekmax);

	    my $ymd1 = sprintf('%4.4d-%2.2d-%2.2d', $year, $month, $day);
	    my $ymd2 = sprintf('%4.4d-%2.2d-%2.2d', $year2, $month2, $day2);

	    $kwdocs = $obvius->search([ 'docdate' ],
				    "docdate >= \'".$ymd1."\' and docdate <= \'".$ymd2."\' and parent = ". $baseid,
				    %options,
				   );
        }
    }
    elsif ($args{weeks}) {
        $args{weeks} =~ tr/ \t//d;
##/
	my ($y1, $w1, $y2, $w2) = ($args{weeks} =~ /^(\d{4})(\d{2})-(\d{4})(\d{2})$/g);
        $output->param(weekmin => "$y1$w1");
        $output->param(weekmax => "$y2$w2");

	my ($year, $month, $day) = Monday_of_Week($w1, $y1);
	my ($year2, $month2, $day2) = Monday_of_Week($w2, $y2);

	#We don't want Monday, we want Sunday
	($year2, $month2, $day2) = Add_Delta_YMD($year2, $month2, $day2, 0, 0, 6);

	my $ymd1 = sprintf('%4.4d-%2.2d-%2.2d', $year, $month, $day);
	my $ymd2 = sprintf('%4.4d-%2.2d-%2.2d', $year2, $month2, $day2);

	$kwdocs = $obvius->search([ 'docdate' ],
				"docdate >= \'".$ymd1."\' and docdate <= \'".$ymd2."\' and parent = ". $baseid,
				%options,
			       );
    }
    else {
        $kwdocs = $obvius->get_document_subdocs($basedoc,
                                              sortvdoc=>$vdoc,
					      nothidden=>(defined $vdoc->field('show_hidden') ?
							  1-$vdoc->field('show_hidden') :
							  1),
                                              public=>!$is_admin,
					     );
    }

    # This is handled by search when public is 1!
    #if ($kwdocs) {
    #	my @kwdocs=grep { $obvius->is_public_document($obvius->get_doc_by_id($_->Docid)) } @$kwdocs;
    #	$kwdocs=\@kwdocs;
    # }

    # my %baseargs = $base->document_options;

    my $pagesize = $vdoc->field('pagesize');
    my $require = $args{require} || '';

    if ($kwdocs) {
        if ($pagesize) {
            my $page = $input->param('p') || 1;
            $this->export_paged_doclist($pagesize, $kwdocs, $output, $obvius,
                            name=>'kwdocs', page=>$page,
                            prefix => $prefix,
                            require=>$require,
                        include_images=>1,
                        );
        } else {
            $this->export_doclist($kwdocs,  $output, $obvius,
                    name=>'kwdocs',
                    prefix => $prefix,
                    require=>$require || '',
                    include_images=>1,
                    );
        }

        # Store stuff in session
        $session->{docs} = $kwdocs;
        $session->{pagesize} = $pagesize;
        $session->{require} = $require;
        $output->param('session' => $session);
    }



    return OBVIUS_OK;
}


1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Obvius::DocType::KeywordSearch - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Obvius::DocType::KeywordSearch;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Obvius::DocType::KeywordSearch, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head2 EXPORT

None by default.


=head1 AUTHOR

A. U. Thor, E<lt>a.u.thor@a.galaxy.far.far.awayE<gt>

=head1 SEE ALSO

L<perl>.

=cut
