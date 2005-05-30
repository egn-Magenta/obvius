package Obvius::DocType::ProduktOversigt;

# $Id$

use strict;
use warnings;

use Obvius;
use Obvius::DocType;

our @ISA = qw( Obvius::DocType );
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

our %godkendt_hash = (
                        'Ikke godkendt' => 'none',
                        'Under behandling' => 'underbehandling',
                        'Godkendt' => 'godkendt'
                    );

sub action {
    my ($this, $input, $output, $doc, $vdoc, $obvius) = @_;

    if($input->param('IS_ADMIN')) {
        return $this->admin_action($input, $output, $doc, $vdoc, $obvius);
    }

    my $mode = $input->param('mode');

    return $this->adv_search($input, $output, $doc, $vdoc, $obvius) if($mode and $mode eq 'advsearch');

    my $o = $input->param('organisme');
    if($o and $o =~ /^\d+$/) {
        my $organisme = $this->get_organismer($obvius, {'id' => $o});
        if($organisme->[0]) {
            $output->param('show_organisme' => 1);
            $output->param('organisme' => $organisme->[0]);
            $output->param('egenskaber' => $this->get_org_egenskaber($obvius, {organisme => $organisme->[0]->{id}}));
            $output->param('all_egenskaber' => $this->get_egenskaber($obvius));
            $output->param('godkendelser' => $this->get_godkendelser($obvius, {organisme => $organisme->[0]->{id}}));
            return OBVIUS_OK;
        }
    }

    my $gkprod_doctype = $obvius->get_doctype_by_name('GodkendtProdukt');


    # Get stuff for sort menu

    my $godkendelser = $this->get_sortstuff($obvius);

    my %sort = (
                    'foder' => {},
                    'teknisk_anvendelse' => {},
                    'dyrkning' => {},
                    'dyrkning_opt' => {},
                    'foedevare' => {},
                    'foedevare_opt' => {},
                    'laegemiddel' => {},
                    'laegemiddel_opt' => {}
                );
    for(@$godkendelser) {
        my $produkt = $_->{produktnavn};
        if($_->{gk_foder} and $_->{gk_foder} eq 'Godkendt') {
            $sort{'foder'}->{$produkt} = 1;
        }
        if($_->{gk_teknisk} and $_->{gk_teknisk} eq 'Godkendt') {
            $sort{'teknisk_anvendelse'}->{$produkt} = 1;
        }
        if($_->{gk_dyrkning} and $_->{gk_dyrkning} eq 'Godkendt') {
            $sort{'dyrkning'}->{$produkt} = 1;
        }
        if($_->{gk_dyrkning_opt} and $_->{gk_dyrkning_opt} eq 'Godkendt') {
            $sort{'dyrkning_opt'}->{$produkt} = 1;
        }
        if($_->{gk_foedevarer} and $_->{gk_foedevarer} eq 'Godkendt') {
            $sort{'foedevare'}->{$produkt} = 1;
        }
        if($_->{gk_foedevarer_opt} and $_->{gk_foedevarer_opt} eq 'Godkendt') {
            $sort{'foedevare_opt'}->{$produkt} = 1;
        }
        if($_->{gk_laegemiddel} and $_->{gk_laegemiddel} eq 'Godkendt') {
            $sort{'laegemiddel'}->{$produkt} = 1;
        }
        if($_->{gk_laegemiddel_opt} and $_->{gk_laegemiddel_opt} eq 'Godkendt') {
            $sort{'laegemiddel_opt'}->{$produkt} = 1;
        }
    }

    $output->param('sort' => \%sort);

    # Stuff for preserving form state
    my $selected = $input->param('godkendt') || 'dummy';
    $output->param('selected' => $selected);

    my @produkter = keys %{ $sort{$selected} || {} };
    $output->param('produkter' => \@produkter);

    my $active = $input->param('produkt') || [];
    $active = [ $active ] unless(ref($active) eq 'ARRAY');
    $output->param('active' => $active);

    my $where;

    my @searchedon;

    $where = "";

    if(my $godkendt = $input->param('godkendt')) {
        my %gk_hash = (
                        "foder" => 'gk_foder',
                        "teknisk_anvendelse" => 'gk_teknisk',
                        "dyrkning" => 'gk_dyrkning',
                        "dyrkning_opt" => 'gk_dyrkning_opt',
                        "foedevare" => 'gk_foedevarer',
                        "foedevare_opt" => 'gk_foedevarer_opt',
                        "laegemiddel" => 'gk_laegemiddel',
                        "laegemiddel_opt" => 'gk_laegemiddel_opt'
                    );
        my %gk_names = (
                        "teknisk_anvendelse" => 'Teknisk brug',
                        "dyrkning" => 'Dyrkning (miljøgodkendelse)',
                        "dyrkning_opt" => 'Godkendte sorter',
                        "dyrkning_opt" => 'Dyrkning - ikke sortsgodkendt',
                        "foedevare" => 'Fødevarer',
                        "foedevare_opt" => 'Fødevarer (forarbejdet)',
                        "laegemiddel" => 'Lægemiddel',
                        "laegemiddel_opt" => 'Lægemiddel - kun miljøgodkendt' # Not used any more.
                    );
        # Make sure we have an array
        $godkendt = [ $godkendt ] unless(ref($godkendt));
        my $gk_where;
        my @gk_searchedon;
        for my $g (@$godkendt) {
            if(my $field = $gk_hash{$g}){
                $gk_where .= " OR " if($gk_where);
                $gk_where .= "$field = 'Godkendt'";
                push(@gk_searchedon, "'" . $gk_names{$g} . "'");
            }
        }

        if($gk_where) {
            $where .= " AND " if($where);
            $where .= "($gk_where)" ;
            my $gk_searchedon = 'Godkendelse: ' . join(', ', @gk_searchedon);
            $gk_searchedon =~ s/,([^,]+)$/ eller$1/;
            push(@searchedon, $gk_searchedon);
        }
    }

    if(my $produkt = $input->param('produkt')) {
        my $searchedon .= 'Produkt: ';
        $produkt = [ $produkt ] unless(ref($produkt));
        $where .= " AND " if($where);
        $where .= "produktnavn IN ('" . join("', '", @$produkt) . "')";
        $searchedon .= "'" . join("', '", @$produkt) . "'";
        $searchedon =~ s/, ([^,]+)$/ eller $1/;

        push(@searchedon, $searchedon);
    }

    $output->param('searchedon' => \@searchedon);

    my $docs = $this->fullsearch($obvius, $where, fields => 'distinct id, betegnelse, unik_kode, produktnavn', order => 'gk_organismer.produktnavn, gk_organismer.betegnelse');

    if($docs) {
        my @result;
        for my $d (@$docs) {
            my $data;

            $data->{betegnelse} = $d->{betegnelse};
            $data->{unik_kode} = $d->{unik_kode};
            $data->{produkt} = $d->{produktnavn};
            $data->{id} = $d->{id};

            $data->{egenskaber} = $this->get_org_egenskaber($obvius, {organisme => $d->{id}}, get_navn => 1);

            my $godkendelser = $this->get_godkendelser($obvius, {organisme => $d->{id}});
            for my $g (@$godkendelser) {
                $data->{foder} = $godkendt_hash{$g->{gk_foder}} unless($data->{foder} and $data->{foder} ne 'none');
                $data->{teknisk_anvendelse} = $godkendt_hash{$g->{gk_teknisk}} unless($data->{teknisk_anvendelse} and $data->{teknisk_anvendelse} ne 'none');
                $data->{dyrkning} = $godkendt_hash{$g->{gk_dyrkning}} unless($data->{dyrkning} and $data->{dyrkning} ne 'none');
                $data->{dyrkning_opt} = $godkendt_hash{$g->{gk_dyrkning_opt}} unless($data->{dyrkning_opt} and $data->{dyrkning_opt} ne 'none');
                $data->{foedevare} = $godkendt_hash{$g->{gk_foedevarer}} unless($data->{foedevare} and $data->{foedevare} ne 'none');
                $data->{foedevare_opt} = $godkendt_hash{$g->{gk_foedevarer_opt}} unless($data->{foedevare_opt} and $data->{foedevare_opt} ne 'none');
                $data->{laegemiddel} = $godkendt_hash{$g->{gk_laegemiddel}} unless($data->{laegemiddel} and $data->{laegemiddel} ne 'none');
                $data->{laegemiddel_opt} = $godkendt_hash{$g->{gk_laegemiddel_opt}} unless($data->{laegemiddel_opt} and $data->{laegemiddel_opt} ne 'none');
            }

            push(@result, $data);
        }
        $output->param(results => \@result) if(scalar(@result));
    }

    return OBVIUS_OK;
}

