package WebObvius::Template::Provider;

use 5.006;
use strict;
use warnings;

our @ISA = qw();
our $VERSION="1.0";

use Net::SMTP;

sub new {
    my ($class, %options) = @_;

    $class = ref $class if (ref $class);
    my $this = {
		DEBUG => $options{debug} || 0,
		OBVIUS => undef,
		DOCUMENT => undef,
		VERSION => undef,
		DOCTYPE => undef,
		SITE => undef,
		REQUEST => undef,
	       };

    while (my ($k, $v) = each %options) {
	$k = uc($k);
	if (exists $this->{$k}) {
	    $this->{$k} = $v;
	    print STDERR __PACKAGE__, ": $k = $v\n" if ($this->{DEBUG});
	}
    }

    bless $this, $class;
}

sub set_options {
    my ($this, %options) = @_;

    while (my ($k, $v) = each %options) {
	$k = uc($k);
	if (exists $this->{$k}) {
	    $this->{$k} = $v;
	    print STDERR __PACKAGE__, ": $k = $v\n" if ($this->{DEBUG});
	}
    }

    return $this;
}

sub make_field_map {
    my ($this, $fields) = @_;

    my %map;
    for (@$fields) {

	if (/^(\w+)=(\w+)$/) {
	    $map{$2} = $1;
	}
	elsif (/^\w+$/) {
	    $map{$_} = $_;
	}
	else {
	    $map{$_} = undef;
	}
    }
    return \%map;
}

sub object_fields_by_map {
    my ($this, $objlist, $template, $map) = @_;

    for my $from (keys %$map) {
	my $to = $map->{$from};
	next if (defined $template->param($to));

	if ($to) {
	    for my $obj (@$objlist) {
		if (my $value = $obj->param($from)) {
		    $template->param($to => $value);
		    last;
		}
	    }
	} else {
	    $template->template_error("version_fields: $_ is not a valid field");
	}
    }
    return 1;
}

sub object_fields {
    my ($this, $obj, $template, $fields, $caller) = @_;

    if (scalar(@$fields) == 1 and $fields->[0] eq '*') {
	$fields = [ $obj->param ];
    }

    return $this->object_fields_by_map($obj, $template, $this->make_field_map($fields), $caller);
}

sub get_all {
    my ($this) = @_;

    return (
	    $this->{SITE}, $this->{REQUEST},
	    $this->{OBVIUS}, $this->{DOCUMENT},
	    $this->{VERSION}, $this->{DOCTYPE}
	   );
}

sub site     { return shift->{SITE};     }
sub request  { return shift->{REQUEST};  }
sub obvius   { return shift->{OBVIUS};   }
sub doc	     { return shift->{DOCUMENT}; }
sub vdoc     { return shift->{VERSION};  }
sub doctype  { return shift->{DOCTYPE};  }

sub get_version_field {
    my ($this, $name) = @_;
    return $this->obvius->get_version_field($this->vdoc, $name);
}


########################################################################
#
#	Document related methods
#
########################################################################

#needs document_field *
#needs document_field field ... name=field ...
sub provide_document_field {		# RS 20010813 - ok
    my ($this, $template, @args) = @_;

    my $map = $this->make_field_map(\@args);
    $this->obvius->get_version_fields($this->vdoc, [ keys %$map ]);
    return $this->object_fields_by_map([ $this->vdoc->{FIELDS}, $this->vdoc, $this->doc ],
				       $template, $map);
}

#needs version_field *
#needs version_field field ... name=field ...
sub provide_version_field {		# RS 20010813 - ok
    my $this = shift;
    return $this->provide_document_field(@_);
}



#needs document_parm param name
sub provide_document_parm {		# RS 20010802 - ej testet
    my ($this, $template, $param, $name) = @_;

    return undef uless ($param);
    $name ||= $param;
    return 1 if (defined $template->param($name));

    my ($site, $req, $obvius, $doc, $vdoc, $doctype) = $this->get_all;

    $template->param($name => $obvius->get_docparam_value($doc, $param));
    return 1;
}

#needs mini_icon [ name ]  (default: "mini_icon")
sub provide_mini_icon {			# RS 20010802 - ej testet
    my ($this, $template, $name) = @_;

    return $this->provide_document_parm($template, 'mini_icon', $name);
}

