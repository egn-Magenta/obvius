package Obvius::Shell;		# Please use -*- cperl -*-, thanks.

########################################################################
#
# Standard Modulsnask
#
########################################################################

use 5.006;
use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter Term::Shell);
our @EXPORT = qw(shell);
our $VERSION = '0.01';

use base qw(Term::Shell);

use Obvius;
use Obvius::Config;
use Obvius::Data;

use Getopt::Std;
use Getopt::Long;

use Data::Dumper;


########################################################################
#
# Public functions
#
########################################################################

sub shell {
  my ($site, $conf, $obvius, $doc);

  $site = shift;
  croak ("No site defined")
    unless (defined($site));
  
  $conf = new Obvius::Config($site);
  croak ("Could not get config for $site")
    unless(defined($conf));
    
  $obvius = new Obvius($conf);
  croak ("Could not get Obvius object for $site")
    unless(defined($obvius));

  $obvius->{USER} = 'admin';

  $doc = $obvius->get_root_document;

  my $shell = new Obvius::Shell;
  $shell->{term}->{completion_append_character} = '/';

  $shell->{SHELL}->{site} = $site;
  $shell->{SHELL}->{conf} = $conf;
  $shell->{SHELL}->{obvius} = $obvius;
  $shell->{SHELL}->{doc} = $doc;
  $shell->{SHELL}->{vdoc} = $obvius->get_public_version($doc) || $obvius->get_latest_version($doc);
  $shell->{SHELL}->{VERSIONS} = $obvius->get_versions($doc);
  $shell->{SHELL}->{OLDPWD} = undef;
  $shell->{SHELL}->{DOCLIST} = [];

  $shell->cmdloop;

}


########################################################################
#
# General Term::Shell functions
#
########################################################################

sub prompt_str { 
  my ($shell) = @_;
  my ($obvius, $doc, $vdoc) = extract_shell $shell;

  $shell->{SHELL}->{site}.":".$obvius->get_doc_uri($doc)."> " 
}


########################################################################
#
# Functions implementing commands
#
########################################################################

# Please order functions smry_*, run_*, comp_*, and help_*
# and always write a smry_* function.


sub smry_ls { "List subdocuments"}

sub run_ls {
  my ($shell, @args) = @_;
  my ($obvius, $doc, $vdoc) = extract_shell $shell;

  my $subdocs = $obvius->get_document_subdocs($doc);

  foreach (@$subdocs) {
    my $doc = $obvius->get_doc_by_id($_->DocId);
    print $doc->Name, "\n";
  }

}


sub smry_lsver { "List versions" }

sub run_lsver {
  my ($shell) = @_;
  my ($obvius, $doc, $vdoc) = extract_shell $shell;

  my $i;
  map { print "[", $i++, "]\t", $_->Version, "\n"; } @{$shell->{SHELL}->{VERSIONS}};
}


sub smry_chver { "Change version" }

sub run_chver {
  my ($shell, $ver) = @_;
  my ($obvius, $doc, $vdoc) = extract_shell $shell;
    
  my $new_ver;
    
  if ($ver =~ /^%(\d+)/) {
    $new_ver =  $shell->{SHELL}->{VERSIONS}->[$1];
  } elsif ($ver =~ /^%%/) {
    $new_ver = $obvius->get_public_version($doc) || $obvius->get_latest_version($doc);
  } else {
    $new_ver = $obvius->get_version($doc, $ver);
  }
    
  if (defined($new_ver)) {
    $shell->{SHELL}->{vdoc} = $new_ver;
  } else {
    warn "No such version: $ver\n";
  }
    
}


sub smry_cd { "Change Document" }

sub run_cd {
  my ($shell, $cd) = @_;
  my ($obvius, $doc, $vdoc) = extract_shell $shell;

  my $new_doc = file2doc($shell, $cd);
  if (defined $new_doc) {
    $shell->{SHELL}->{OLDPWD} = $doc;
    $shell->{SHELL}->{doc} = $new_doc;
    $shell->{SHELL}->{vdoc} = $obvius->get_public_version($new_doc) || $obvius->get_latest_version($new_doc);
    $shell->{SHELL}->{VERSIONS} = $obvius->get_versions($new_doc);
  } else {
    warn "No such document: $cd\n";
  }
}

sub comp_cd {
  my ($shell, $word, $line, $start) = @_;

  my @res = file_completion($shell, $word);

  return @res;
}


sub smry_pwd { "Print working document" }

sub run_pwd {
  my $shell = shift;
  my ($obvius, $doc, $vdoc) = extract_shell $shell;

  local @ARGV = @_;
    
  my %opt;
    
  getopts('aiuv', \%opt);
    
  $opt{i} = $opt{u} = $opt{v} = 1 if ($opt{a});

  $opt{u} = 1 unless ($opt{i} || $opt{u} || $opt{v});
    
  if ($opt{i}) {
    print "DocId:\t\t", $doc->Id, "\n"
  } 
  if ($opt{u}) {
    print "Uri:\t\t", $obvius->get_doc_uri($doc), "\n";
  }
  if ($opt{v}) {
    print "Version:\t",  $vdoc->Version, "\n";
  }
    
}


