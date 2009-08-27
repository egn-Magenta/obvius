package Obvius::Tags;

use strict;
use warnings;

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

1;