#needs subdocs [ name [ opt=value ...] ] (default name="subdocs")
#	bruger pager
#	option:	all=1
#		require=teaser|full-info
sub provide_subdocs {			# RS 20010813 - ok
    my ($this, $template, $name, @opts) = @_;

    $name ||= 'subdocs';
    return 1 if (defined $template->param($name));

    my ($site, $req, $obvius, $doc, $vdoc, $doctype) = $this->get_all;
    my $prefix = $req->notes('prefix');

    my %opts;
    for (@opts) {
	my ($k, $v) = split('=', $_, 2);
	$opts{$k} = $v || 1;
    }

    # Sub-documents
    $obvius->get_version_fields($vdoc, ['pagesize', 'require']);
    if ($vdoc->field('pagesize')) {
	my $page = $req->param('p');
	$site->export_paged_subdocs($doc, $prefix, $template,
				    name=>$name, page=>$page,
				    require=>$opts{require} || $vdoc->field('require'),
				   );
    } else {
	$site->export_subdocs($doc, $prefix, $template,
			      name=>$name,
			      require=>$opts{require} || $vdoc->field('require'),
			     );
    }
    return 1;
}

#needs section_info [ prefix ]  (default: "section")
#	definerer SECTION=name SECTION_name=1 SECTION_title=title
sub provide_section_info {		# RS 20010813 - ok
    my ($this, $template, $tname) = @_;

    $tname ||= 'section';
    return 1 if (defined $template->param($tname));

    my ($site, $req, $obvius, $doc, $vdoc, $doctype) = $this->get_all;

    my $prefix = $req->notes('prefix');
    my @path = $obvius->get_doc_path($doc);
    my $section = $path[1];

    if (defined $section) {
	my $name = $section->param('name');
	$name =~ tr/-/_/;
	$name =~ s/\W+//g;
	$template->param("${tname}_$name" => 1);
	$template->param($tname => $name);

	my $section_version = $obvius->get_public_version($section);
	die 'Failed to find public version of section' unless ($section_version);

	$template->param("${tname}_title" => $section_version->param('title'));
    }
    return 1;
}


#needs top_level_menu [ name ]  (default: "top_menu")
#	laver to-niveau top-menu
sub provide_top_level_menu {		# RS 20010802 - ej testet
    my ($this, $template, $menu_name) = @_;

    $menu_name ||= 'top_menu';
    return 1 if (defined $template->param($menu_name));

    my ($site, $req, $obvius, $doc, $vdoc, $doctype) = $this->get_all;
    my $prefix = $req->notes('prefix');

    my @path = $obvius->get_doc_path($doc);
    my $section = $path[1];

    my $top = $obvius->get_doc_by_id(1);	# ROOT DEP
    my $first_level = $obvius->get_document_subdocs($top);

    my @top_menu = ();
    for (@$first_level) {
	$obvius->get_version_fields($_);

	next if ($_->field('seq') >= 100 or $_->param('seq') < 0);

	my $subdoc = $obvius->get_doc_by_id($_->DocId);

	my $name = $_->Name;
	$name =~ tr/-/_/;
	$name =~ s/\W+//g;

	push(@top_menu, {
			 url => $prefix . $obvius->get_doc_uri($subdoc),
			 title => $_->Title,
			 name => $name,
			 subdocs => [ map { ({
					      url => $prefix . $obvius->get_doc_uri($_->[0]),
					      title => $_->field('title'),
					     })
					} map {
					    $obvius->get_version_fields($_);
					    [ $obvius->get_doc_by_id($_->DocId), $_ ]
					} $obvius->get_document_subdocs($subdoc)
				    ],
			 active => (defined($section) and $_->DocId == $section->Id),
			});
    }

    $template->param($menu_name => \@top_menu);
    return 1;
}


