package Obvius::Tags;

use strict;
use warnings;

use Data::Dumper;
use LWP::UserAgent;
use XML::Simple;
use JSON;

our @langs = qw(danish english);

sub new {
     my ($class, $obvius) = @_;
     
     bless { obvius => $obvius }, $class;
}

sub ob { shift->{obvius} }

sub validate_tag {
     my ($this, $tag) = @_;
     
     return $tag !~ /^\s*$/ && $tag =~ /^[-\s\w\d._!æøåÅÆØ]+$/;
}

sub get_tags {
     my ($this, $short_lang) = @_;
     my $tags = 
       $this->ob->execute_select("select name from tags where lang=?", $short_lang);
     [ map { $_->{name} } @$tags ];
}

sub add_tag {
     my ($this, $name, $short_lang) = @_;
     $this->ob->execute_command("insert into tags (name, lang) values (?, ?)",
                                $name, $short_lang);
       
}

sub strip {
     my $a = shift;
     $a =~ s/^\s+//;
     $a =~ s/\s+$//;
     $a;
}

sub update_tags {
     my ($this, $tags, $short_lang) = @_;
     my @sql_vals = map { [ strip($_), $short_lang ] } @$tags;
     eval {
          $this->ob->db_begin;
          $this->ob->execute_command("delete from tags where lang = ?", $short_lang);
          $this->ob->execute_command("insert into tags (name, lang) value (?, ?)", 
                                     \@sql_vals);
          $this->ob->db_commit;
     };
     if ($@) {
          $this->ob->db_rollback;
          die $@;
     }
};

for my $lang (@langs) {
     my $short_lang = substr($lang, 0, 2);
     no strict "refs";
     *{ __PACKAGE__ . '::' . $lang . '_tags' } = sub {
          get_tags(@_, $short_lang);
     };
     *{ __PACKAGE__ . '::add_' . $lang . '_tag' } = sub {
          add_tag(@_, $short_lang);
     };
     *{ __PACKAGE__ . '::update_' . $lang . '_tags' } = sub {
          update_tags(@_, $short_lang);
     };
     use strict "refs";
}

sub find_tags_on_path {
     my ($this, $docs, %options) = @_;
     
     $docs = [$docs] if ref $docs ne 'ARRAY';
     my @paths = grep { $_ } map { $this->ob->get_doc_uri($_) } @$docs;

     my (@vars, @where, @pathexp);
     
     
     for my $path (@paths) {
          push @pathexp, "dp.path like ?";
          push @vars, "${path}%";
     }
     
     die "Document $doc's path couldn't be found" if (!@pathexp);

     push @where, '(' . (join " or ", @pathexp) . ')';
     
     if (my $doctypes = $options{doctypes}) {
          $doctypes = [$doctypes] if ref $doctypes ne 'ARRAY';
          my @doctypes;
          
          for my $doctype (@$doctypes) {
               if ($doctype =~ /^\d+$/) {
                    push @doctypes, $doctype;
               } else {
                    $doctype = $this->ob->get_doctype_by_name($doctype);
                    next if !$doctype;
                    push @doctypes, $doctype->Id;
               }
          }

          if (@doctypes) {
               my $params = join ",", (("?") x @doctypes);
               push @where, "v.type in ($params)";
               push @vars, @doctypes;
          }
     }

     if ($options{tag_filter}) {
          for my $key ('include', 'exclude') {
               my $data = $options{tag_filter}->{$key};
               next if !$data;
               if (!@$data) {
                    push @where, "0" if $key eq 'include';
                    next;
               }
               my $param = join ",", (("?") x @$data);
               push @where, "vf.text_value " . ($key eq 'exclude' ? ' not ' : '') . " in ($param)";
               push @vars, @$data;
          }

     }
     
     push @where, "v.public = 1";
     push @where, "vf.name = 'tags'";
     
     push @where, "vf.text_value is not null";

     my $where = @where ? " where " . (join ' and ', @where) : "";

     my $query = "select vf.text_value tag, count(*) tagcount from 
                     vfields vf join versions v on (v.docid = vf.docid and vf.version = v.version)
                     join docid_path dp on (v.docid = dp.docid) $where\n
                     group by vf.text_value order by lower(vf.text_value)";
     
     my $tags = $this->ob->execute_select($query, @vars);
     @$tags = grep { $_->{tag} && $_->{tag} !~ /^\s*$/ } @$tags;

     return $tags,
}
1;
