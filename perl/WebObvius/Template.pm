# $Id$

package WebObvius::Template;

use 5.006;
use strict;
use warnings;

use Carp;
use Data::Dumper;
# use Cwd;

our @ISA = qw();
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

our %Cache = ();			# template cache

sub new {
    my ($class, %hash) = @_;

    my %self = (PATH=>undef,		# search path (arrayref)
		ALWAYS_SEARCH_PATH=>1,	# force a full search each time
		CACHE=>0,		# cache flag
		DEBUG=>0,		# debug flag
		TRACE=>0,		# trace flag  (values 0,1,2,3,4)
		TRACEFILE=>undef,	# trace output file
		WARNINGS=>0,		# print warnings flag
	       );

    my $this = bless \%self, $class;

    my ($k, $v);
    while (($k,$v) = each %hash) {
	$k = uc($k);
	if ($k eq 'PATH') {
	    if (ref($v) eq 'ARRAY') {
		$this->{PATH} = [ @$v ];
	    }
	    elsif (!ref($v)) {
		$this->{PATH} = [ $v ];
	    }
	    else {
		croak("$class: Template path is not a string or arrayref");
	    }
	} 
	elsif (exists($this->{$k})) {
	    $this->{$k} = $v;
	}
	else {
	    carp("$class: Unknown parameter $k");
	}
    }

    $this->{VARS} = {};			# current namespace
    $this->{VARSTACK} =[];		# shadowed name spaces
    $this->{HOOKS} ={};			# hook namespace

    if (defined($ENV{TEMPLATE_ROOT})) {
	$this->{PATH} = [] unless (defined($this->{PATH}));
	push( @{ $this->{PATH} }, split(/:/, $ENV{TEMPLATE_ROOT}));
    }

    unless (defined($this->{PATH})) {
	croak("$class: No template search path defined");
    }

    $this->_open_trace_file if ($this->{TRACE});

    $this;
}

sub add_template_path {
    my ($this, $path) = @_;

    unshift( @{ $this->{PATH} }, $path);
    return $this;
}

sub clear {
    my ($this) = @_;

    $this->{VARS} = {};
    $this->{HOOKS} = {};
}

sub param {
    my ($this, $name, $value) = @_;

    if (defined($value)) {
	croak(__PACKAGE__,'::param called with bad name')
	    unless (defined($name) and $name);

	$this->_trace_out("SET " . substr(substr(Data::Dumper->Dump([$value], [$name]), 1), 0, -2))
	    if ($this->{TRACE});

	$this->{VARS}->{$name} = $value;
	return $value;
    } 

    return $this->{VARS}->{$name}
	if (defined($name));

    return keys %{ $this->{VARS} };
}

sub set {
    my ($this, $name, $value) = @_;

    $this->param($name, $value);
}

sub unset {
    my ($this, $name) = @_;

    delete $this->{VARS}->{$name};

    $this->_trace_out("UNSET $name")
	if ($this->{TRACE});
}

sub associate {
    my ($this, $r, $prefix) = @_;

    confess(__PACKAGE__, ": Cannot import non-objects") unless (ref($r));

    $prefix ||= '';
    if (ref($r) eq 'HASH') {
	my ($k, $v);
	while (($k, $v) = each(%$r)) {
	    $this->set("$prefix$k", $v, );
	}
    }
    elsif (defined($r->can('param'))) {
	my $p;
	foreach $p ($r->param()) {
	    $this->set("$prefix$p", $r->param("$p"));
	}
    } else {
	croak(__PACKAGE__, ": Don't know how to import object of type ", ref($r));
    }
}

sub set_hook {
    my ($this, $name, $value, $user_data) = @_;

    croak(__PACKAGE__,'::set_hook called with illegal name')
	unless (defined($name) and ($name =~ m!^\w+$!));

    croak(__PACKAGE__,'::set_hook called with illegal value')
	unless (defined($value) and ref($value) eq 'CODE');

    $this->{HOOKS}->{$name} = [ $value, $user_data ];
    return $this;
}

sub set_hook_data {
    my ($this, $name, $user_data) = @_;

    croak(__PACKAGE__,'::set_hook_data called with illegal name')
	unless (defined($name) and ($name =~ m!^\w+$!));

    my $hook_data = $this->{HOOKS}->{$name};
    warn(__PACKAGE__,'::set_hook_data called with unknown hook')
	unless (defined($hook_data));

    $this->{HOOKS}->{$name}->[1] = $user_data;
    return $this;
}

sub unset_hook {
    my ($this, $name) = @_;

    croak(__PACKAGE__,'::unset_hook called with illegal name')
	unless (defined($name) and ($name =~ m!^\w+$!));

    delete $this->{HOOKS}->{$name};
    return $this;
}


# TIEHASH interface - EXPERIMENTAL

sub TIEHASH {
    my ($class, @args) = @_;
    return $class->new(@args);
}

sub FETCH {
    my ($this, $key) = @_;
    return $this->{VARS}->{$key};
}

sub STORE {
    my ($this, $key, $value) = @_;
    $this->param($key, $value);
}

sub DELETE {
    my ($this, $key) = @_;
    $this->unset($key);
}

sub CLEAR {
    my ($this) = @_;
    $this->{VARS} = {};
}

sub EXISTS {
    my ($this, $key) = @_;
    return exists($this->{VARS}->{$key});
}

sub FIRSTKEY {
    my ($this) = @_;
    my $a = keys %{$this->{VARS}};
    each %{$this->{VARS}};
}

sub NEXTKEY {
    my ($this) = @_;
    each %{$this->{VARS}};
}



# internal - open a new scope
sub _open_scope {
    my ($this) = @_;

    unshift(@{ $this->{VARSTACK} }, $this->{VARS});
    $this->{VARS} = {};
}

# internal - open a new scope
sub _close_scope {
    my ($this) = @_;

    $this->{VARS} = shift(@{ $this->{VARSTACK} });
}