#needs second_level_menu [ name ]  (default: "sub_menu")
#	Laver andet-niveaus menu
sub provide_second_level_menu {		# RS 20010813 - ok
    my ($this, $template, $menu_name) = @_;

    $menu_name ||= 'sub_menu';
    return 1 if (defined $template->param($menu_name));

    my ($site, $req, $obvius, $doc, $vdoc, $doctype) = $this->get_all;
    my $prefix = $req->notes('prefix');

    my @path = $obvius->get_doc_path($doc);
    my $section = $path[1];
    my $subsection = $path[2];

    $site->export_subdocs($section, $prefix, $template,
			  name=>$menu_name, active=>$subsection)
	if (defined $section);

    return 1;
}


#needs categories [ name ]  (default: "categories")
sub provide_categories {		# RS 20010805 - ej testet - nok
                                        # ok qua provide_keywords
    my ($this, $template, $name) = @_;

    $name ||= 'categories';
    return 1 if (defined $template->param($name));

    my $categories = $this->get_version_field('category');
    return undef unless ($categories);

    $template->export_arraydata($name => $categories, [ qw(name id) ]);
    return 1;
}

#needs keywords [ name ]  (default: "keywords")
sub provide_keywords {			# RS 20010816 - ok
    my ($this, $template, $name) = @_;

    $name ||= 'keywords';
    return 1 if (defined $template->param($name));

    my $keywords = $this->get_version_field('keyword');
    return undef unless ($keywords);

    $template->export_arraydata($name => $keywords, [ qw(name id) ]);
    return 1;
}


#needs document_path [ name ]  (default: "path")
sub provide_document_path {		# RS 20010813 - ok
    my ($this, $template, $name) = @_;

    $name ||= 'path';
    return 1 if (defined $template->param($name));

    my ($site, $req, $obvius, $doc, $vdoc, $doctype) = $this->get_all;

    my $prefix = $req->notes('prefix');
    my @path = $obvius->get_doc_path($doc);
    my $self = pop(@path);		# remove this doc
    my $root = shift(@path);		# get the root
    return 1 unless ($root);		# this is the root doc

    my $path_uri = "$prefix/";

    my @pathdata = ();
    push(@pathdata, {
		     url => $path_uri,
		     title => $obvius->get_public_version_field($root, 'title'),
		    });

    for (@path) {
	$path_uri .= $_->Name . '/';
	push(@pathdata, {
			 url => $path_uri,
			 title => $obvius->get_public_version_field($_, 'title'),
			});
    }

    $template->param($name, \@pathdata);
    return 1;
}


#needs newsitems [ name [max] ]  (default: "newsitems")
sub provide_newsitems {			# RS 20010806 - ej testet
    my ($this, $template, $name, $max) = @_;

    $name ||= 'newsitems';
    return 1 if (defined $template->param($name));

    my ($site, $req, $obvius, $doc, $vdoc, $doctype) = $this->get_all;

    my $prefix = $req->notes('prefix');
    my @path = $obvius->get_doc_path($doc);
    my $section = $path[1];
    if (defined $section) {
	my $vdoc = $obvius->get_public_version($section);
	if ($vdoc->get_version_field('seq') < 0) {
	    undef $section;
	}
    }

    my $hits;
    my $hits2;

    $max ||= 6;

    my $age = '(UNIX_TIMESTAMP()-UNIX_TIMESTAMP(published))/(24*60*60)';
    if (defined $section) {
	my $section_id = $section->param('id');

	$hits2 = $obvius->search([ qw(public expires lprio lsection published lduration) ],
			       ('public > 0 AND expires > NOW() AND lprio = 1'
				. " AND lsection = $section_id AND $age <= lduration"),
			       order => ' ORDER BY published DESC',
			       limit => 1,
			      );
	$hits = $obvius->search([ qw(public expires lprio lsection published lduration) ],
			      ('public > 0 AND expires > NOW() AND lprio > 1'
			       . " AND lsection = $section_id AND $age <= lduration"),
			      order => 'lprio DESC, published DESC',
			      limit => (($hits2 and @$hits2) ? $max-1 : $max),
			     );
    }

    unless ((($hits and @$hits) or ($hits2 and @$hits2))) {
	$hits2 = $obvius->search([ qw(public expires gprio published gduration) ],
			       ('public > 0 AND expires > NOW() AND gprio = 1'
				. " AND $age <= gduration"),
			       order => 'published DESC',
			       limit => 1,
			      );

	$hits = $obvius->search([ qw(public expires gprio published gduration) ],
			       ('public > 0 AND expires > NOW() AND gprio > 1'
				. " AND $age <= gduration"),
			       order => 'published DESC',
			       limit => (($hits2 and @$hits2) ? $max-1 : $max),
			      );
    }

    return 1 unless (($hits and @$hits) or ($hits2 and @$hits2));

    my @newsitems = ();
    foreach my $vdoc (@$hits, @$hits2) {
	my $doc = $obvius->get_doc_by_id($vdoc->DocId);
	$obvius->get_version_fields($vdoc);

	push(@newsitems, {
			  url => $prefix . $obvius->get_doc_uri($doc),
			  date => $vdoc->field('docdate'),
			  title => $vdoc->field('title'),
			  teaser => $vdoc->field('teaser'),
			  icon => $obvius->get_docparam_value_recursive($doc, 'mini_icon'),
			 });
    }

    $template->param($name, \@newsitems);

    return 1;
}