########################################################
#               Stuff needed for sorting               #
########################################################

sub get_sortstuff {
    my ($this, $obvius) = @_;

    my $set=DBIx::Recordset->SetupObject( {
                                            '!DataSource'   => $obvius->{DB},
                                            '!Table'        => 'gk_organismer, gk_godkendelser',
                                            '!TabRelation'  => 'gk_organismer.id = gk_godkendelser.organisme',
                                            '!Fields'       => "produktnavn,
                                                                gk_foder,
                                                                gk_teknisk,
                                                                gk_dyrkning,
                                                                gk_dyrkning_opt,
                                                                gk_foedevarer,
                                                                gk_foedevarer_opt,
                                                                gk_laegemiddel,
                                                                gk_laegemiddel_opt"
                                        } );
    $set->Search('');
    my @data;
    while(my $rec = $set->Next) {
        push(@data, $rec);
    }
    $set->Disconnect;

    return \@data;
}

########################################################
#                     Full search                      #
########################################################

sub fullsearch {
    my ($this, $obvius, $where, %options) = @_;

    my $tables = 'gk_organismer, gk_godkendelser';
    my $tabrelation = 'gk_organismer.id = gk_godkendelser.organisme';

    if($options{add_tables} and $options{add_tabrelation}) {
        $tables .= $options{add_tables};
        $tabrelation .= $options{add_tabrelation};
    }

    my $set=DBIx::Recordset->SetupObject( {
                                            '!DataSource'   => $obvius->{DB},
                                            '!Table'        => $tables,
                                            '!TabRelation'  => $tabrelation,
                                            '!Fields'       => $options{fields} || '',
                                            '!Order'        => $options{order}
                                        } );
    $set->Search($where);
    my @data;
    while(my $rec = $set->Next) {
        push(@data, $rec);
    }
    $set->Disconnect;

    return \@data;

}

sub multiple_search_where {
    my ($fieldname, $value, $title)=@_;

    $value = [ $value ] unless(ref($value));

    my $searchedon .= $title . ': ';
    my $where = "$fieldname IN ('" . join("', '", @$value) . "')";
    $searchedon .= "'" . join("', '", @$value) . "'";
    $searchedon =~ s/, ([^,]+)$/ eller $1/;

    return ($where, $searchedon);
}