# internal - get simple variable value
sub _value {
    my ($this, $name) = @_;

    #print STDERR "_value -> $name\n";

    my $value;
    for (split('\s*\|+\s*', $name)) {
	#print STDERR "_value try $_\n";

	next unless (/^\w+$/);
	$value = $this->{VARS}->{$_};
	last if (defined $value);
    }

    return undef unless (defined($value));
    return (ref($value) ? scalar(@{ $value }) : $value);
}

# internal - get simple value with error check
sub _value_safe {
    my ($this, $name) = @_;

    my $value = _value($this, $name);
    return $value if (defined($value));

    $this->template_error("variable \"$name\" not recognised");
    return '';
}

# internal - get global variable value
sub _value_global {
    my ($this, $name) = @_;

    return undef unless ($name =~ /^\w+$/);

    my $value;
    foreach (@{ $this->{VARSTACK} }) {
	$value = $_->{$name};
	return $value if (defined $value);
    }
    return undef;
}


sub _call_hook {
    my ($this, $name) = @_;

    # call-backs format $(hook, var, arg, ...)
    if ($name =~ /^(\w+)((.)\s*(.*))?$/) {
	my $hook = $1;
	my $sep = $3;
	my $args = $4;

	my $hook_data = $this->{HOOKS}->{$hook};
	unless (defined($hook_data)) {
	    if (my $func = $this->UNIVERSAL::can("do_${hook}_hook")) {
		$hook_data = [ $func ];
	    } else {
		$this->template_error("hook \"$hook\" not defined");
		return undef;
	    }
	}

	my @args = ();
	if (defined($sep)) {
	    @args = split(/\Q$sep\E\s*/, $args, -1);
	}
	_trace_out($this, "Hook $hook(" . join(',', @args) . ") ...")
	    if ($this->{TRACE} > 2);

	unshift(@args, $hook_data->[1]) if (scalar(@$hook_data)>1);

	my $value = $hook_data->[0]->($this, @args);
	_trace_out($this, "Hook $hook --> "
			  . ($value ? substr(Dumper($value), 6) : "\"$value\""))
	    if ($this->{TRACE} > 2);
	return $value;
    }

    $this->template_error("variable \"$name\" not recognised");
    return undef;
}

sub _call_hook_safe {
    my ($this, $name) = @_;
    $name = _call_hook($this, $name);
    return defined($name) ? (ref($name) ? scalar(@$name) : $name) : '';
}

# internal - substitute variables and hooks in normal text
sub _substitute {
    my ($this, $text) = @_;
    $text =~ s/\$\(([\w\|]+)\)/_value_safe($this, $1)/ges;
    $text =~ s/\$\[([^\]]+)\]/_call_hook_safe($this, $1)/ges;
    return $text;
}

# internal - evaluate a loop expression
sub _loop_data {
    my ($this, $name) = @_;

    my $data;
    for (split('\s*\|+\s*', $name)) {
	if (/^\s*(\w+)|\$\((\w+)\)|\$\[(.+)\]\s*$/) {
	    $data = (defined($3)
		     ? $this->_call_hook($3)
		     : $this->{VARS}->{$1 || $2});
	    last if ($data);
	}
    }

    if (not $data and $this->{DEBUG}) {
	$this->template_error("DEBUG loop expression \"$name\" not recognised");
	return undef;
    }

    if ($data and !(ref($data) eq 'ARRAY')) {
	$this->template_error("loop expression $name is not an arrayref");
	# print STDERR Dumper($data);
	return undef;
    }

    return $data;
}


# internal - dump all variables
sub _dumpall {
    my ($this, @names) = @_;

    @names = sort keys %{$this->{VARS}} unless (@names);

    for (@names) {
	my $value = $this->{VARS}->{$_} if (exists $this->{VARS}->{$_});
	_output($this, Data::Dumper->Dump([$value], [$_]));
    }
}

# print template related message
sub template_error {
    my ($this, $msg) = @_;
    _trace_out($this, $msg);
    warn(__PACKAGE__, ": $msg\n") if ($this->{WARNINGS});
    push(@{ $this->{MESSAGES} }, [ $this->{FILE}, $this->{LINE}, $msg ]);

    printf(STDERR "TEMPLATE ERROR %s:%d: %s\n", $this->{FILE}, $this->{LINE}, $msg)
	if ($this->{DEBUG});
}

# internal - get and clear all messages
sub _get_messages {
    my ($this) = @_;
    my $tmp = $this->{MESSAGES};
    $this->{MESSAGES} = [];
    return $tmp;
}

# internal - dump all messages
sub _dump_messages {
    my ($this, $prefix) = @_;

    foreach (@{ $this->_get_messages }) {
	_output($this, sprintf("%s%s:%d: %s", ($prefix ? "$prefix: " : ''), @$_))
    }
}


# internal
sub _trace_line {
    my ($this, $cond, $line) = @_;

    $this->_trace_out(($cond ? '+ ' : '- ') . $line);
}

sub _output {
    $_[0]->{OUTPUT} .= $_[1] . "\n";
}