#needs doctype_news NAME PATH [ TIME ]
sub provide_doctype_news {		# XXX ej konverteret
    my ($this, $template, $name, $path, $time) = @_;

    return undef unless ($name and $name =~ /^\w+$/ and $path);
    return 1 if (defined $template->param($name));

    my $site = $this->{SITE};
    return undef unless ($site);

    $time = 24 unless ($time and $time =~ /^\d+$/);
    $time *= 60*60;

    my @path = $site->get_doc_by_path($path);
    unless (@path) {
	$template->template_error("make_doctype_news: path $path not found.");
	return undef;
    }

    my $doc = $path[-1];
    my %doctypes = map { split(/\s*=\s*/, "\L$_\E", 2) } grep {/=/} split(/\n+/, $doc->helptext);
    my $doctypes = join(', ', map { $site->{DB}->quote($_) } keys %doctypes);

    my $query = ('SELECT LOWER(vdocs.doctype) AS doctype, COUNT(docs.id) AS count'
		 . ' FROM docs,vdocs'
		 . ' WHERE docs.id=vdocs.id AND docs.version=vdocs.version'
		 . '   AND docs.public >0 AND docs.expires >= NOW()'
		 . "   AND vdocs.doctype IN ($doctypes)"
		 . '   AND (UNIX_TIMESTAMP()-UNIX_TIMESTAMP(vdocs.version)) < ' . $time
		 . ' GROUP BY vdocs.doctype'
		 . ' ORDER BY count DESC');

    my $data = $site->{DB}->select($query);
    unless ($data) {
	$template->template_error("make_doctype_news: search failed");
	return undef;
    }

    for (@$data) {
	$_->{url} = $doctypes{$_->{doctype}};

	@path = $site->get_doc_by_path($_->{url});
	$_->{title} = $path[-1]->param('title') if (@path);
    }
    $template->param($name => $data);

    return 1;
}

#needs daily_news NAME [ MAX [ MAXTYPE [ DAYS ]]]
sub provide_daily_news {		# XXX ej konverteret
    my ($this, $template, $name, $max, $maxtype, $days) = @_;

    return undef unless ($name and $name =~ /^\w+$/);
    return 1 if (defined $template->param($name));

    my $site = $this->{SITE};
    return undef unless ($site);

    $max = 12 unless ($max and $max =~ /^\d+$/);
    $maxtype = 3 unless ($maxtype and $maxtype =~ /^\d+$/);
    $days = 2 unless ($days and $days =~ /^\d+$/);

    my $query = ('SELECT DISTINCT docs.id AS id,'
		 . '     vdocs.docdate AS docdate,'
		 . '     vdocs.doctype AS doctype,'
		 . '     vdocs.url AS url,'
		 . '     vdocs.teaser AS teaser,'
		 . '     vdocs.title AS title'
		 . ' FROM docs, vdocs'
		 . ' WHERE docs.id=vdocs.id AND docs.version=vdocs.version'
		 . '   AND docs.public > 0 AND docs.expires >= NOW()'
		 . '   AND doctype LIKE \'Nyhedsartikel fra %\''
		 . "   AND ((vdocs.docdate > DATE_SUB(NOW(), INTERVAL $days DAY)))"
		 . ' ORDER BY vdocs.docdate DESC, vdocs.title'
		 . ' LIMIT ' . $max*$maxtype
		);

    my $data = $site->{DB}->select($query);
    unless ($data) {
	$template->template_error("make_daily_news_hook: search failed");
	return undef;
    }

    #print STDERR Dumper($data);

    my %types;
    $template->param($name => [ grep { $types{$_->{doctype}}++ < $maxtype and --$max >= 0 } @$data ]);

    return 'ok';
}