sub adv_search {
    my ($this, $input, $output, $doc, $vdoc, $obvius) = @_;

    $output->param(advsearh => 1);

    my $gkprod_doctype = $obvius->get_doctype_by_name('GodkendtProdukt');

    # Find stuff for dropdown menus

    my $stuff = $this->fullsearch($obvius);

    my %stuff = (
                    betegnelse => {},
                    unik_kode => {},
                    produkt => {},
                    godkendelsesnr => {},
                    godkendelsesdato => {},
                    ansoeger => {},
                    land => {}
                );

    for my $s (@$stuff) {
        $stuff{betegnelse}->{ $s->{betegnelse} } = 1;
        $stuff{unik_kode}->{ $s->{unik_kode} } = 1;
        $stuff{produkt}->{ $s->{produktnavn} } = 1;
        $stuff{godkendelsesnr}->{ $s->{ansoegningsnr} } = 1;
        $stuff{ansoeger}->{ $s->{ansoeger} } = 1;
        $stuff{land}->{ $s->{ansoegerland} } = 1;

        my $gkdato = $s->{godkendelsesdato};
        $gkdato =~ s/^(\d\d\d\d).*$/$1/;
        $gkdato = '' if($gkdato eq '0000');
        $stuff{godkendelsesdato}->{$gkdato} = 1 if($gkdato);
    }

    $output->param('stuff' => \%stuff);

    my $egenskaber = $this->get_egenskaber($obvius) || [];
    $output->param('egenskaber' => $egenskaber);

    my %egenskaber;
    for (@$egenskaber) {
        $egenskaber{$_->{id}} = $_->{navn};
    }

    my $where = "";
    my %options;
    my @searchedon;

    if(my $produkt = $input->param('produkt')) {
        my ($w, $s)=multiple_search_where('produktnavn', $produkt, 'Produkt');
        $where.=$w;
        push @searchedon, $s;
    }

    if(my $betegnelse = $input->param('betegnelse')) {
        $where .= " AND betegnelse = '$betegnelse'";
        push(@searchedon, "Betegnelse: $betegnelse");
    }

    if(my $unik_kode = $input->param('unik_kode')) {
        $where .= " AND unik_kode = '$unik_kode'";
        push(@searchedon, "Unik kode: $unik_kode");
    }

    if(my $gk_nr = $input->param('gk_nr')) {
        my ($w, $s)=multiple_search_where('ansoegningsnr', $gk_nr, 'Godkendelsesnr');
        $where.=" AND $w";
        push @searchedon, $s;
    }

    if(my $ansoeger = $input->param('ansoeger')) {
        my ($w, $s)=multiple_search_where('ansoeger', $ansoeger, 'Ansøger');
        $where.=" AND $w";
        push @searchedon, $s;
    }

    if(my $land = $input->param('land')) {
        my ($w, $s)=multiple_search_where('ansoegerland', $land, 'Ansøgerland');
        $where.=" AND $w";
        push @searchedon, $s;
    }

    if(my $indsigelse = $input->param('indsigelse')) {
        if($indsigelse eq 'ja') {
            $where .= " AND dk_indsigelse = 1";
            push(@searchedon, "Dansk indsigelse: Ja");
        } elsif($indsigelse eq 'nej') {
            $where .= " AND dk_indsigelse = 0";
            push(@searchedon, "Dansk indsigelse: Nej");
        } elsif($indsigelse eq 'undlod') {
            $where .= " AND dk_indsigelse = 2";
            push(@searchedon, "Dansk indsigelse: Undlod at stemme");
        }
    }

    if(my $aar = $input->param('aar')) {
        $aar = [ $aar ] unless(ref($aar));
        my $aar_where = '';
        for my $aar1 (sort @$aar) {
            my $aar2 = $aar1 + 1;
            $aar_where .= ' OR ' if($aar_where);
            $aar_where .= "( godkendelsesdato  >= '$aar1-01-01' AND godkendelsesdato < '$aar2-01-01' )";
        }
        $where .= ' AND ' . $aar_where;
        my $searchedon = "Godkendelsesår: " . join(', ', @$aar);
        $searchedon =~ s/, ([^,]+)$/ eller $1/;
        push(@searchedon, $searchedon);
    }


    my @egenskaber_in = map { /^egenskab_(\d+)/i; $1 } grep { /^egenskab_\d+/i } $input->param();

    if(scalar(@egenskaber_in)) {
        $options{add_tables} = ', gk_organisme_egenskaber as egenskaber';
        $options{add_tabrelation} = ' AND gk_organismer.id = egenskaber.organisme';
        $where .= ' AND ' if($where);
        $where .= 'egenskaber.egenskab IN (' . join(', ', @egenskaber_in) . ')';

        my @egenskaber_navne = map { $egenskaber{$_} } @egenskaber_in;
        my $s_on = "Egenskaber: " . join(', ', @egenskaber_navne);
        $s_on =~ s/, ([^,]*)$/ eller $1/;
        push(@searchedon, $s_on);
    }


    my @list = (
                    'foder',
                    'teknisk',
                    'dyrkning',
                    'dyrkning_opt',
                    'foedevarer',
                    'foedevarer_opt',
                    'laegemiddel',
                    'laegemiddel_opt',
                );
    # XXX Why is this duplicated?
    my %gk_names = (
                    "teknisk" => 'Teknisk brug',
                    "dyrkning" => 'Dyrkning (miljøgodkendelse)',
                    "dyrkning_opt" => 'Godkendte sorter',
                    "dyrkning_opt" => 'Dyrkning - ikke sortsgodkendt',
                    "foedevarer" => 'Fødevarer',
                    "foedevarer_opt" => 'Fødevarer (forarbejdet)',
                    "laegemiddel" => 'Lægemiddel',
                    "laegemiddel_opt" => 'Lægemiddel - kun miljøgodkendt' # Not used any more
                );

    my $gk_where = '';
    for(@list) {
        if($input->param($_ . '_godkendt')) {
            $gk_where .= " OR gk_$_ = 'Godkendt'";
            push(@searchedon, $gk_names{$_} . ': Godkendt');
        }
        if($input->param($_ . '_underbehandling')) {
            $gk_where .= " OR gk_$_ = 'Under behandling'";
            push(@searchedon, $gk_names{$_} . ': Under behandling');
        }
    }
    $gk_where =~ s/^\s*OR\s*//;
    if($gk_where) {
        $where .= ' AND ' if($where);
        $where .= "($gk_where)";
    }

    # Only get each organisme once
    $options{fields} = 'distinct id, betegnelse, unik_kode, produktnavn, gk_godkendelser.*';
    $options{order} = 'produktnavn, betegnelse, id';

    $where =~ s/^\s*AND\s*//i;

    $output->param('searchedon' => \@searchedon);

    my $docs = $this->fullsearch($obvius, $where, %options);

    my $last_id = -1;
    if($docs) {
        my @result;
        my $data;
        for my $d (@$docs) {
            if($last_id != $d->{id}) {
                push(@result, $data) if($data);
                $data = {};
                $data->{godkendelser} = [];
                $data->{betegnelse} = $d->{betegnelse};
                $data->{unik_kode} = $d->{unik_kode};
                $data->{produkt} = $d->{produktnavn};
                $data->{id} = $d->{id};
                $last_id = $d->{id};
            }

            my @under_behandling = sort map { $gk_names{$_} } grep { $d->{"gk_$_"} and $d->{"gk_$_"} eq 'Under behandling' } @list;
            my @godkendelser     = sort map { $gk_names{$_} } grep { $d->{"gk_$_"} and $d->{"gk_$_"} eq 'Godkendt' } @list;
            push(@{ $data->{godkendelser} }, {
                                                under_behandling => \@under_behandling,
                                                godkendt => \@godkendelser,
                                                ansoegningsnr => $d->{ansoegningsnr}
                                            });
        }
        push(@result, $data) if($data->{id});
        $output->param(results => \@result) if(scalar(@result));
        $output->param(nr_godk => scalar(@$docs));
    }

    return OBVIUS_OK;
}