sub _expand_input {
    my ($this, $input) = @_;
    my $line;

    return unless ($input);

    my @cond = ( 1 );

    while (defined($line = shift(@$input))) {
	++$this->{LINE};

	_trace_line($this, $cond[0], $line) if ($this->{TRACE} > 3);

	if (! ($line =~ /^\#/)) {
	    _output($this, _substitute($this, $line)) if ($cond[0]);
	    next;
	}

	unless ($line =~ /^\#\s*(\w+)\s*(.*?)\s*$/) {
	    $this->template_error("unknown \# line $line")
		unless ($line =~ /^\#\#/ or $line =~ /^\#\s*$/);
	    next;
	}
	my $cmd = $1;
	my $args = $2;

	if ($cmd eq 'include') {
	    if ($cond[0]) {
		$args = _substitute($this, $args);

		my $lines;
		for (split(' ', $args)) {
		    $lines = _read_file($this, $_);
		    last if $lines;
		}
		next unless ($lines);

		unshift(@$input, sprintf('#line %d %s', $this->{LINE}+1, $this->{FILE}));
		unshift(@$input, @$lines);
	    }
	}
	elsif ($cmd eq 'expand') {
	    if ($cond[0]) {
		my $data = _value_safe($this, $args);
		if ($data) {
		    my $lines = _read_file($this, \$data);
		    next unless ($lines);

		    unshift(@$input, sprintf('#line %d %s', $this->{LINE}+1, $this->{FILE}));
		    unshift(@$input, @$lines);
		}
	    }
	}
	elsif ($cmd eq 'call') {
	    if ($cond[0]) {
		_call_hook($this, $args);
	    }
	}
	elsif ($cmd eq 'set') {
	    if ($args =~ /^(\w+)=(.*)$/) {
		if ($cond[0]) {
		    my $name = $1;
		    my $value = $2;

		    $value = _substitute($this, $value);
		    $this->set($name, $value);
		}
	    } else {
		$this->template_error("bad \#set line $line")
	    }
	}
	elsif ($cmd eq 'if') {
	    if ($cond[0]) {
		my $value = $args;

		$value = _substitute($this, $value);
		$value = ! ($value =~ m!^\s*0*\s*$!);

		unshift(@cond, ((defined($value) && $value))?1:0);
	    } else {
		unshift(@cond, 0);
	    }
	}
	elsif ($cmd eq 'ifdef') {
	    if ($cond[0]) {
		my $value = _value($this, $args);
		unshift(@cond, ((defined($value) and $value ne '')?1:0));
	    } else {
		unshift(@cond, 0);
	    }
	}
	elsif ($cmd eq 'ifndef') {
	    if ($cond[0]) {
		my $value = _value($this, $args);
		unshift(@cond, ((defined($value) and $value ne '')?0:1));
	    } else {
		unshift(@cond, 0);
	    }
	}
	elsif ($cmd eq 'else') {
	    if ($#cond == 0) {
		$this->template_error("Dangling \#else");
	    } elsif ($cond[1]) {
		$cond[0] = ($cond[0]?0:1);
	    } else {
		$cond[0] = 0;
	    }
	}
	elsif ($cmd eq 'endif' or $cmd eq 'fi') {
	    if ($#cond == 0) {
		$this->template_error("Dangling \#endif");
	    } else {
		shift(@cond);
	    }
	}
	elsif ($cmd eq 'loop') {
	    print STDERR __PACKAGE__, ": START LOOP $args\n"
		if ($this->{DEBUG} > 1);

	    my $loopvar = $args;
	    my $loopdata;
	    my $start_line;

	    if ($cond[0]) {
		$loopdata = _loop_data($this, $loopvar);
		$start_line = $this->{LINE};
	    }

	    my @body = ();
	    my $level = 0;
	    while (defined($line = shift(@$input))) {
		++$this->{LINE};

		print STDERR  __PACKAGE__, ": LOOP $line\n"
		    if ($this->{DEBUG} > 1);

		if ($line =~ /^\#\s*loop\s/) {
		    $level++;
		    push(@body, $line);
		} elsif ($line =~ /^\#\s*endloop\b/) {
		    last if ($level == 0);
		    push(@body, $line);
		    --$level;
		} else {
		    push(@body, $line);
		}
	    }
	    print(STDERR (__PACKAGE__, 
			  ": END LOOP $loopvar\nLOOP DATA\n\t",
			  join("\n\t", @body), "END DATA\n"))
		if ($this->{DEBUG} > 1);

	    if ($level > 0) {
		$this->template_error("template loop $loopvar not terminated");
		last;
	    }

	    if ($loopdata) {
		my $end_line = $this->{LINE};

		$this->_open_scope();

		my $hash;
		my $index = 0;
		my $rest = $#$loopdata;

		undef $this->{BREAK};
		foreach $hash (@$loopdata) {
		    $this->{LINE} = $start_line;

		    $this->{VARS} = $hash;
		    $this->{VARS}->{_index} = $index;
		    $this->{VARS}->{_rest} = $rest;

		    _expand_input($this, [@body]);
		    last if ($this->{BREAK});

		    $index++;
		    --$rest;
		}
		undef $this->{BREAK};

		$this->_close_scope;
		$this->{LINE} = $end_line;
	    }
	    $this->_trace_line($cond[0], $line) if ($this->{TRACE} > 3);

	}
	elsif ($cmd eq 'import') {
	    if ($cond[0]) {
		foreach ($args =~ /\w+/g) {
		    $this->{VARS}->{$_} = _value_global($this, $_);
		}
	    }
	}
	elsif ($cmd eq 'verb') {
	    if ($cond[0]) {
		_output($this, $args);
	    }
	}
	elsif ($cmd eq 'break') {
	    if ($cond[0]) {
		$this->{BREAK} = 1;
		return;
	    }
	}
	elsif ($cmd eq 'dumpall') {
	    if ($cond[0]) {
		$this->_dumpall(split /\s+/, $args);
	    }
	}
	elsif ($cmd eq 'warn') {
	    if ($cond[0]) {
		$this->template_error($args);
	    }
	}
	elsif ($cmd eq 'messages') {
	    _dump_messages($this, $args);
	}
	elsif ($cmd eq 'line') {
	    if ($args =~ /^(\d+)\s*(\s(.*))?$/) {
		$this->{LINE} = $1-1;
		$this->{FILE} = $3 if (defined $3);
	    }
	} elsif ($this->UNIVERSAL::can("do_${cmd}_command")) {
            $this->UNIVERSAL::can("do_${cmd}_command")->($this, $args, $cond[0]);
        } else {
            $this->template_error("bad \#line line $line");
        }
    }

    if ($#cond > 0) {
	$this->template_error("$#cond unfinished conditionals at the end");
    }

    return;
}


# Trace output

sub _open_trace_file {
    my ($this) = @_;

    if ($this->{TRACEFILE}) {
	local (*TRACE);
	if (open(TRACE, '>' . $this->{TRACEFILE})) {
	    	$this->{TRACE_HANDLE} = *TRACE{IO};
	} else {
	    carp(__PACKAGE__, ": cannot open tracefile: $!\n");
	    $this->{TRACE} = 0;
	}
    } else {
	$this->{TRACE_HANDLE} = *STDERR{IO};
    }
}

sub _close_trace_file {
    my ($this) = @_;

    if ($this->{TRACEFILE}) {
	close($this->{TRACE_HANDLE})
	    or carp(__PACKAGE__, ": cannot close tracefile: $!\n");
    }
}

sub _trace_out {
    my ($this, $msg) = @_;

    return unless $this->{TRACE};

    my $fh = $this->{TRACE_HANDLE};
    if (defined $this->{FILE}) {
	printf $fh
	    "%s: %d: %s\n", $this->{FILE}, $this->{LINE}, $msg;
    } else {
	printf $fh
	    "%s: %s\n", __PACKAGE__, $msg;
    }
}



# Template cache

sub _read_cached_file {
    my ($this, $file) = @_;

#    $file = Cwd::cwd . '/' . $file
#	unless ($file =~ m!^/!);

    _trace_out($this, "TRYING $file") if ($this->{TRACE} > 1);

    my $mtime = (stat($file))[9];
    if (!defined($mtime)) {
	delete $Cache{$file};
	_trace_out($this, "NO FILE $file")
	    if ($this->{TRACE} > 1);

	return undef;			# file inaccessible
    }

    if ($this->{CACHE}) {
	my $cdata = $Cache{$file};
	if (defined($cdata) and ($$cdata[0] == $mtime)) {
	    _trace_out($this, "CACHE HIT $file")
		if ($this->{TRACE} > 1);

	    return [ @{ $$cdata[1] } ];	# copy out of cache
	}

	_trace_out($this, "CACHE RELOAD $file")
	    if ($this->{TRACE});
    }

    local (*FORM);

    if (open(FORM, $file)) {
	_trace_out($this, "READING $file")
	    if ($this->{TRACE} > 1);
	my @lines = <FORM>;
	close(FORM);

	map { tr/\n\r//d } @lines;

	unshift(@lines, '#line 1 ' . $file);
	$Cache{$file} = [ $mtime, \@lines ]
	    if ($this->{CACHE});

	return [ @lines ];		# copy out of cache
    }

    return undef;
}


# internal
sub _read_file {
    my ($this, $file) = @_;

    my $type = ref($file);

    unless ($type) {			# scalar - ie filename
	if ($file =~ /^\//) {
	    return _read_cached_file($this, $file);
	} else {
	    my $path = $this->{PATH} || [ '.' ];
	    my $dir;

	    # Speed-optimisation - scan cache first for path.  This will
	    # cause problems if a file is moved from one path element to
	    # another.
	    if ($this->{CACHE} and $this->{ALWAYS_SEARCH_PATH}==0) {
		for $dir (@$path) {
		    my $nfile = "$dir/$file";
		    if (defined $Cache{$nfile}) {
			my $lines = _read_cached_file($this, $nfile);
			return $lines if (defined $lines);
		    }
		}
	    }

	    for $dir (@$path) {
		my $lines = _read_cached_file($this, "$dir/$file");
		return $lines if (defined $lines);
	    }
	}

	# File not found
	$this->template_error("The template file '$file' cannot be opened: $!");
	return undef;
    }

    # These tests are taken from Compress::Zlib 1.08 by Paul Marquess.

    # Reference to a string
    if (UNIVERSAL::isa($file, 'SCALAR')) {
	my @lines = split("\r?\n", $$file);

	unshift(@lines, '#line 1 ANONYMOUS STRING');
	return \@lines;
    }

    # Reference to a file handle
    if (((UNIVERSAL::isa($file,'GLOB') or UNIVERSAL::isa(\$file,'GLOB')) 
	 and defined fileno($file))) {
	my @lines = <$file>;
	map { tr/\n\r//d } @lines;

	unshift(@lines, '#line 1 ANONYMOUS FILE');
	return \@lines;
    }
}

sub expand {
    my ($this, $file, $provider) = @_;

    $this->{FILE} = 'ANONYMOUS INPUT';
    $this->{LINE} = 0;
    $this->{MESSAGES} = [];
    $this->{PROVIDER} = $provider || $this->{PROVIDER};

    _trace_out($this, "EXPANDING $file") if ($this->{TRACE});

    my $lines = _read_file($this, $file);
    croak(__PACKAGE__, "->expand: '$file' not readable: $!")
	unless ($lines);

    $this->{OUTPUT} = '';
    _expand_input($this, $lines);

    unless ($this->{OUTPUT}) {
	_trace_out($this, "NO OUTPUT FOR $file");
    }

    if ($this->{TRACE}) {
	_trace_out($this, "FINISHED $file");
    }

    my $r = \$this->{OUTPUT};
    delete $this->{OUTPUT};

    return $$r;
}

# static function
sub preload {
    my ($class, @dirs) = @_;

    my $tmpl = $class->new(path=>'/tmp', cache=>1, trace=>0);

    foreach my $dir (@dirs) {
	$dir =~ s!/+$!!;

	local (*DIR);
	opendir(DIR, $dir) or next;
	foreach my $file (grep { (-f "$dir/$_") and (not (exists $Cache{"$dir/$_"}
				      or (/^\.|\.bak$|\~$|\#|CVS/)))
			     } readdir(DIR)) {
	    _read_cached_file($tmpl, "$dir/$file");
	}
	closedir(DIR);
    }
}



########################################################################
#
#	Interface to Provider object
#
########################################################################

sub do_needs_command {
    my ($this, $args, $active) = @_;

    return '' unless ($active);

    print STDERR ">>>> #needs $args\n" if ($this->{DEBUG});

    my $provider = $this->{PROVIDER};
    if ($provider) {
	my ($func, @args) = split(' ', $args);
	return '' unless ($func);

	my $ignore_error = 0;
	if ($func eq '?') {
	    $ignore_error++;
	    $func = shift(@args);
	} elsif ($func =~ /\?$/) {
	    $func = substr($func, 0, -1);
	    $ignore_error++;
	}

	my $method;
	if ($method = $provider->UNIVERSAL::can("provide_$func")) {
	    unless ($method->($provider, $this, @args) or $ignore_error) {
		$this->template_error("Provider failed for #needs $func @args");
	    }
	} else {
	    $this->template_error("No way to fulfil #needs $func");
	}
    } else {
	$this->template_error("No data available for #needs commands");
    }
    return '';
}


########################################################################
#
#	Generel hooks for tests and comparisons
#
########################################################################

#	no=	undef	0       T
#yes=
#undef		1/0	''/0    ''/T
#    0		1/0	0/0     0/T
#    T		T/''	T/0     T/T

sub default_yes_no {
    my ($yes, $no) = @_;

    if (defined $no) {
	$yes = '' unless (defined $yes);
    } else {
	if ($yes) {
	    $no = '';
	} else {
	    $yes = 1;
	    $no = 0;
	}
    }
    return ($yes, $no);
}

sub do_ifdef_hook { 
    my ($this, $n, $yes, $no) = @_;
    ($yes, $no) = default_yes_no($yes, $no);
    return (defined($this->_value($n)) ? $yes : $no);
}

sub do_ifndef_hook { 
    my ($this, $n, $yes, $no) = @_;
    ($yes, $no) = default_yes_no($yes, $no);
    return (not defined($this->_value($n)) ? $yes : $no);
}

sub do_if_hook { 
    my ($this, $n, $yes, $no) = @_;
    $n = $this->_value($n) || '';
    $yes = $n unless (defined($yes));
    $no = '' unless (defined($no));
    return ($n ? $yes : $no);
}

sub do_default_hook { 
    my ($this, $n, $def) = @_;
    $n = $this->_value($n);
    $def = '' unless (defined($def));
    return ((defined($n) and $n) ? $n : $def);
}

sub do_equal_hook { 
    my ($this, $n, $test, $yes, $no) = @_;
    ($yes, $no) = default_yes_no($yes, $no);
    return ((($this->_value_safe($n)) eq $test) ? $yes : $no);
}

sub do_equal_nocase_hook { 
    my ($this, $n, $test, $yes, $no) = @_;
    ($yes, $no) = default_yes_no($yes, $no);
    return ((lc($this->_value_safe($n)) eq lc($test)) ? $yes : $no);
}

sub do_vequal_hook { 
    my ($this, $n, $n2, $yes, $no) = @_;
    ($yes, $no) = default_yes_no($yes, $no);
    return (($this->_value_safe($n) eq $this->_value_safe($n2)) ? $yes : $no);
}

sub do_match_hook { 
    my ($this, $name, $regex, $yes, $no) = @_;

    my $text = $this->_value_safe($name);
    return '' unless ($text);

    ($yes, $no) = default_yes_no($yes, $no);
    return (($text =~ /$regex/) ? $yes : $no);
}

sub do_gt_hook { 
    my ($this, $n, $value, $yes, $no) = @_;
    ($yes, $no) = default_yes_no($yes, $no);
    return (($this->_value_safe($n) > $value) ? $yes : $no);
}

sub do_ge_hook { 
    my ($this, $n, $value, $yes, $no) = @_;
    ($yes, $no) = default_yes_no($yes, $no);
    return (($this->_value_safe($n) >= $value) ? $yes : $no);
}

sub do_lt_hook { 
    my ($this, $n, $value, $yes, $no) = @_;
    ($yes, $no) = default_yes_no($yes, $no);
    return (($this->_value_safe($n) < $value) ? $yes : $no);
}

sub do_le_hook { 
    my ($this, $n, $value, $yes, $no) = @_;
    ($yes, $no) = default_yes_no($yes, $no);
    return (($this->_value_safe($n) <= $value) ? $yes : $no);
}

sub do_is_even_hook { 
    my ($this, $n, $yes, $no) = @_;
    ($yes, $no) = default_yes_no($yes, $no);
    my $v = $this->_value_safe($n);
    return ($v%2 == 0) ? $yes : $no;
}

sub do_is_multiplum_of_hook { 
    my ($this, $n, $div, $yes, $no) = @_;
    ($yes, $no) = default_yes_no($yes, $no);
    my $v = $this->_value_safe($n);
    return (($v % $div) == 0) ? $yes : $no;
}

# hooks for changing variables

sub do_toggle_hook { 
    my ($this, $n, $yes, $no) = @_;
    ($yes, $no) = default_yes_no($yes, $no);
    my $v = $this->_value_safe($n);
    $v = ((!defined($v) or $v eq $no) ? $yes : $no);
    $this->param($n, $v);
    return $v;
}

# hooks for calculating values

sub do_lc_hook { 
    my ($this, $n) = @_;
    return lc($this->_value_safe($n));
}

sub do_uc_hook { 
    my ($this, $n) = @_;
    return uc($this->_value_safe($n));
}

sub do_length_hook { 
    my ($this, $n) = @_;
    return length($this->_value_safe($n));
}


1;

__END__

=pod

=head1 NAME

WebObvius::Template - Template expansion

=head1 SYNOPSIS

In the program:

  use WebObvius::Template;

  $template = new WebObvius::Template(options ...);

  $template->set($name, $value);
  $template->unset($name);
  $template->clear;

  @params = $template->param;
  $value = $template->param($name);
  $template->param($name, $value);

  $template->associate(\%hash, $prefix);
  $template->associate($object, $prefix);

  $template->set_hook($hook, $coderef, $user_data);
  $template->set_hook_data($hook, $user_data);
  $template->unset_hook($hook);

  $result = $template->expand($filename);
  $result = $template->expand(\$string);
  $result = $template->expand(\*fh);

In sub-classes or hook functions also

  $template->template_error($message);
  $template->_value($variable);
  $template->_value_safe($variable);

Interpolation of text into the templates:

  $(name)
  $[hook, arg ...]

Control-structures for the templates

  #include file ...

  #if expression
  #ifdef name
  #ifndef name
  #else
  #endif or #fi

  #set name=value

  #call hook, args....
  #expand name

  #loop loop-variable
  #endloop

  #break
  #warn message
  #verb verbatim-text
  #dumpall
  #messages
  #line line-number [file-name]
  ## comment

=head1 DESCRIPTION

WebObvius::Template is is yet another system for generating template based
output.  This module is very easy to use and has a very flexible
template format, which resembles the format of the C pre-processor a
bit.

When choosing a template module, the background and the qualifications
of the template writers must be taken into account.  This module
requires more of the template writer than other modules, but it is also
more flexible and more powerful.

For the programmer WebObvius::Template is very easy to use: create a
WebObvius::Template object, set some variables and then expand one or more
template files.

The template writer can use the variables set by the programmer to
generate the output.  It is possible to have conditional text, loops and
verbatim text, to include other template files and to set new variables
in the template object.

WebObvius::Template is extensible. The programmer can defined hooks or
call-backs that the template writer can use. A hook invokes a perl
function whose return value is the expansion.

WebObvius::Template can be used to generate any kind of text.

If you can think of a better name, please let me know.



=head1 THE PROGRAMMERS VIEW

From the programmers point of view, using B<WebObvius::Template> is easy:
create a WebObvius::Template object, set some variables using the methods
set(), unset(), param() and associate(), then expand one or more files
with the method expand().  The only slightly complex part is
constructing data for loops in the template files.


=head2 Template Object Creation

C<WebObvius::Template> objects are created with C<new>:

  $template = new WebObvius::Template(options ...);

The options are:

=over 4

=item B<path>

This is the path used to locate template files.  It can be either a
string for a single element or a reference to an array of several
values, e.g.,

  path=>$dir

or

  path=>[ $dir1, $dir2, ... ]

If the environment variable TEMPLATE_ROOT is set, its value is appended
to the search path.

Directories are searched in order.

If no valid search path is specified, neither as an option, nor through
TEMPLATE_ROOT, C<WebObvius::Template> will croak.

=item B<cache>

If set to a true value, C<WebObvius::Template> will cache the template
text for faster access the next time it is needed.  If set to a false
falue, no caching is performed.

Before using the text in the cache, the modification time of the file is
compared with the modification time of the cached text.  The file is
then reloaded if necessary.

This is probably only useful in an Apache/mod_perl context.  There are
separate caches for each Apache child process.

Default is false.

=item B<debug>

If set to a true value, C<WebObvius::Template> generates debug output on
standard error, about the internal state of the template object. It is
probably only useful when debugging WebObvius::Template itself.

Default is false.

=item B<trace>

If set to a true value, C<WebObvius::Template> generates trace output on
standard error.  The amount of output is determined by the value given
to the trace options.

If set to 1 (one) it will output a line each time a variable is set or
unset, and whenever a cached file is reloaded.

With a value of 2, it will also tell about each file read and details about
cache hits.

When set to 3, hooks are traced, with indications of the arguments
passed to the hook functions and the value returned from it.

With a value of 4 or more, detailed tracing of conditionals and loops is
included in the output. There will be a line for template line
processed, with and indication of whether it was output or
suppressed by conditionals.

If possible, each line will tell the filename and line number of the
template line in question.

Default is false (zero).

=item B<tracefile>

If tracing is used, the output can be directed to a file with the
C<tracefile=E<gt>filename> argument to new(). The file is overwritten.
To append to the file, use C<E<gt>filename> as the filename part.

Default is trace output to standard error.

=item B<warning>

If set to a true value, C<WebObvius::Template> prints warnings of errors
in template files, such as references to undefined template variables,
unterminated loops, unfinished conditional constructs and from the
C<#warn> template command.  Output is to stardard error.

Default is false, meaning template input errors are I<not> printed
anywhere.

Error and warning messages are still collected for use by C<#messages>.

=back


=head2 Setting Variables

C<WebObvius::Template> has an array of functions for controlling the variables
set in a template.  Variables can be set or unset individually or in
groups.

Valid variable names consist of letters, digits and underscore. Invalid
names are not rejected. They cannot be referenced by the template files,
but they can be used by hook functions.

=over 4

=item C<param>

Return a list of names defined in the template.

=item C<param($name)>

Return the current value of the template variable $name.

=item C<set($name, $value)>

=item C<param($name, $value)>

Set template variable $name to expand to $value.

=item C<unset($name)>

Remove any previous value for $name.

=item C<clear>

Remove all variables and hooks from the template.

=item C<associate(\%hash, $prefix)>

Import (name,value) pairs from the referenced hash into the template,
names optionally prefixed by $prefix.

=item C<associate($object, $prefix)>

Import (name,value) pairs from the object into the template, names
optionally prefixed by $prefix.  The names imported are found by
calling the method param() without arguments, and the values are
obtained by calling param(name) on the object.  This means that a CGI
object can be associated easily.

=back



=head2 Loop Variables

Loop variables need special care.  For a variable to be usable as a loop
variable, its value must be a reference to an array.  Each element in
this array should be a reference to a hash, which defines the variables
for each iteration of the loop.

Loops can be nested.  In that case the data-structures become more
complex.

A loop introduces new scope, so variables defined outside the loop
cannot be used inside.  This might change in the future, where an import
mechanism might be introduced, to allow global template variables to be
accessed from within a loop.

All this is quite analogous to the way HTML::Template handles loops.

Please look at the test-suite in the source distribution for examples of
how to construct the data structures necessary for using loops.

=head2 Adding Customised Hooks

WebObvius::Template is extensible.  Hook functions can be defined, and
later activated from the templates. 

Valid hook names consist of letters, digits and underscore. Invalid hook
names are rejected.

=over 4

=item C<set_hook($name, $coderef, $user_data)>

Define the hook $name to call the perl sub referenced by $coderef.  The
$user_data is attached to the hook and passed to it on each invokation.

Returns the template object.

=item C<set_hook_data($name, $user_data)>

Change the $user_data attached to the hook $name.

Returns the template object.

=item C<unset_hook($name)>

Clear a previously defined hook $name.

Returns the template object.

=back

A hook function is a perl sub with a prototype of

    hook($template, $user_data, ...)

When a reference to a hook is seen in the template file, the function is
called with the template object, the user data and any extra arguments
given in the template.

The sub should return a string value, which will be the expansion of the
call from the template file.

Here is a small example that implements a simple equal-not equal test:

    $template->set_hook(equal => sub { 
			    my ($t, $udata, $n1, $n2, $yes, $no) = @_;
			    return ($n1 eq $n2) ? ($yes || 1) : ($no || 0);
			}, $udata);

It can be used in a template like this:

    #if $[equal, $(date), 9999-01-01]
    Date is not specified
    #else
    Date is $(date)
    #endif

If WebObvius::Template is used for HTML generation with mod_perl, these
two hook defintions will be useful:

    $template->set_hook(urlencode => sub { 
			    my ($t, $r, $n) = @_;
			    return Apache::Util::escape_uri($t->param($n));
			}, $r);

    $template->set_hook(htmlencode => sub { 
			    my ($t, $r, $n) = @_;
			    return Apache::Util::escape_html($t->param($n));
			}, $r);

Put shortly, hooks allow the template writer to do anything the
programmer fancies.

There are a couple of semi-internal methods of use to the programmer of
template hook functions.  In case of errors in the template file, the
error can be signalled using template_error($msg), which will call
warn() if C<warnings> are enabled.  The values of template variables can
be requested with _value($name) and _value_safe($name). The first
returns the value that would be inserted for C<$(name)> or undef if the
name is not defined. The second return the same value, but signals an
error and returns an empty string if the name is not defined.

=head2 Expanding Templates

Once all the information is computed and the variables set on the
template object, template files can be expanded.

=over 4

=item C<expand($filename)>

Returns the content of $filename expanded by the template object.

The expand() does not output anything, it only returns the expanded
string.  It is up to the caller to actually print the expanded file.

=back

Calling expand() does not change the state of the template object,
unless it is changed by the templates expanded.

The same template object can be used several times, for example first to
generate a HTML page and then to generate an email with the same data.
Just call expand() several times with different files.


=head2 Tied interface (experimental)

A tied interface has been added to WebObvius::Template.  It is not
seriously tested and should be considered experimental.

Usage:

  tie %template, WebObvius::Template, option=>value, ...;

  $template{name} = 'value';
  @names = keys %template;

  tied(%template)->expand($file);

  untie %template;

WebObvius::Template should implement the full TIEHASH interface. Please
see the test files in the source distribution for better examples.

=head2 Errors

WebObvius::Template will croak() in the following cases: when an invalid
template path is passed to new(); on attempts to assign values to
undefined variable names; on attempts to defined hooks with illegal
names; on attempts to associate() something that is not a reference to a
hash or a blessed object with a param() method; and when the filename
passed to expand() cannot be opened.

Specifically WebObvius::Template will not die when there are errors in
template files, such as unterminated loops, unfinished conditionals or
included files that cannot be read.  It will issue warnings, if the
c<warning> options was given to new().


=head1 THE TEMPLATE WRITERS VIEW

The template writer can use the variables set by the programmer to
generate the output.  It is possible to have conditional text, loops and
verbatim text, to include other template files and to set new variables
in the template object.

Template variables come in two variants: I<simple variables> are normal
text strings, while I<loop variables> contain complex structures with
the necessary information to control a template loop. Loops are used for
repetitious information, such as search results or lists of information.

WebObvius::Template is designed as to avoid having any kind of knowledge
of the form of the final output coded into the program. The template
writer is only restricted by the information made available to her by
the programmer.

The template files are treated on a line-by-line basis, so all template
commands and references to template variables must be on a single line
of input.  Lines with template commands all begin with a hash-mark (#)
in the first column. All other lines are copied to the output, with
template variables interpolated first.

=head2 Interpolating Variables

A line of input from a template is subjected to variable interpolation
if it does not form a template command.

Interpolating the values of variables into the expanded output can be
done in two ways.

=over 4

=item C<$(name)>

This will be replaced with the value of the variable I<name> when the
template is expanded.  If I<name> is a loop variable, the value is the
number of iterations of a loop controlled by I<name>.

The value is void if I<name> is not defined by the program.

=item C<$[hook, ...]>

This will be replaced with the return value of the I<hook>, called with
any remaining arguments.  The hook can behave like a simple variable or
like a loop variable and the value inserted accordingly.

The first character after the hook name is used as separator between the
following arguments.  White-space after the separator is removed. The
following three examples all perform exactly the same call:

    $[url_encode| uri|         strong]
    $[url_encode, uri,strong]
    $[url_encode:uri:strong]

The value is void if the hook is not defined by the program.

A hook can be called for its side-effects using the syntax

    #call hook, args....

=back

Both of the above forms must be on one input line to be recognised.

On each line of a template file, the C<$(name)> constructs are evaluated
first, followed by C<$[hook ...]> references, so input like:

    $[equal, $(date), 9999-01-01]

will behave as expected.


=head2 Setting Variables

Variables in the template object can be changed by the templates.  This
alters the state of the template object and the changes are visible in
the program afterwards.

=over 4

=item C< #set name=value>

Assign C<value> to C<name>, which will always be a simple variable.  The
right hand side is subject to variable and hook interpolation first, so

  #set file=$(dir)/$(base).$(ext)

is perfectly legal.

=back


=head2 File Inclusion

=over 4

=item C< #include file ...>

Includes the contents of C<file> in the output. If more files are
specified, each is tried in turn, until one succeeds or the list is
exhausted.

Files are not included when they are in a conditional branch that is not
taken.  This is likely to cause problems if conditionals are not
balanced within an input file.

=back

The filename given is subject to variable interpolation, so (assuming an
appropriate definition of the hook I<random>):

    #include template$[random 5].html

could be used to include a random file of five files named
F<template0.html> to F<template4.html>.

=head2 Conditionals

Conditionals are come in several variants.

=over 4

=item C< #ifdef name>

Expand the following lines if C<name> is defined in the template and it
has a non-void value.

=item C< #ifndef name>

Expand the following lines if C<name> is not defined in the template or
it is void.

=item C< #if expression>

Expand the following lines if the C<expression> is true.

The expression is subject to normal variable expansion, and the test
succeeds if the result is void or 0.  Leading and trailing whitespace is
ignored.  With the use of hooks, complex tests can be made.

=item C< #else>

Expand the following lines if the previous unfinished C<#if*> test was
false.

Text following #else is ignored.

=item C< #endif> or C<#fi>

End an C<#if*> construct. The two forms can be used interchangably.

Text following #endif/#fi is ignored.

=back



=head2 Loops

Loops are an important part of WebObvius::Template.  They allow the
programmer to construct tabular data and let the template writer take
care of the presentation, be it as HTML tables, as a SELECT menu, in a
mail message or otherwise.

=over 4

=item C< #loop loop-varible>

Starts a loop with controlling variable C<loop-varible>.  The argument
C<loop-varible> can either be the name of a loop variable, it can be a
normal reference of the form C<$(loop_variable)> to such a variable, or
it ca be a reference to a template hook returning a loop value, e.g.,
C<$[hook, args...]>.

=item C< #endloop>

Ends a loop.

Text following #endloop is ignored.

=back

The C<loop-variable> defines a set of template variables for each
iteration.  Within the loop, I<only> the variables for that iteration
are accessible.  There is currently no way of accessing global template
variables from within a loop.

Within a C<#loop> .. C<#endloop> construct, there are two standard
variables set for each iteration: C<_index> and C<_rest>.  The former is
the number of the iteration, counting from zero, and the latter is the
number of remaining iterations, which is zero for the last iteration.

Loop variables can be used in C<#ifdef>.  In that case the test is
true, if there are one or more iterations of the loop.  Likewise for and
C<#ifndef>.

If a loop variable is interpolated with one of the C<$(name)> forms, the
result is the number of iterations of the loop. The same is true for a
hook returning a loop value.


=head2 Miscellaneous

=over 4

=item C< #break>

Terminates template expansion.  If used within a loop, C<#break>
terminates the loop, and if used outside any loop, C<#break> terminates
further processing.  In any case, the expansion text generated so far is
returned to the program.  No error is signalled.

=item C< #warn message>

Calls the perl warn() function with C<message>.

=item C< #verb text>

Outputs C<text> verbatim without any form of processing.

=item C< #dumpall>

Expands to a description of all the variables set in the template
object.  It can be included in the output for debugging purposes.

Variables are printed by the Data::Dumper module.

=item C< #messages>

Expands to a list of error and warning messages from the template
processing.  It can be included in the output for debugging purposes.

The list of messages is cleared each time C<#messages> is used, so it
can be used repeatedly.

=item C< ##comment text>

The line is immediately discarded. Nothing will appear in the output.

=item C< #line line-number [filename]>

This command sets the internally maintained line number and filename to
the arguments.  This information is only used for error messages and
debugging output.

A number of these lines are added automatically by WebObvius::Template to
maintain the correct line numbers when files are included. These lines
will show up when tracing the output.

=back


=head1 DEBUGGING

Debugging aids are the new() options C<debug> and C<trace>, which gives
some output on standard error on optionally in a file and the
C<#dumpall> and C<#messages> template command.

Errors from template files are only printed if the C<warnings> option
was given to new(). The reason is that a malformed template file should
not fill up the web server error logs.


=head1 TIPS AND TRICKS

=head2
Two-way communication between template designer and programmer

Using the C<#set> command, the template designer can set values, that
can be inspected by the program after a template file has been
expanded. Assume the file F<template.conf> contains the line:

    #set max_entries=10

After this file has been expanded through a template object $tmpl, the
value can be retrived with

    $max_entries = $tmpl->param('max_entries');

The value can then be used by the program. The result of the expansion
can simply be discarded.

The configuration data can even be included in the actual template file
(not using a separate file), with a construct like at the start of the
template file:

    #ifndef first_time
    #  set max_entries=10
    #  set first_time=no
    #  break
    #endif

The program will first expand the template file, after which it can
retrive the configuration parameters from the template object. The
program then goes on to do its job and expand the same template file
again to produce the real output.



=head1 BUGS

Infinite include recursion is not detected.

Template files should be pre-parsed when read, instead of just being
stored as lists of lines.

Hooks should be possible as methods in subclasses. That way specialised
template types could be made easily.

=head1 AUTHOR

René Seindal (rene@magenta-aps.dk).


=head1 COPYRIGHT

Copyright © 2000 Magenta Aps, Denmark (http://www.magenta-aps.dk/)

This module is published under the GNU GPL, version 2 or later.  See the
file F<COPYING> in the distribution for terms and conditions.

=head1 SEE ALSO

perl(1), HTML::Template(3).

=cut