########################################################################
#
#	Mail related methods
#
########################################################################

#needs send_mail_ok NAME MAILMSG MAILTO
sub provide_send_mail_ok {
    my ($this, $template, $name, $mailtemplate, $mailto, $from) = @_;

    return undef unless ($name and $name =~ /^\w+$/);
    return 1 if (defined $template->param($name));

	print STDERR "jubk: Recipient: $mailto\n";

	$mailtemplate = $template->param($mailtemplate);
	$mailto = $template->param($mailto);

	print STDERR "jubk: Recipient: $mailto\n";

	unless ($mailtemplate) {
		$template->param($name => "No mail template specified\n");
		return 1;
	}

	unless ($mailto) {
		$template->param($name => "No recipient specified\n");
		return 1;
	}

	#Send the email
	$from = $from ? $template->param($from) : $template->param('Email');
    $template->param(from => $from);

    # Expand the mail template
	my $msg = $template->expand($mailtemplate);


	my $smtp = Net::SMTP->new($this->obvius->config->param('smtp') || 'localhost', Timeout=>30, Debug => 1);
    unless ($smtp->mail($from)) {
		$template->param($name => "Failed to specify a sender [$from]\n");
		return 1;
	}
    unless ($smtp->to($mailto)) {
		$template->param($name => "Failed to specify a recipient [$mailto]\n");
		return 1;
	}
    unless ($smtp->data([$msg])) {
		$template->param($name => "Failed to send a message\n");
		return 1;
	};
    unless ($smtp->quit) {
		$template->param($name => "Failed to quit\n");
		return 1;
	};

    $template->param($name => 'ok');

    return 1;
}




########################################################################
#
#	Version related methods
#
########################################################################

#needs template_file [ name ]  (default: "template_file")
sub provide_template_file {		# RS 20010813 - ok
    my ($this, $template, $name) = @_;

    $name ||= 'template_file';
    return 1 if (defined $template->param($name));

    my $doctmpl = $this->get_version_field('template');
    return undef unless ($doctmpl);

    $template->param($name => $doctmpl->param('file'));
    return 1;
}

#needs image_file [ name ]  (default: "image_file")
sub provide_image_file {		# RS 20010813 - ok
    my ($this, $template, $name) = @_;

    $name ||= 'image_file';
    return 1 if (defined $template->param($name));

    $template->param($name => $this->get_version_field('image_file'));

    return 1;
}


########################################################################
#
#	Funktioner til at lave require=... i templates
#
########################################################################

#needs loopdata document [name=]field ...
sub require_document_fields {		# RS 20010806 - ej testet
    my ($this, $list, $fields) = @_;

    #print STDERR "HOOK require_document_fields: @$fields\n";

    for (@$list) {
	for my $f (@$fields) {
	    my ($n, $v) = ($f =~ /^(\w+)=(\w+)$/);
	    $n ||= $f;
	    $v ||= $f;
	    #print STDERR "HOOK require_document_fields: $v => $n\n";

	    my $doc = $this->obvius->get_doc_by_id($_->{id});
	    $_->{$n} = $doc->param($v);
	}
    }
}

#needs loopdata document [name=]field ...
sub require_document_params {		# RS 20010806 - ej testet
    my ($this, $list, $fields) = @_;

    #print STDERR "HOOK require_document_params: @$fields\n";

    for (@$list) {
	for my $f (@$fields) {
	    my ($n, $v) = ($f =~ /^(\w+)=(\w+)$/);
	    $n ||= $f;
	    $v ||= $f;
	    #print STDERR "HOOK require_document_params:: $v => $n\n";

	    my $doc = $this->obvius->get_doc_by_id($_->{id});
	    $_->{$n} = $this->obvius->get_docparam_value_recursive($doc, $v);
	}
    }
}