sub smry_show { "Show information about document" }

sub run_show {
  my $shell = shift;
  my ($obvius, $doc, $vdoc) = extract_shell $shell;

  local @ARGV = @_;
        
  my %options = ();
  GetOptions(\%options, qw(all publish));

  my $fields;
  if ($options{all}) {
    $fields = 255;
  } elsif ($ARGV[0] =~ /^\d+$/) {
    $fields = $ARGV[0];
  } else {
    $fields = \@ARGV;
  }

  my $type;
  $type = 'PUBLISH_FIELDS' if ($options{publish});

  my $needed = fields_by_threshold($obvius, $vdoc, $fields, $type);
  $fields = $obvius->get_version_fields($vdoc, $needed, $type);

  my $res = new Obvius::Data;
  foreach (@$needed) {
    $res->param($_ => $fields->param($_));
  }
    
  print Dumper $res;
    
}


sub smry_search { "Search database" }

sub run_search {
  my $shell = shift;
  my ($obvius, $doc, $vdoc) = extract_shell $shell;

  local @ARGV = @_;
    
  my %options = ();
  GetOptions(\%options, qw(nothidden notexpired public max=i sortvdoc=s));
    
  if (defined $options{sortvdoc}) {
    $options{sortvdoc} = file2doc($shell, $options{sortvdoc});
  }

  my $where = shift @ARGV;
    
  my $vdocs = $obvius->search(\@ARGV, $where, %options);
    
  my @docs = map { $obvius->get_doc_by_id($_->DocId) } @$vdocs;

  $shell->{SHELL}->{DOCLIST} = \@docs;

  my $i = 0;
  map {print "[", $i++, "]\t", $obvius->get_doc_uri($_), "\n"} @docs;
}


########################################################################
#
# Helper functions
#
########################################################################

sub extract_shell {
  my ($shell) = @_;
  @{$shell->{SHELL}}{'obvius','doc','vdoc'}
}

sub file2doc {
  my ($shell, $id) = @_;
  my ($obvius, $doc, $vdoc) = extract_shell $shell;

  if ($id =~ m|^/|) {
    $doc =  $obvius->get_root_document;
  }

  my @id = split '/', $id;
  my $d;
    
  while (defined($doc) && defined($d = shift @id)) {
    if ($d eq '') {
      # no-op
    } elsif ($d eq '.') {
      # no-op
    } elsif ($d eq '..') {
      $doc = $obvius->get_doc_by_id($doc->Parent)
	unless ($doc == $obvius->get_root_document);
    } elsif ($d eq '-') {
      $doc = $shell->{SHELL}->{OLDPWD};
    } elsif ($d =~ /^(\d+)\.docid/) {
      $doc = $obvius->get_doc_by_id($1);
    } elsif ($d =~ /^%(\d+)/) {
      $doc = $shell->{SHELL}->{DOCLIST}->[$1];
    } else {
      $doc = $obvius->get_doc_by_name_parent($d, $doc->Id);
    }
	
  }

  return $doc;
}

sub file_completion {
  my ($shell, $word) = @_;
  my ($obvius, $doc, $vdoc) = extract_shell $shell;

  my @path = split '/', $word;
  $word = pop @path;
  my $path = @path ? join('/', @path) . '/' : '';
  my $base_doc = file2doc($shell, $path);

  return () unless defined($base_doc);

  my @res = map { $path. $_ }
    grep { m|^$word| } 
      map { $obvius->get_doc_by_id($_->DocId)->Name }
	@{$obvius->get_document_subdocs($base_doc)};
    
  return @res;
}

sub fields_by_threshold {
  my ($obvius, $version, $threshold, $type) = @_;
  $type=(defined $type ? $type : 'FIELDS');
    
  my $doctype = $obvius->get_version_type($version);
  my @fields;
    
  if (ref $threshold) {
    @fields = grep { defined $doctype->field($_, undef, $type) } @$threshold
      ;
  } else {
    $threshold = 0 unless (defined $threshold and $threshold >= 0);
    $threshold = 255 if ($threshold > 255);
	
    @fields = grep {
      $doctype->field($_, undef, $type)->Threshold <= $threshold
    } @{$doctype->fields_names($type)};
  }
  return @fields ? \@fields : undef;
}

1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Obvius::Shell - Shell-like interface to a Obvius-site

=head1 SYNOPSIS

  $ perl -MObvius::Shell -e 'shell sitename'

=head1 DESCRIPTION

Stub documentation for Obvius::Shell, created by h2xs. It looks like the
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