sub admin_action {
    my ($this, $input, $output, $doc, $vdoc, $obvius) = @_;

    $output->param('admin' => 1);


    ####################################
    #             Organisme            #
    ####################################

    if($input->param('organisme_new')) {
        $output->param('mode' => 'organisme_new');
        if($input->param('go')) {

            $output->param('go' => 1);

            my $data = {};

            if(my $betegnelse = $input->param('betegnelse')) {
                my $betegnelse_test = $betegnelse;
                 $betegnelse_test =~ s/'/\\'/gi;
                if(scalar(@{ $this->get_organismer($obvius, "betegnelse = '$betegnelse_test'") })) {
                    $output->param('error' => 'Der findes allerede en organisme med den betegnelse');
                    return OBVIUS_OK;
                } else {
                    $data->{betegnelse} = $betegnelse;
                }
            } else {
                $output->param('error' => 'Du skal angive en betegnelse');
                return OBVIUS_OK;
            }

            if(my $unik_kode = $input->param('unik_kode')) {
                $data->{unik_kode} = $unik_kode;
            }

            if(my $produktnavn = $input->param('produktnavn')) {
                $data->{produktnavn} = $produktnavn;
            } else {
                $output->param('error' => 'Du skal angive et produktnavn');
                return OBVIUS_OK;
            }

            $data->{kommentar} = $input->param('kommentar') || '';

            my @egenskaber_in = map { /^egenskab_(\d+)/i; $1 } grep { /^egenskab_\d+/i } $input->param();

            my @egenskaber;
            for(@egenskaber_in) {
                push(@egenskaber, $_) if(scalar(@{ $this->get_egenskaber($obvius, "id = '$_'") }));
            }

            # OK, so far no errors, let's insert
            if(my $id = $this->insert_organisme($obvius, $data)) {
                $this->insert_org_egenskaber($obvius, $id, \@egenskaber) if(scalar(@egenskaber));
            } else {
                $output->param('error' => 'Der opstod en databasefejl ved oprettelse af organismen');
                return OBVIUS_OK;
            }

        } else {
            $output->param('egenskaber' => $this->get_egenskaber($obvius));
            return OBVIUS_OK;
        }
    } elsif(my $organisme = $input->param('organisme')) {
        if($organisme =~ /^\d+$/) {
            $output->param('mode' => 'organisme_edit');
        } else {
            return OBVIUS_OK;
        }

        if($input->param('go')) {
            $output->param('go' => 1);

            my $data = {};

            if(my $betegnelse = $input->param('betegnelse')) {
                my $betegnelse_test = $betegnelse;
                 $betegnelse_test =~ s/'/\\'/gi;
                if(scalar(@{ $this->get_organismer($obvius, "betegnelse = '$betegnelse_test' AND id != '$organisme'") })) {
                    $output->param('error' => 'Der findes allerede en organisme med den betegnelse');
                    return OBVIUS_OK;
                } else {
                    $data->{betegnelse} = $betegnelse;
                }
            } else {
                $output->param('error' => 'Du skal angive en betegnelse');
                return OBVIUS_OK;
            }

            if(my $unik_kode = $input->param('unik_kode')) {
                $data->{unik_kode} = $unik_kode;
            }

            if(my $produktnavn = $input->param('produktnavn')) {
                $data->{produktnavn} = $produktnavn;
            } else {
                $output->param('error' => 'Du skal angive et produktnavn');
                return OBVIUS_OK;
            }

            $data->{kommentar} = $input->param('kommentar') || '';

            my @egenskaber_in = map { /^egenskab_(\d+)/i; $1 } grep { /^egenskab_\d+/i } $input->param();

            my @egenskaber;
            for(@egenskaber_in) {
                push(@egenskaber, $_) if(scalar(@{ $this->get_egenskaber($obvius, "id = '$_'") }));
            }

            # OK, so far no errors, let's insert
            if($this->update_organisme($obvius, $organisme, $data)) {
                    $this->delete_org_egenskaber($obvius, {'organisme' => $organisme});
                    $this->insert_org_egenskaber($obvius, $organisme, \@egenskaber) if(scalar(@egenskaber));
            } else {
                $output->param('error' => 'Der opstod en databasefejl ved redigering af organismen');
                return OBVIUS_OK;
            }
        } else {
            my $orgs = $this->get_organismer($obvius, {'id' => $organisme});
            if($orgs->[0]) {
                $output->param('organisme' => $orgs->[0]);

                $output->param('egenskaber' => $this->get_egenskaber($obvius));

                my @egenskaber_chosen = map { $_->{egenskab} } @{ $this->get_org_egenskaber($obvius, { 'organisme' => $orgs->[0]->{id} }) };
                $output->param('egenskaber_chosen' => \@egenskaber_chosen);

                $output->param('godkendelser' => $this->get_godkendelser($obvius, {organisme => $orgs->[0]->{id}}));

            } else {
                # Alert the user
                $output->param('go' => 1);
                $output->param('error' => "Kunne ikke finde organisme med id '$organisme'");
            }
        }
    } elsif($input->param('organisme_delete')) {

        my $o = $input->param('o');
        return OBVIUS_OK unless($o and $o =~ /^\d+/);

        $output->param('mode' => 'organisme_delete');

        if($input->param('confirm')) {
            $this->delete_organisme($obvius, $o);
            $output->param('deleted' => 1);
        } else {
            my $orgs = $this->get_organismer($obvius, {'id' => $o});
            if($orgs->[0]) {
                $output->param('organisme' => $orgs->[0]);
            } else {
                $output->param('mode' => '');
            }
        }
    }

    ####################################
    #            Egenskaber            #
    ####################################

    elsif($input->param('egenskaber')) {
        $output->param('mode' => 'egenskaber');
        $output->param('egenskaber' => $this->get_egenskaber($obvius));
    } elsif($input->param('egenskab_new')) {

        $output->param('mode' => 'egenskab_new');

        my $data = {};

        if(my $navn = $input->param('navn')) {
            $data->{navn} = $navn;
        } else {
            $output->param('error' => 'Du skal angive et navn på egenskaben');
            return OBVIUS_OK;
        }

        unless($this->insert_egenskab($obvius, $data)) {
            $output->param('error' => 'Der opstod en databasefejl under oprettelse af egenskaben');
        }
    } elsif(my $e = $input->param('egenskab')) {

        return OBVIUS_OK unless($e and $e =~ /^\d+$/);

        $output->param('mode' => 'egenskab_edit');

        if($input->param('go')) {
            $output->param('go' => 1);

            my $data = {};

            if(my $navn = $input->param('navn')) {
                $data->{navn} = $navn;
            } else {
                $output->param('error' => 'Du skal angive et navn på egenskaben');
                return OBVIUS_OK;
            }

            unless($this->update_egenskab($obvius, $e, $data)) {
                $output->param('error' => 'Der opstod en databasefejl under redigering af egenskaben');
            }
        } else {
            my $egenskaber = $this->get_egenskaber($obvius, {id => $e});
            if($egenskaber->[0]) {
                $output->param(egenskab => $egenskaber->[0]);
            } else {
                $output->param('mode' => '');
            }
        }
    } elsif($input->param('egenskab_delete')) {
        my $e = $input->param('e');

        return OBVIUS_OK unless($e and $e =~ /^\d+$/);

        $output->param('mode' => 'egenskab_delete');

        if($input->param('confirm')) {
            $this->delete_egenskab($obvius, $e);
            $output->param('deleted' => 1);
        } else {
            my $egenskaber = $this->get_egenskaber($obvius, {'id' => $e});
            if($egenskaber->[0]) {
                $output->param('egenskab' => $egenskaber->[0]);
            } else {
                $output->param('mode' => '');
            }
        }

    }

    ####################################
    #           Godkendelser           #
    ####################################

    elsif($input->param('godkendelse_new')) {
        my $o = $input->param('o');

        return OBVIUS_OK unless($o and $o =~ /^\d+$/);

        $output->param('mode' => 'godkendelse_new');

        if($input->param('go')) {

            $output->param('go' => 1);

            my $data = {};

            # Organisme relation
            $data->{organisme} = $o;

            # Ansøgningsnummer
            if(my $nr = $input->param('ansoegningsnr')) {
                my $nr_test = $nr;
                 $nr_test =~ s/'/\\'/gi;
                if(scalar(@{ $this->get_godkendelser($obvius, "organisme = '$o' AND ansoegningsnr = '$nr_test'") })) {
                    $output->param('error' => 'Der findes allerede en godkendelse med det ansøgningsnummer');
                    return OBVIUS_OK;
                } else {
                    $data->{ansoegningsnr} = $nr;
                }
            } else {
                $output->param('error' => 'Du skal angive et ansøgningsnummer');
                return OBVIUS_OK;
            }

            # Ansøger
            $data->{'ansoeger'} = $input->param('ansoeger') || '';

            # Ansøgerland
            $data->{'ansoegerland'} = $input->param('ansoegerland') || '';

            # Ansøgningsdato
            my $a_dato = $input->param('ansoegningsdato');
            $a_dato = '0000-00-00' unless($a_dato and $a_dato =~ /^\d\d\d\d-\d\d-\d\d$/);
            $data->{'ansoegningsdato'} = $a_dato;

            # Godkendelsesdato
            my $g_dato = $input->param('godkendelsesdato');
            $g_dato = '0000-00-00' unless($g_dato and $g_dato =~ /^\d\d\d\d-\d\d-\d\d$/);
            $data->{'godkendelsesdato'} = $g_dato;

            # Anvendelse
            $data->{'anvendelse'} = $input->param('anvendelse') || '';

            # Kommentar
            $data->{kommentar} = $input->param('kommentar') || '';

            # Godkendelser

            my $gk;

            $gk = $input->param('gk_foder');
            $gk = 'Ikke godkendt' unless($gk and $gk =~ /^(Ikke godkendt|Godkendt|Under behandling)$/);
            $data->{'gk_foder'} = $gk;

            $gk = $input->param('gk_teknisk');
            $gk = 'Ikke godkendt' unless($gk and $gk =~ /^(Ikke godkendt|Godkendt|Under behandling)$/);
            $data->{'gk_teknisk'} = $gk;

            $gk = $input->param('gk_dyrkning');
            $gk = 'Ikke godkendt' unless($gk and $gk =~ /^(Ikke godkendt|Godkendt|Under behandling)$/);
            $data->{'gk_dyrkning'} = $gk;

            $gk = $input->param('gk_dyrkning_opt');
            $gk = 'Ikke godkendt' unless($gk and $gk =~ /^(Ikke godkendt|Godkendt|Under behandling)$/);
            $data->{'gk_dyrkning_opt'} = $gk;

            $gk = $input->param('gk_foedevarer');
            $gk = 'Ikke godkendt' unless($gk and $gk =~ /^(Ikke godkendt|Godkendt|Under behandling)$/);
            $data->{'gk_foedevarer'} = $gk;

            $gk = $input->param('gk_foedevarer_opt');
            $gk = 'Ikke godkendt' unless($gk and $gk =~ /^(Ikke godkendt|Godkendt|Under behandling)$/);
            $data->{'gk_foedevarer_opt'} = $gk;

            $gk = $input->param('gk_laegemiddel');
            $gk = 'Ikke godkendt' unless($gk and $gk =~ /^(Ikke godkendt|Godkendt|Under behandling)$/);
            $data->{'gk_laegemiddel'} = $gk;

            $gk = $input->param('gk_laegemiddel_opt');
            $gk = 'Ikke godkendt' unless($gk and $gk =~ /^(Ikke godkendt|Godkendt|Under behandling)$/);
            $data->{'gk_laegemiddel_opt'} = $gk;

            # Sortsgodkendelse
	    my $sort = $input->param('sortsgodk');
            $data->{'sortsgodk'} = (defined($sort) ? $sort : 0);

            # Sortsgodkendelse - text
            $data->{'sortsgodk_text'} = $input->param('sortsgodk_text') || '';

            # Sortsgodkendelse - url
            my $sortgk_url = $input->param('sortsgodk_url') || '';
            $sortgk_url =~ s!^www!http://www!;
            $data->{'sortsgodk_url'} = $sortgk_url;

            # Dansk indsigelse
	    my $dk_ind = $input->param('dk_indsigelse');
            $data->{'dk_indsigelse'} = (defined($dk_ind) ? $dk_ind : 2);

            # Godkendte sorter - text
            $data->{'dk_indsigelse_text'} = $input->param('dk_indsigelse_text') || '';

            # Godkendte sorter - url
            my $dk_url = $input->param('dk_indsigelse_url') || '';
            $dk_url =~ s!^www!http://www!;
            $data->{'dk_indsigelse_url'} = $dk_url;

            # Godkendte sorter
            $data->{'gk_sorter'} = $input->param('gk_sorter') || 0;

            # Dansk indsigelse - text
            $data->{'gk_sorter_text'} = $input->param('gk_sorter_text') || '';

            # Dansk indsigelse - url
            my $sort_url = $input->param('gk_sorter_url') || '';
            $sort_url =~ s!^www!http://www!;
            $data->{'gk_sorter_url'} = $sort_url;

            # Videnskabelig udtalelse - text
            $data->{'udtalelse_text'} = $input->param('udtalelse_text') || '';

            # Videnskabelig udtalelse - url
            my $udt_url = $input->param('udtalelse_url') || '';
            $udt_url =~ s!^www!http://www!;
            $data->{'udtalelse_url'} = $udt_url;

            # Oprindelige ansøgere - text
            $data->{'opr_ans_text'} = $input->param('opr_ans_text') || '';

            # Oprindelige ansøgere - url
            my $ans_url = $input->param('opr_ans_url') || '';
            $ans_url =~ s!^www!http://www!;
            $data->{'opr_ans_url'} = $ans_url;

            unless($this->insert_godkendelse($obvius, $data)) {
                $output->param('error' => 'Der opstod en databasefejl ved oprettelse af godkendelsen');
                return OBVIUS_OK;
            }
        }
    } elsif(my $ansoeg_nr = $input->param('godkendelse')) {
        my $o = $input->param('o');
        return OBVIUS_OK unless($o and $o =~ /^\d+$/);

        $output->param('mode' => 'godkendelse_edit');

        if($input->param('go')) {

            $output->param('go' => 1);

            my $data = {};

            # Organisme relation
            $data->{organisme} = $o;

            # Ansøgningsnummer
            if(my $nr = $input->param('ansoegningsnr')) {
                $data->{ansoegningsnr} = $nr;
            } else {
                $output->param('error' => 'Du skal angive et ansøgningsnummer');
                return OBVIUS_OK;
            }

            # Ansøger
            $data->{'ansoeger'} = $input->param('ansoeger') || '';

            # Ansøgerland
            $data->{'ansoegerland'} = $input->param('ansoegerland') || '';

            # Ansøgningsdato
            my $a_dato = $input->param('ansoegningsdato');
            $a_dato = '0000-00-00' unless($a_dato and $a_dato =~ /^\d\d\d\d-\d\d-\d\d$/);
            $data->{'ansoegningsdato'} = $a_dato;

            # Godkendelsesdato
            my $g_dato = $input->param('godkendelsesdato');
            $g_dato = '0000-00-00' unless($g_dato and $g_dato =~ /^\d\d\d\d-\d\d-\d\d$/);
            $data->{'godkendelsesdato'} = $g_dato;

            # Anvendelse
            $data->{'anvendelse'} = $input->param('anvendelse') || '';

            # Kommentar
            $data->{kommentar} = $input->param('kommentar') || '';

            # Godkendelser

            my $gk;

            $gk = $input->param('gk_foder');
            $gk = 'Ikke godkendt' unless($gk and $gk =~ /^(Ikke godkendt|Godkendt|Under behandling)$/);
            $data->{'gk_foder'} = $gk;

            $gk = $input->param('gk_teknisk');
            $gk = 'Ikke godkendt' unless($gk and $gk =~ /^(Ikke godkendt|Godkendt|Under behandling)$/);
            $data->{'gk_teknisk'} = $gk;

            $gk = $input->param('gk_dyrkning');
            $gk = 'Ikke godkendt' unless($gk and $gk =~ /^(Ikke godkendt|Godkendt|Under behandling)$/);
            $data->{'gk_dyrkning'} = $gk;

            $gk = $input->param('gk_dyrkning_opt');
            $gk = 'Ikke godkendt' unless($gk and $gk =~ /^(Ikke godkendt|Godkendt|Under behandling)$/);
            $data->{'gk_dyrkning_opt'} = $gk;

            $gk = $input->param('gk_foedevarer');
            $gk = 'Ikke godkendt' unless($gk and $gk =~ /^(Ikke godkendt|Godkendt|Under behandling)$/);
            $data->{'gk_foedevarer'} = $gk;

            $gk = $input->param('gk_foedevarer_opt');
            $gk = 'Ikke godkendt' unless($gk and $gk =~ /^(Ikke godkendt|Godkendt|Under behandling)$/);
            $data->{'gk_foedevarer_opt'} = $gk;

            $gk = $input->param('gk_laegemiddel');
            $gk = 'Ikke godkendt' unless($gk and $gk =~ /^(Ikke godkendt|Godkendt|Under behandling)$/);
            $data->{'gk_laegemiddel'} = $gk;

            $gk = $input->param('gk_laegemiddel_opt');
            $gk = 'Ikke godkendt' unless($gk and $gk =~ /^(Ikke godkendt|Godkendt|Under behandling)$/);
            $data->{'gk_laegemiddel_opt'} = $gk;

            # Sortsgodkendelse
            $data->{'sortsgodk'} = $input->param('sortsgodk') || 0;

            # Sortsgodkendelse - text
            $data->{'sortsgodk_text'} = $input->param('sortsgodk_text') || '';

            # Sortsgodkendelse - url
            my $sortgk_url = $input->param('sortsgodk_url') || '';
            $sortgk_url =~ s!^www!http://www!;
            $data->{'sortsgodk_url'} = $sortgk_url;

            # Dansk indsigelse
            $data->{'dk_indsigelse'} = $input->param('dk_indsigelse') || 2;

            # Godkendte sorter - text
            $data->{'dk_indsigelse_text'} = $input->param('dk_indsigelse_text') || '';

            # Godkendte sorter - url
            my $dk_url = $input->param('dk_indsigelse_url') || '';
            $dk_url =~ s!^www!http://www!;
            $data->{'dk_indsigelse_url'} = $dk_url;

            # Godkendte sorter
            $data->{'gk_sorter'} = $input->param('gk_sorter') || 0;

            # Dansk indsigelse - text
            $data->{'gk_sorter_text'} = $input->param('gk_sorter_text') || '';

            # Dansk indsigelse - url
            my $sort_url = $input->param('gk_sorter_url') || '';
            $sort_url =~ s!^www!http://www!;
            $data->{'gk_sorter_url'} = $sort_url;

            # Videnskabelig udtalelse - text
            $data->{'udtalelse_text'} = $input->param('udtalelse_text') || '';

            # Videnskabelig udtalelse - url
            my $udt_url = $input->param('udtalelse_url') || '';
            $udt_url =~ s!^www!http://www!;
            $data->{'udtalelse_url'} = $udt_url;

            # Oprindelige ansøgere - text
            $data->{'opr_ans_text'} = $input->param('opr_ans_text') || '';

            # Oprindelige ansøgere - url
            my $ans_url = $input->param('opr_ans_url') || '';
            $ans_url =~ s!^www!http://www!;
            $data->{'opr_ans_url'} = $ans_url;

           unless($this->update_godkendelse($obvius, $o, $ansoeg_nr, $data)) {
                $output->param('error' => 'Der opstod en databasefejl ved redigering af godkendelsen');
                return OBVIUS_OK;
            }
        } else {
            my $godkendelser = $this->get_godkendelser($obvius, {'ansoegningsnr' => $ansoeg_nr, 'organisme' => $o});
            if($godkendelser->[0]) {
                $output->param('godkendelse' => $godkendelser->[0]);
            } else {
                $output->param('go' => 1);
                $output->param('error' => 'Kunne ikke finde den angivne godkendelse');
            }
        }
    } elsif($input->param('godkendelse_delete') or $input->param('godkendelse_archive')) {
        my $what_to_do=($input->param('godkendelse_delete') ? 'godkendelse_delete' : 'godkendelse_archive');

        my $o = $input->param('o');
        return OBVIUS_OK unless($o and $o =~ /^\d+$/);

        my $ansoeg_nr = $input->param('g');
        return OBVIUS_OK unless($ansoeg_nr);

        $output->param('mode' => $what_to_do);

        if($input->param('confirm')) {
            if ($what_to_do eq 'godkendelse_delete') {
                $this->delete_godkendelser($obvius, { 'organisme' => $o, 'ansoegningsnr' => $ansoeg_nr });
                $output->param('deleted' => 1);
            }
            else {
                $this->archive_godkendelser($obvius, { 'organisme' => $o, 'ansoegningsnr' => $ansoeg_nr });
                $output->param('archived' => 1);
            }
        } else {
            my $godkendelser = $this->get_godkendelser($obvius, {'ansoegningsnr' => $ansoeg_nr, 'organisme' => $o});
            if($godkendelser->[0]) {
                $output->param('godkendelse' => $godkendelser->[0]);
            } else {
                # Skip it all
                $output->param('mode' => '');
            }
        }

    }

    ####################################
    # Default action: list organismer  #
    ####################################

    unless($output->param('mode')) {
        # Default action, list
        $output->param('organismer' => $this->get_organismer($obvius));
    }

    return OBVIUS_OK;
}