#needs loopdata version [name=]field ...
sub require_version_fields {		# RS 20010806 - ej testet
    my ($this, $list, $fields) = @_;

    #print STDERR "HOOK require_version_fields: @$fields\n";

    for (@$list) {
	for my $f (@$fields) {
	    my ($n, $v) = ($f =~ /^(\w+)=(\w+)$/);
	    $n ||= $f;
	    $v ||= $f;
	    #print STDERR "HOOK require_version_fields: $v => $n\n";

	    my $doc = $this->obvius->get_doc_by_id($_->{id});
	    my $vdoc = $this->obvius->get_public_version($doc);
	    my $field = $this->obvius->get_version_field($vdoc, $v);

	    $_->{$n} = $field || $vdoc->param($v);
	}
    }
}

#needs loopdata new_date (indicator for changing dates)
sub require_new_date {			# RS 20010806 - ej testet
    my ($this, $list) = @_;

    my $last_date = '**';

    for (@$list) {
	$_->{new_date} = ($last_date ne $_->{docdate});
	$last_date = $_->{docdate};
    }
}

#needs loopdata new_title (indicator for changing initial title letter)
sub require_new_title {			# RS 20010806 - ej testet
    my ($this, $list) = @_;

    my $last_title = '**';

    for (@$list) {
	my $first_letter = uc(substr($_->{title}, 0, 1));
	$_->{new_title} = ($last_title ne $first_letter) ? $first_letter : '';
	$last_title = $first_letter;
    }
}

#needs loopdata image_file
sub require_image_file {		# RS 20010806 - ej testet
    my ($this, $list) = @_;
    $this->require_version_fields($list, 'image_file');
}

#needs loopdata mini_icon
sub require_mini_icon {			# RS 20010806 - ej testet
    my ($this, $list) = @_;

    $this->require_document_params($list, 'mini_icon');
}

#needs loopdata teaser
sub require_teaser {			# RS 20010806 - ej testet
    my ($this, $list) = @_;

    $this->require_version_fields($list,
				  [ 'title', 'short_title', 'teaser',
				    'docdate', 'docref', 'doctype',
				    'source', 'contributors',
				    'extern_url=url', 'seq',
				    'image'
				  ]
				 );
    $this->require_image_file($list);
    $this->require_new_date($list);
    $this->require_new_title($list);
}

#needs loopdata full-info
sub require_full_info {			# RS 20010806 - ej testet
    my ($this, $list) = @_;

    $this->require_teaser($list);
    $this->require_version_fields($list, [ 'content']);
}

#needs loopdata keywords
sub require_keywords {			# RS 20010806 - ej testet
    my ($this, $list) = @_;

    for (@$list) {
	next if (defined $_->{keywords});

	my $doc = $this->obvius->get_doc_by_id($_->{id});
	my $vdoc = $this->obvius->get_public_version($doc);

	$_->{keywords} = [ map { my $h;
				 $h->{lc $_} = $_->param($_) for ($_->param);
				 $h;
			     } @{ $vdoc->field('keyword') }
			 ];
    }
}

#needs loopdata categories
sub require_categories {		# RS 20010806 - ej testet
    my ($this, $list) = @_;

    for (@$list) {
	next if (defined $_->{categories});

	my $doc = $this->obvius->get_doc_by_id($_->{id});
	my $vdoc = $this->obvius->get_public_version($doc);

	$_->{categories} = [ map { my $h;
				   $h->{lc $_} = $_->param($_) for ($_->param);
				   $h;
			       } @{ $vdoc->field('category') }
			   ];
    }
}

our %require_handlers = (
			 teaser => \&require_teaser,

			 content => \&require_full_info,
			 all => \&require_full_info,
			 'full-info' => \&require_full_info,

			 new_date => \&require_new_date,
			 'new-date' => \&require_new_date,

			 new_title => \&require_new_title,
			 'new-title' => \&require_new_title,

			 image_file => \&require_image_file,
			 'image-file' => \&require_image_file,

			 mini_icon => \&require_mini_icon,
			 'mini-icon' => \&require_mini_icon,

			 keywords => \&require_keywords,
			 categories => \&require_categories,

			 document => \&require_document_fields,

			 version => \&require_version_fields,
			 fields => \&require_version_fields,

			 '*' => \&require_version_fields,
			);

