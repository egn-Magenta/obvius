package Obvius::DocType::CreateDocument;

# $Id$

use strict;
use warnings;

use Obvius;
use Obvius::DocType;

use POSIX qw(strftime);

our @ISA = qw( Obvius::DocType );
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub action {
    my ($this, $input, $output, $doc, $vdoc, $obvius, %options) = @_;

    my $op = $input->param('op');
    return OBVIUS_OK unless($op and $op eq 'createdocument');

    #Tell the template system that we are actually doing a create
    $output->param(create => 1);

    $obvius->get_version_fields($vdoc, [  'doctype',
                                        'language',
                                        'where',
                                        'name_prefix',
                                        'publish_mode',
                                        'email',
                                        'subscribe_include' ]);

    my $doctype;
    if(%options and $options{doctype}) {
        $doctype = $options{doctype};
    } else {
        $doctype = $vdoc->DocType;
        $doctype = $obvius->get_doctype_by_name($doctype);
    }

    die("No doctype in CreateDocument\n") unless($doctype);

    my @fields;
    for(keys %{$doctype->{FIELDS}}) {
        push(@fields, $_);
    }

    my $docfields = new Obvius::Data;
    $docfields->param('DOCTYPE' => $doctype->{ID});
    for(@fields) {
        my $default_value = $doctype->{FIELDS}->{$_}->{DEFAULT_VALUE};
	my $value=$input->param(lc($_));

        $value = $default_value unless(defined($value) or !$default_value);

	if (defined $value) { # copy_in:
	    my $fieldspec=$obvius->get_fieldspec($_, $doctype);
	    my $fieldtype=$fieldspec->param('fieldtype');
	    $value = $fieldtype->copy_in($obvius, $fieldspec, $value);
	}

        $docfields->param($_ => $value)  if(defined($value));
    }

    unless($docfields->param('TITLE')){
        $output->param(create_error => 'Cannot create a document without a title');
        return OBVIUS_OK;
    }

    $docfields->param(docdate => strftime('%Y-%m-%d 00:00:00', localtime));

    #override with fields from %options
    if($options{fields} and ref($options{fields}) eq 'HASH') {
        for(keys %{$options{fields}}) {
            $docfields->param($_ => $options{fields}->{$_});
        }
    }

    my $language = $options{language} || $vdoc->field('language');
    my $doctypeid = $doctype->{ID};
    my $owner = $doc->{OWNER};
    my $group = $doc->{GRP};

    my $parent;
    if(%options and $options{parent_doc}) {
        $parent = $options{parent_doc};
    } else {
        $parent = $vdoc->Where;
        $parent = $obvius->lookup_document($parent);
    }

    my $name_prefix = $vdoc->field('name_prefix') || '';
    my $name = $name_prefix . strftime('%Y%m%d%H%M%S', localtime);

    $output->param(Obvius_SIDE_EFFECTS => 1);
    my $create_error;
    my $backup_user = $obvius->{USER};
    $obvius->{USER} = 'admin'; # XXX I walk through mindfields..
    my ($new_docid, $new_version) = $obvius->create_new_document($parent, $name, $doctypeid, $language, $docfields, $owner, $group, \$create_error);
    $obvius->{USER} = $backup_user;

    if($create_error) {
        $output->param(create_error => $create_error);
        return OBVIUS_OK;
    }

    my $publish_mode = $vdoc->Publish_Mode || $options{publish_mode};
    my $document_published;
    my $new_doc = $obvius->get_doc_by_id($new_docid);
    my $new_vdoc = $obvius->get_version($new_doc, $new_version);
    $output->param(new_doc=>$new_doc);
    $output->param(new_vdoc=>$new_vdoc);

    if($publish_mode and $publish_mode eq 'immediate') {
        my $publish_error;

        # Start out with som defaults
        $obvius->get_version_fields($new_vdoc, 255, 'PUBLISH_FIELDS');

        # Set published
        my $publish_fields = $new_vdoc->publish_fields;
        $publish_fields->param(PUBLISHED => strftime('%Y-%m-%d %H:%M:%S', localtime));

        #If we want the document to be sent by the subscription system...
        if($vdoc->field('subscribe_include')) {
            $publish_fields->param(in_subscription => 1);
        }

        my $backup_user = $obvius->{USER};
        $obvius->{USER} = 'admin'; # XXX Don't try this at home
        $obvius->publish_version($new_vdoc, \$publish_error);
        $obvius->{USER} = $backup_user;

        if($publish_error) {
            $output->param(publish_error => $publish_error);
        } else {
            $output->param(document_published => 1);
        }
    }

    $obvius->get_version_field($new_vdoc, "title");
    $output->param(new_title => $new_vdoc->Title);
    $output->param(new_url => $obvius->get_doc_uri($new_doc));

    my $email = $vdoc->field('email');
    if($email) {
        $output->param(send_email => 1);
        $output->param(recipient => $email);
    }

    # Redirect?
    my $redirect_to = $input->param('redirect_to');
    $output->param('Obvius_REDIRECT' => $redirect_to) if($redirect_to);

    return OBVIUS_OK;
}

1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Obvius::DocType::CreateDocument - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Obvius::DocType::CreateDocument;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Obvius::DocType::CreateDocument, created by h2xs. It looks like the
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