#############################################################
#                                                           #
#                         Organismer                        #
#                                                           #
#############################################################

sub get_organismer {
    my ($this, $obvius, $searchexpression, $order) = @_;

    $order ||= 'betegnelse';

    my $set=DBIx::Recordset->SetupObject( {
                                            '!DataSource'   => $obvius->{DB},
                                            '!Table'        => 'gk_organismer',
                                            '!Order'        => $order
                                        } );
    $set->Search($searchexpression);
    my @data;
    while(my $rec = $set->Next) {
        push(@data, $rec);
    }
    $set->Disconnect;

    return \@data;
}

sub insert_organisme {
    my ($this, $obvius, $organisme) = @_;

    my $set=DBIx::Recordset->SetupObject( {
                                            '!DataSource'   => $obvius->{DB},
                                            '!Table'        => 'gk_organismer',
                                            '!Serial'       => 'id'
                                        } );
    my $retval = $set->Insert($organisme);
    $set->Disconnect;

    return $retval ? $set->LastSerial : undef;
}

sub update_organisme {
    my ($this, $obvius, $organisme, $data) = @_;

    my $set=DBIx::Recordset->SetupObject( {
                                            '!DataSource'   => $obvius->{DB},
                                            '!Table'        => 'gk_organismer',
                                        } );
    my $retval = $set->Update($data, { 'id' => $organisme });
    $set->Disconnect;

    return $retval;
}