sub provide_loopdata {			# RS 20010806 - ej testet
    my ($this, $template, $name, $type, @fields) = @_;

    #print STDERR "HOOK require: $name $type @fields\n";

    my $value = $template->param($name);
    return undef unless (ref($value));

    my $handler = $require_handlers{lc($type)};
    unless ($handler) {
	$handler = $require_handlers{'*'};
	unshift(@fields, $type);
    }
    return undef unless ($handler);

    #print STDERR "HOOK require: handler ok\n";

    $handler->($this, $value, \@fields);

    return 1;
}






########################################################################
#
#	Utility methods (relies on template-object only)
#
########################################################################

#needs mapped_upload_url name
#	Fjerne evt. indledende = fra NAME
sub provide_mapped_upload_url {		# ikke ændret
    my ($this, $template, $name) = @_;

    my $url = $template->param($name);
    return undef unless (defined $url);

    if ($url =~ /^=/) {
	$url = substr($url, 1);
	$template->param($name => $url);
    }
    return 1;
}


#needs split_multipart_field NAME
sub provide_split_multipart_field {	# RS 20010806 - ej testet
   my ($this, $template, $name, $dest) = @_;

    my $text = $template->param($name);
    return undef unless (defined $text);

    $dest ||= $name;

    my $parts = $this->{SITE}->split_multipart_data($name => $text);
    for (keys %$parts) {
	#print STDERR "SPLIT Part $_\n";
	$template->param("${dest}_$_" => $parts->{$_});
    }

    return 1;
}

sub provide_splitted_multipart_field {	# Stavepalde
    my $this = shift;
    return $this->provide_split_multipart_field(@_);
}


########################################################################
#
#	Request
#
########################################################################

#needs server_name [ NAME ] (default: "SERVER_NAME")
sub provide_server_name {		# RS 20010806 - ej testet
    my ($this, $template, $name) = @_;

    $name ||= 'SERVER_NAME';
    return 1 if (defined $template->param($name));

    my $req = $this->{REQUEST};

    $template->param($req->server->server_hostname);
    return 1;
}

#needs request_notes DEST[=SRC] ...
sub provide_request_notes {		# RS 20010813 - ok
    my ($this, $template, @names) = @_;

    return undef unless (@names);

    for (@names) {
	my $from;
	my $to;

	if (/^(\w+)=(\w+)$/) {
	    $to = $1;
	    $from = $2;
	}
	elsif (/^\w+$/) {
	    $from = $to = $_;
	}

	if ($to) {
	    $template->param($to => $this->{REQUEST}->notes($from)) unless (defined $template->param($to));
	} else {
	    $template->template_error("request_notes: $_ is not a valid name");
	}
    }
    return 1;
}

#needs request_pnotes DEST[=SRC]
sub provide_request_pnotes {		# RS 20010806 - ej testet
    my ($this, $template, $name) = @_;

    return undef unless ($name);

    my ($dest, $src) = split('=', $name, 2);
    $src ||= $dest;
    return 1 if (defined $template->param($dest));

    $template->param($dest => scalar($this->{REQUEST}->pnotes($src)));
    return 1;
}

#needs request_uri NAME (default: "URI")
sub provide_request_uri {		# RS 20010806 - ej testet
    my ($this, $template, $name) = @_;

    $name ||= 'URI';
    return 1 if (defined $template->param($name));

    $template->param($name => $this->{REQUEST}->uri);
    return 1;
}

#needs request_path_info NAME (default: "PATH_INFO")
sub provide_request_path_info {		# RS 20010806 - ej testet
    my ($this, $template, $name) = @_;

    $name ||= 'URI';
    return 1 if (defined $template->param($name));

    $template->param($name => $this->{REQUEST}->path_info);
    return 1;
}


1;
__END__

# Below is stub documentation for your module. You better edit it!

=head1 NAME

WebObvius::Template::Provider - Perl extension for blah blah blah

=head1 SYNOPSIS

  use WebObvius::Template::Provider;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for WebObvius::Template::Provider, created by h2xs. It looks like the
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