sub delete_organisme {
    my ($this, $obvius, $organisme) = @_;

    # First delete relations
    $this->delete_org_egenskaber($obvius, {'organisme' => $organisme});
    $this->delete_godkendelser($obvius, {'organisme' => $organisme});

    # Delete self

    my $set=DBIx::Recordset->SetupObject( {
                                            '!DataSource'   => $obvius->{DB},
                                            '!Table'        => 'gk_organismer',
                                        } );
    my $retval = $set->Delete({ 'id' => $organisme });
    $set->Disconnect;

    return $retval;
}

#############################################################
#                                                           #
#                       Godkendelser                        #
#                                                           #
#############################################################

sub get_godkendelser {
    my ($this, $obvius, $searchexpression, $order) = @_;

    $order ||= 'ansoegningsnr';

    my $set=DBIx::Recordset->SetupObject( {
                                            '!DataSource'   => $obvius->{DB},
                                            '!Table'        => 'gk_godkendelser',
                                            '!Order'        => $order
                                        } );
    $set->Search($searchexpression);
    my @data;
    while(my $rec = $set->Next) {
        push(@data, $rec);
    }
    $set->Disconnect;

    return \@data;
}

sub insert_godkendelse {
    my ($this, $obvius, $godkendelse) = @_;

    my $set=DBIx::Recordset->SetupObject( {
                                            '!DataSource'   => $obvius->{DB},
                                            '!Table'        => 'gk_godkendelser',
                                        } );
    my $retval = $set->Insert($godkendelse);
    $set->Disconnect;

    return $retval;
}

sub update_godkendelse {
    my ($this, $obvius, $organisme, $nr, $data) = @_;

    $DBIx::Recordset::Debug = 18;

    my $set=DBIx::Recordset->SetupObject( {
                                            '!DataSource'   => $obvius->{DB},
                                            '!Table'        => 'gk_godkendelser',
                                            '!Debug'        => 2
                                        } );
    my $retval = $set->Update($data, { 'organisme' => $organisme, 'ansoegningsnr' => $nr });
    $set->Disconnect;

    return $retval;
}

sub delete_godkendelser {
    my ($this, $obvius, $where) = @_;

    my $set=DBIx::Recordset->SetupObject( {
                                            '!DataSource'   => $obvius->{DB},
                                            '!Table'        => 'gk_godkendelser',
                                        } );
    my $retval = $set->Delete($where);
    $set->Disconnect;

    return $retval;
}

sub archive_godkendelser {
    my ($this, $obvius, $where) = @_;

    my $set=DBIx::Recordset->SetupObject( {
                                            '!DataSource'   => $obvius->{DB},
                                            '!Table'        => 'gk_godkendelser',
                                        } );

    my $retval = $set->Update( { archived=>1 }, $where );
    $set->Disconnect;

    return $retval;
}

#############################################################
#                                                           #
#                         Egenskaber                        #
#                                                           #
#############################################################


sub get_egenskaber {
    my ($this, $obvius, $searchexpression) = @_;

    my $set=DBIx::Recordset->SetupObject( {
                                            '!DataSource'   => $obvius->{DB},
                                            '!Table'        => 'gk_egenskaber',
                                            '!Order'        => 'navn'
                                        } );
    $set->Search($searchexpression);
    my @data;
    while(my $rec = $set->Next) {
        push(@data, $rec);
    }
    $set->Disconnect;

    return \@data;
}

sub update_egenskab {
    my ($this, $obvius, $egenskab, $data) = @_;

    my $set=DBIx::Recordset->SetupObject( {
                                            '!DataSource'   => $obvius->{DB},
                                            '!Table'        => 'gk_egenskaber',
                                        } );
    my $retval = $set->Update($data, { 'id' => $egenskab });
    $set->Disconnect;

    return $retval;
}

sub insert_egenskab {
    my ($this, $obvius, $data) = @_;

    my $set=DBIx::Recordset->SetupObject( {
                                            '!DataSource'   => $obvius->{DB},
                                            '!Table'        => 'gk_egenskaber',
                                            '!Serial'       => 'id'
                                        } );
    my $retval = $set->Insert($data);
    $set->Disconnect;

    return $retval ? $set->LastSerial : undef;

}

sub delete_egenskab {
    my ($this, $obvius, $egenskab_id) = @_;

    # First delete relations
    $this->delete_org_egenskaber($obvius, {'egenskab' => $egenskab_id});

    # Delete self
    my $set=DBIx::Recordset->SetupObject( {
                                            '!DataSource'   => $obvius->{DB},
                                            '!Table'        => 'gk_egenskaber',
                                        } );
    my $retval = $set->Delete({ 'id' => $egenskab_id });
    $set->Disconnect;

    return $retval;
}

#############################################################
#                                                           #
#               Organisme/egenskab realtioner               #
#                                                           #
#############################################################

sub get_org_egenskaber {
    my ($this, $obvius, $searchexpression, %options) = @_;

    my $tables = 'gk_organisme_egenskaber';
    my $tabrelation = '';

    if($options{get_navn}) {
        $tables .= ', gk_egenskaber';
        $tabrelation .= 'gk_organisme_egenskaber.egenskab = gk_egenskaber.id';
    }

    my $set=DBIx::Recordset->SetupObject( {
                                            '!DataSource'   => $obvius->{DB},
                                            '!Table'        => $tables,
                                            '!TabRelation'  => $tabrelation,
                                        } );
    $set->Search($searchexpression);
    my @data;
    while(my $rec = $set->Next) {
        push(@data, $rec);
    }
    $set->Disconnect;

    return \@data;
}

sub insert_org_egenskaber {
    my ($this, $obvius, $organisme, $egenskaber) = @_;

    $egenskaber ||= [];

    my $set=DBIx::Recordset->SetupObject( {
                                            '!DataSource'   => $obvius->{DB},
                                            '!Table'        => 'gk_organisme_egenskaber',
                                        } );
    for(@$egenskaber) {
        $set->Insert({ organisme => $organisme, egenskab => $_ });
    }
}

sub delete_org_egenskaber {
    my ($this, $obvius, $where) = @_;

    my $set=DBIx::Recordset->SetupObject( {
                                            '!DataSource'   => $obvius->{DB},
                                            '!Table'        => 'gk_organisme_egenskaber',
                                        } );
    my $retval = $set->Delete($where);
    $set->Disconnect;

    return $retval;
}


1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Obvius::DocType::ProduktOversigt - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Obvius::DocType::ProduktOversigt;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Obvius::DocType::ProduktOversigt, created by h2xs. It looks like the
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
