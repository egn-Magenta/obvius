package Obvius::DocType::ForsoegsSearch;

# $Id$

use strict;
use warnings;

use Obvius;
use Obvius::DocType;

our @ISA = qw( Obvius::DocType );
our ( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub action {
    my ($this, $input, $output, $doc, $vdoc, $obvius) = @_;

    return $this->admin_handler($input, $output, $doc, $vdoc, $obvius) if($input->param('IS_ADMIN'));

    return $this->advsearch_handler($input, $output, $doc, $vdoc, $obvius) if($input->param('mode') and $input->param('mode') eq 'advsearch');

    my $godkendelse = $input->param('godkendelse');
    if($godkendelse and $godkendelse =~ /^\d+$/) {
        $output->param('show_godkendelse' => 1);

        my $gks = $this->get_godkendelser($obvius, {'fsu_godkendelser.id' => $godkendelse});
        if($gks->[0]) {
            $output->param('godkendelse' => $gks->[0]);
            $output->param('egenskaber' => $this->get_godkendelse_egenskaber($obvius, { godkendelse => $godkendelse }, get_navn => 1));
            $output->param('udsaetninger' => $this->get_udsaetninger($obvius, {godkendelse => $godkendelse}));
            $output->param('areal_total' => $this->get_areal($obvius, $godkendelse));

            $output->param('override_title' => "Forsøgsgodkendelse: " . $gks->[0]->{godkendelsesnr});
        }

        # Do stuff.
        return OBVIUS_OK;
    }

    my $udsaetning = $input->param('udsaetning');
    if($udsaetning and $udsaetning =~ /^\d+$/) {
        $output->param('show_udsaetning' => 1);
        my $uds = $this->get_udsaetninger($obvius, {id => $udsaetning});
        if($uds->[0]) {
            $output->param('udsaetning' => $uds->[0]);
            my $gks = $this->get_godkendelser($obvius, {'fsu_godkendelser.id' => $uds->[0]->{godkendelse}});
            if($gks->[0]) {
                $output->param('godkendelse' => $gks->[0]);
                $output->param('egenskaber' => $this->get_godkendelse_egenskaber($obvius, { godkendelse => $gks->[0]->{id} }, get_navn => 1));

                $output->param('override_title' => $gks->[0]->{godkendelsesnr} . " ved " . $uds->[0]->{navn});
            }

        }

    }

    my $searchexpression = {};

    $output->param('egenskaber' => $this->get_egenskaber($obvius));

    if(my $egenskab = $input->param('egenskab')) {
        $searchexpression->{'fsu_godkendelse_egenskaber.egenskab'} = $egenskab;

        my $egenskaber = $this->get_egenskaber($obvius, {'id' => $egenskab});
        if($egenskaber->[0]) {
            $output->param('soeg_egenskab' => "Alle med " . $egenskaber->[0]->{navn});
        }
        $output->param('egenskab_selected' => $egenskab);
    }

    my $order;

    my $sortby = $input->param('sortby');
    $sortby = 'aar' unless($sortby and $sortby eq 'produkt');

    if($sortby eq 'produkt') {
        $order = 'fsu_produkter.navn, fsu_godkendelser.aar DESC';
        $output->param('sorttype' => 2);
    } else {
        $order = 'fsu_godkendelser.aar DESC, fsu_produkter.navn';
        $output->param('sorttype' => 1);
    }

    use Data::Dumper;
    my $result = $this->standardsearch($obvius, $searchexpression, $order) || [];

    my @result;
    for(@$result) {
        push(@result, {
                        'egenskaber' => $this->get_godkendelse_egenskaber($obvius, { godkendelse => $_->{id} }, get_navn => 1),
                        'år' => $_->{aar},
                        'produkt' => $_->{produktnavn},
                        'nr' => $_->{godkendelsesnr},
                        'formål' => $_->{formaal},
                        'godkendelse' => $_->{id},
                    }
                    );

    }

    $output->param('result' => \@result) if(scalar(@result));

    return OBVIUS_OK;
}

sub standardsearch {
    my ($this, $obvius, $searchexpression, $order) = @_;

    $order ||= 'godkendelsesnr';

    my $set=DBIx::Recordset->SetupObject( {
                                            '!DataSource'   => $obvius->{DB},
                                            '!Table'        => 'fsu_godkendelser, fsu_godkendelse_egenskaber, fsu_produkter',
                                            '!TabRelation'  => 'fsu_godkendelser.id = fsu_godkendelse_egenskaber.godkendelse AND fsu_godkendelser.produkt = fsu_produkter.id',
                                            '!Fields'       => 'distinct fsu_godkendelser.*, fsu_produkter.navn as produktnavn',
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


sub advsearch_handler {
    my ($this, $input, $output, $doc, $vdoc, $obvius) = @_;

    # Get stuff for dropdowns


    my $stuff = {
                    gk_nrs => {},
                    ansoegere => {},
                    amter => {},
                };

    my $gdks = $this->get_godkendelser($obvius);
    for(@$gdks) {
        $stuff->{gk_nrs}->{ $_->{godkendelsesnr} } = 1 if($_->{godkendelsesnr});
        $stuff->{ansoegere}->{ $_->{ansoeger} } = 1 if($_->{ansoeger});
    }

    my $udsaetninger = $this->get_udsaetninger($obvius);
    for(@$udsaetninger) {
        $stuff->{amter}->{ $_->{amt} } = 1 if($_->{amt});
    }

    my @gk_nrs = keys %{ $stuff->{gk_nrs} };
    my @ansoegere = keys %{ $stuff->{ansoegere} };
    my @amter = keys %{ $stuff->{amter} };

    $output->param('gk_nrs' => \@gk_nrs);
    $output->param('ansoegere' => \@ansoegere);
    $output->param('amter' => \@amter);

    $output->param('produkter' => $this->get_produkter($obvius));

    $output->param('egenskaber' => $this->get_egenskaber($obvius));

    my $tables = 'fsu_godkendelser, fsu_udsaetninger';
    my $tabrelation = 'fsu_godkendelser.id = fsu_udsaetninger.godkendelse';
    my $fields = 'fsu_godkendelser.id as godkendelse, fsu_godkendelser.godkendelsesnr as nr';

    my @searchedon;
    my $where = '';

    # År
    $fields .= ', fsu_godkendelser.aar as aar';

    # Formål
    $fields .= ', fsu_godkendelser.formaal as formaal';

    # produkt
    $tables .= ', fsu_produkter';
    $tabrelation .= ' AND fsu_godkendelser.produkt = fsu_produkter.id';
    $fields .= ', fsu_produkter.navn as produktnavn';


    if(my $amt = $input->param('amt')) {
        $where .= "fsu_udsaetninger.amt = '$amt'";
        push(@searchedon, "Amt: $amt");
    }

    if(my $gk_nr = $input->param('gk_nr')) {
        $where .= ' AND ' if($where);
        $where .= "fsu_godkendelser.godkendelsesnr = '$gk_nr'";
        push(@searchedon, "Godkendelsesnr: $gk_nr");
    }

    if(my $ansoeger = $input->param('ansoeger')) {
        $where .= ' AND ' if($where);
        $where .= "fsu_godkendelser.ansoeger = '$ansoeger'";
        push(@searchedon, "Ansøger: $ansoeger");
    }

    my @egenskaber_in = map { /^egenskab_(\d+)/i; $1 } grep { /^egenskab_\d+/i } $input->param();

    my $egenskaber_searched = '';
    for(@egenskaber_in) {
        $tables .= ', fsu_godkendelse_egenskaber as e_tab_' . $_;
        $tabrelation .= ' AND fsu_godkendelser.id = e_tab_' . $_ . '.godkendelse';
        $where .= ' AND ' if($where);
        $where .= 'e_tab_' . $_ . '.egenskab = ' . $_;

        my $egns = $this->get_egenskaber($obvius, {id => $_});
        if($egns->[0]) {
            $egenskaber_searched .= ', ' if($egenskaber_searched);
            $egenskaber_searched .= $egns->[0]->{navn};
        }
    }
    $egenskaber_searched =~ s/, ([^,]+)$/ og $1/;
    push(@searchedon, "Egenskaber: $egenskaber_searched") if($egenskaber_searched);

    if(my $produkt = $input->param('produkt')) {
        my $pdks_searched = '';

        $produkt = [ $produkt ] unless(ref($produkt));
        $where .= ' AND ' if($where);
        $where .= 'fsu_godkendelser.produkt IN (' . join(',', @$produkt) . ')';

        for(@$produkt) {
            my $pdks = $this->get_produkter($obvius, {id => $_});
            if($pdks->[0]) {
                $pdks_searched .= ', ' if($pdks_searched);
                $pdks_searched .= $pdks->[0]->{navn};
            }
        }
        $pdks_searched =~ s/, ([^,]+)$/ eller $1/;
        push(@searchedon, "Produkter: $pdks_searched") if($pdks_searched);
    }

    my $set=DBIx::Recordset->SetupObject( {
                                            '!DataSource'   => $obvius->{DB},
                                            '!Table'        => $tables,
                                            '!TabRelation'  => $tabrelation,
                                            '!Fields'       => $fields,
                                            '!Order'        => 'fsu_godkendelser.aar DESC, fsu_produkter.navn'
                                        } );
    $set->Search($where);
    my @data;
    while(my $rec = $set->Next) {
        push(@data, $rec);
    }
    $set->Disconnect;

    my $areal_min = $input->param('area_min');
    my $areal_max = $input->param('area_max');

    $areal_min = undef if(defined($areal_min) and $areal_min !~ /^\d+$/);
    $areal_max = undef if(defined($areal_max) and $areal_max !~ /^\d+$/);

    push(@searchedon, "Minimumareal: $areal_min") if(defined($areal_min));
    push(@searchedon, "Maximumareal: $areal_max") if(defined($areal_max));

    my $dublicates;

    my @result;

    for my $d (@data) {
        next if($dublicates->{ $d->{godkendelse} });
        $dublicates->{ $d->{godkendelse} } = 1;
        if(defined($areal_min) or defined($areal_max)) {
            my $areal =  $this->get_areal($obvius, $d->{godkendelse});
            next if(defined($areal_min) and $areal < $areal_min);
            next if(defined($areal_max) and $areal > $areal_max);
        }

        push(@result, {
                        'egenskaber' => $this->get_godkendelse_egenskaber($obvius, { godkendelse => $d->{godkendelse} }, get_navn => 1),
                        'år' => $d->{aar},
                        'produkt' => $d->{produktnavn},
                        'nr' => $d->{nr},
                        'formål' => $d->{formaal},
                        'godkendelse' => $d->{godkendelse},
                    });
    }

    $output->param(result => \@result) if(@result);
    $output->param('searchedon' => \@searchedon) if(scalar(@searchedon));

    return OBVIUS_OK;

}

sub get_areal {
    my ($this, $obvius, $godkendelse) = @_;

    my $set=DBIx::Recordset->SetupObject( {
                                            '!DataSource'   => $obvius->{DB},
                                            '!Table'        => 'fsu_udsaetninger',
                                            '!Fields'       => 'sum(areal) as areal'
                                        } );
    $set->Search( { godkendelse => $godkendelse } );
    my $result;
    if(my $rec = $set->Next) {
        $result = $rec->{areal};
    }
    $set->Disconnect;

    return $result;
}

sub dkkort_search {
    my ($this, $obvius, $year) = @_;

    my $set=DBIx::Recordset->SetupObject( {
                                            '!DataSource'   => $obvius->{DB},
                                            '!Table'        => 'fsu_godkendelser, fsu_udsaetninger, fsu_produkter',
                                            '!TabRelation'  => 'fsu_godkendelser.id = fsu_udsaetninger.godkendelse AND fsu_godkendelser.produkt = fsu_produkter.id',
                                            '!Fields'       => 'fsu_godkendelser.godkendelsesnr as nr,
                                                                fsu_udsaetninger.xpos as xpos,
                                                                fsu_udsaetninger.ypos as ypos,
                                                                fsu_udsaetninger.navn as stednavn,
                                                                fsu_produkter.ikon as ikon,
                                                                fsu_udsaetninger.id as u_id,
                                                                fsu_godkendelser.id as g_id'
                                        } );
    $set->Search( {'fsu_godkendelser.aar' => $year} );
    my @data;
    while(my $rec = $set->Next) {
        push(@data, $rec);
    }
    $set->Disconnect;

    return \@data;
}

sub get_distinct_years {
    my ($this, $obvius) = @_;

    my $set=DBIx::Recordset->SetupObject( {
                                            '!DataSource'   => $obvius->{DB},
                                            '!Table'        => 'fsu_godkendelser',
                                            '!Fields'       => 'distinct aar',
                                            '!Order'        => 'aar DESC'
                                        } );
    $set->Search();
    my @data;
    while(my $rec = $set->Next) {
        push(@data, $rec->{aar});
    }
    $set->Disconnect;

    return \@data;

}


sub admin_handler {
    my ($this, $input, $output, $doc, $vdoc, $obvius) = @_;

    $output->param('admin' => 1);

    ####################################
    #           Godkendelser           #
    ####################################

    if($input->param('godkendelse_new')) {
        $output->param('mode' => 'godkendelse_new');
        if($input->param('go')) {

            $output->param('go' => 1);

            my $data = {};

            if(my $godkendelsesnr = $input->param('godkendelsesnr')) {
                my $godkendelsesnr_test = $godkendelsesnr;
                 $godkendelsesnr_test =~ s/'/\\'/gi;
                if(scalar(@{ $this->get_godkendelser($obvius, "godkendelsesnr = '$godkendelsesnr'") })) {
                    $output->param('error' => 'Der findes allerede en godkendelse med det godkendelsesnummer');
                    return OBVIUS_OK;
                } else {
                    $data->{godkendelsesnr} = $godkendelsesnr;
                }
            } else {
                $output->param('error' => 'Du skal angive et godkendelsesnr');
                return OBVIUS_OK;
            }

            if(my $produkt = $input->param('produkt')) {
                $data->{produkt} = $produkt;
            } else {
                $output->param('error' => 'Du skal angive et produkt');
                return OBVIUS_OK;
            }

            $data->{ansoeger} = $input->param('ansoeger') || '';

            $data->{formaal} = $input->param('formaal') || '';

            $data->{kommentar} = $input->param('kommentar') || '';

            if(my $aar = $input->param('aar')) {
                if($aar =~ /^\d\d\d\d$/) {
                    $data->{aar} = $aar;
                } else {
                    $output->param('error' => "År skal være et tal på 4 cifre");
                    return OBVIUS_OK;
                }
            } else {
                $output->param('error' => 'Du skal angive et år');
                return OBVIUS_OK;
            }

            my @egenskaber_in = map { /^egenskab_(\d+)/i; $1 } grep { /^egenskab_\d+/i } $input->param();

            my @egenskaber;
            for(@egenskaber_in) {
                push(@egenskaber, $_) if(scalar(@{ $this->get_egenskaber($obvius, "id = '$_'") }));
            }

            # OK, so far no errors, let's insert
            if(my $id = $this->insert_godkendelse($obvius, $data)) {
                $this->insert_godkendelse_egenskaber($obvius, $id, \@egenskaber) if(scalar(@egenskaber));
            } else {
                $output->param('error' => 'Der opstod en databasefejl ved oprettelse af godkendelsen');
                return OBVIUS_OK;
            }
        } else {
            $output->param('egenskaber' => $this->get_egenskaber($obvius));
            $output->param('produkter' => $this->get_produkter($obvius));
            return OBVIUS_OK;
        }
    } elsif(my $godkendelse = $input->param('godkendelse')) {
        if($godkendelse =~ /^\d+$/) {
            $output->param('mode' => 'godkendelse_edit');
        } else {
            return OBVIUS_OK;
        }

        if($input->param('go')) {
            $output->param('go' => 1);

            my $data = {};

            if(my $godkendelsesnr = $input->param('godkendelsesnr')) {
                my $godkendelsesnr_test = $godkendelsesnr;
                 $godkendelsesnr_test =~ s/'/\\'/gi;
                if(scalar(@{ $this->get_godkendelser($obvius, "godkendelsesnr = '$godkendelsesnr' AND fsu_godkendelser.id != '$godkendelse'") })) {
                    $output->param('error' => 'Der findes allerede en godkendelse med det godkendelsesnummer');
                    return OBVIUS_OK;
                } else {
                    $data->{godkendelsesnr} = $godkendelsesnr;
                }
            } else {
                $output->param('error' => 'Du skal angive et godkendelsesnr');
                return OBVIUS_OK;
            }

            if(my $produkt = $input->param('produkt')) {
                $data->{produkt} = $produkt;
            } else {
                $output->param('error' => 'Du skal angive et produkt');
                return OBVIUS_OK;
            }

            $data->{ansoeger} = $input->param('ansoeger') || '';

            $data->{formaal} = $input->param('formaal') || '';

            $data->{kommentar} = $input->param('kommentar') || '';

            if(my $aar = $input->param('aar')) {
                if($aar =~ /^\d\d\d\d$/) {
                    $data->{aar} = $aar;
                } else {
                    $output->param('error' => "År skal være et tal på 4 cifre");
                    return OBVIUS_OK;
                }
            } else {
                $output->param('Du skal angive et år');
                return OBVIUS_OK;
            }

            my @egenskaber_in = map { /^egenskab_(\d+)/i; $1 } grep { /^egenskab_\d+/i } $input->param();

            my @egenskaber;
            for(@egenskaber_in) {
                push(@egenskaber, $_) if(scalar(@{ $this->get_egenskaber($obvius, "id = '$_'") }));
            }

            # OK, so far no errors, let's update
            if($this->update_godkendelse($obvius, $godkendelse, $data)) {
                    $this->delete_godkendelse_egenskaber($obvius, {'godkendelse' => $godkendelse});
                    $this->insert_godkendelse_egenskaber($obvius, $godkendelse, \@egenskaber) if(scalar(@egenskaber));
            } else {
                $output->param('error' => 'Der opstod en databasefejl ved redigering af godkendelsen');
                return OBVIUS_OK;
            }
        } else {
            my $gdks = $this->get_godkendelser($obvius, {'fsu_godkendelser.id' => $godkendelse});
            if($gdks->[0]) {
                $output->param('godkendelse' => $gdks->[0]);

                $output->param('egenskaber' => $this->get_egenskaber($obvius));
                $output->param('produkter' => $this->get_produkter($obvius));

                my @egenskaber_chosen = map { $_->{egenskab} } @{ $this->get_godkendelse_egenskaber($obvius, { 'godkendelse' => $gdks->[0]->{id} }) };
                $output->param('egenskaber_chosen' => \@egenskaber_chosen);

                $output->param('udsaetninger' => $this->get_udsaetninger($obvius, {godkendelse => $gdks->[0]->{id}}));

            } else {
                # Alert the user
                $output->param('go' => 1);
                $output->param('error' => "Kunne ikke finde godkendelse med id '$godkendelse'");
            }
        }
    } elsif($input->param('godkendelse_delete')) {

        my $g = $input->param('g');
        return OBVIUS_OK unless($g and $g =~ /^\d+/);

        $output->param('mode' => 'godkendelse_delete');

        if($input->param('confirm')) {
            $this->delete_godkendelse($obvius, $g);
            $output->param('deleted' => 1);
        } else {
            my $gdks = $this->get_godkendelser($obvius, {'fsu_godkendelser.id' => $g});
            if($gdks->[0]) {
                $output->param('godkendelse' => $gdks->[0]);
            } else {
                $output->param('mode' => '');
            }
        }
    }


    ####################################
    #           Udsætninger            #
    ####################################

    elsif($input->param('udsaetning_new')) {
        my $g = $input->param('g');

        return OBVIUS_OK unless($g and $g =~ /^\d+$/);

        $output->param('mode' => 'udsaetning_new');

        if($input->param('go')) {

            $output->param('go' => 1);

            my $data = {};

            # Organisme relation
            $data->{godkendelse} = $g;

            if(my $navn = $input->param('navn')) {
                $data->{navn} = $navn;
            } else {
                $output->param('error' => 'Du skal angive et navn');
            }

            $data->{amt} = $input->param('amt') || '';
            $data->{adresse} = $input->param('adresse') || '';

            my $areal = $input->param('areal');
            if(defined($areal)) {
                if($areal =~ /^\d+$/) {
                    $data->{areal} = $areal;
                } else {
                    $output->param('error' => 'Areal skal være et positivt heltal');
                    return OBVIUS_OK;
                }
            } else {
                $output->param('error' => 'Du skal angive et areal');
                return OBVIUS_OK;
            }

            my $xpos = $input->param('xpos');
            if(defined($xpos)) {
                if($xpos =~ /^\d+$/) {
                    $data->{xpos} = $xpos;
                } else {
                    $output->param('error' => 'X-koordinat skal være et tal');
                    return OBVIUS_OK;
                }
            } else {
                $output->param('error' => 'Du skal angive et X-koordinat');
                return OBVIUS_OK;
            }

            my $ypos = $input->param('ypos');
            if(defined($ypos)) {
                if($ypos =~ /^\d+$/) {
                    $data->{ypos} = $ypos;
                } else {
                    $output->param('error' => 'Y-koordinat skal være et tal');
                    return OBVIUS_OK;
                }
            } else {
                $output->param('error' => 'Du skal angive et Y-koordinat');
                return OBVIUS_OK;
            }

            unless($this->insert_udsaetning($obvius, $data)) {
                $output->param('error' => 'Der opstod en databasefejl ved oprettelse af udsætningen');
                return OBVIUS_OK;
            }
        }
    } elsif(my $udsaetning = $input->param('udsaetning')) {

        return OBVIUS_OK unless($udsaetning and $udsaetning =~ /^\d+$/);

        $output->param('mode' => 'udsaetning_edit');

        if($input->param('go')) {

            $output->param('go' => 1);

            my $data = {};

            # Godkendelse relation skulle ikke blive ændret
            # $data->{godkendelse} = nothing

            if(my $navn = $input->param('navn')) {
                $data->{navn} = $navn;
            } else {
                $output->param('error' => 'Du skal angive et navn');
            }

            $data->{amt} = $input->param('amt') || '';
            $data->{adresse} = $input->param('adresse') || '';

            my $areal = $input->param('areal');
            if(defined($areal)) {
                if($areal =~ /^\d+$/) {
                    $data->{areal} = $areal;
                } else {
                    $output->param('error' => 'Areal skal være et positivt heltal');
                    return OBVIUS_OK;
                }
            } else {
                $output->param('error' => 'Du skal angive et areal');
                return OBVIUS_OK;
            }

            my $xpos = $input->param('xpos');
            if(defined($xpos)) {
                if($xpos =~ /^\d+$/) {
                    $data->{xpos} = $xpos;
                } else {
                    $output->param('error' => 'X-koordinat skal være et tal');
                    return OBVIUS_OK;
                }
            } else {
                $output->param('error' => 'Du skal angive et X-koordinat');
                return OBVIUS_OK;
            }

            my $ypos = $input->param('ypos');
            if(defined($ypos)) {
                if($ypos =~ /^\d+$/) {
                    $data->{ypos} = $ypos;
                } else {
                    $output->param('error' => 'Y-koordinat skal være et tal');
                    return OBVIUS_OK;
                }
            } else {
                $output->param('error' => 'Du skal angive et Y-koordinat');
                return OBVIUS_OK;
            }

            unless($this->update_udsaetning($obvius, $udsaetning, $data)) {
                $output->param('error' => 'Der opstod en databasefejl ved redigering af udsætningen');
                return OBVIUS_OK;
            }
        } else {
            my $udsaetninger = $this->get_udsaetninger($obvius, {'id' => $udsaetning});
            if($udsaetninger->[0]) {
                $output->param('udsaetning' => $udsaetninger->[0]);
            } else {
                $output->param('go' => 1);
                $output->param('error' => 'Kunne ikke finde den angivne udsætning');
            }
        }
    } elsif($input->param('udsaetning_delete')) {
        my $u = $input->param('u');
        return OBVIUS_OK unless($u and $u =~ /^\d+$/);

        $output->param('mode' => 'udsaetning_delete');

        if($input->param('confirm')) {
            $this->delete_udsaetninger($obvius, { 'id' => $u });
            $output->param('deleted' => 1);
        } else {
            my $udsaetninger = $this->get_udsaetninger($obvius, {'id' => $u});
            if($udsaetninger->[0]) {
                $output->param('udsaetning' => $udsaetninger->[0]);
            } else {
                # Skip it all
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

        if(my $ikon = $input->param('ikon')) {
            $data->{ikon} = $ikon;
        } else {
            $output->param('error' => 'Du skal angive et ikon til egenskaben');
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

            if(my $ikon = $input->param('ikon')) {
                $data->{ikon} = $ikon;
            } else {
                $output->param('error' => 'Du skal angive et ikon til egenskaben');
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
    #            Produkter             #
    ####################################

    elsif($input->param('produkter')) {
        $output->param('mode' => 'produkter');
        $output->param('produkter' => $this->get_produkter($obvius));
    } elsif($input->param('produkt_new')) {

        $output->param('mode' => 'produkt_new');

        my $data = {};

        if(my $navn = $input->param('navn')) {
            $data->{navn} = $navn;
        } else {
            $output->param('error' => 'Du skal angive et navn på produktet');
            return OBVIUS_OK;
        }

        if(my $ikon = $input->param('ikon')) {
            $data->{ikon} = $ikon;
        } else {
            $output->param('error' => 'Du skal angive et ikon til produktet');
            return OBVIUS_OK;
        }
        unless($this->insert_produkt($obvius, $data)) {
            $output->param('error' => 'Der opstod en databasefejl under oprettelse af produktet');
        }
    } elsif(my $p = $input->param('produkt')) {

        return OBVIUS_OK unless($p and $p =~ /^\d+$/);

        $output->param('mode' => 'produkt_edit');

        if($input->param('go')) {
            $output->param('go' => 1);

            my $data = {};

            if(my $navn = $input->param('navn')) {
                $data->{navn} = $navn;
            } else {
                $output->param('error' => 'Du skal angive et navn på produktet');
                return OBVIUS_OK;
            }

            if(my $ikon = $input->param('ikon')) {
                $data->{ikon} = $ikon;
            } else {
                $output->param('error' => 'Du skal angive et ikon til produktet');
                return OBVIUS_OK;
            }

            unless($this->update_produkt($obvius, $p, $data)) {
                $output->param('error' => 'Der opstod en databasefejl under redigering af produktet');
            }
        } else {
            my $produkter = $this->get_produkter($obvius, {id => $p});
            if($produkter->[0]) {
                $output->param(produkt => $produkter->[0]);
            } else {
                $output->param('mode' => '');
            }
        }
    } elsif($input->param('produkt_delete')) {
        my $p = $input->param('p');

        return OBVIUS_OK unless($p and $p =~ /^\d+$/);

        $output->param('mode' => 'produkt_delete');

        if($input->param('confirm')) {
            my $godkendelser = $this->get_godkendelser($obvius, {produkt => $p}) || [];
            if(scalar(@$godkendelser)) {
                $output->param('constraints' => $godkendelser);
            } else {
                $this->delete_produkt($obvius, $p);
            }
            $output->param('deleted' => 1);
        } else {
            my $produkter = $this->get_produkter($obvius, {'id' => $p});
            if($produkter->[0]) {
                $output->param('produkt' => $produkter->[0]);
            } else {
                $output->param('mode' => '');
            }
        }

    } else {
        $output->param('godkendelser' => $this->get_godkendelser($obvius));
    }

    return OBVIUS_OK;
}













#############################################################
#                                                           #
#                       Godkendelser                        #
#                                                           #
#############################################################

sub get_godkendelser {
    my ($this, $obvius, $searchexpression, $order) = @_;

    $order ||= 'godkendelsesnr';

    my $set=DBIx::Recordset->SetupObject( {
                                            '!DataSource'   => $obvius->{DB},
                                            '!Table'        => 'fsu_godkendelser, fsu_produkter',
                                            '!TabRelation'  => 'fsu_godkendelser.produkt = fsu_produkter.id',
                                            '!Fields'       => 'fsu_godkendelser.*, fsu_produkter.navn as produktnavn',
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
                                            '!Table'        => 'fsu_godkendelser',
                                            '!Serial'       => 'id'
                                        } );
    my $retval = $set->Insert($godkendelse);
    $set->Disconnect;

    return $retval ? $set->LastSerial : undef;
}

sub update_godkendelse {
    my ($this, $obvius, $godkendelse, $data) = @_;

    my $set=DBIx::Recordset->SetupObject( {
                                            '!DataSource'   => $obvius->{DB},
                                            '!Table'        => 'fsu_godkendelser',
                                        } );
    my $retval = $set->Update($data, { 'id' => $godkendelse });
    $set->Disconnect;

    return $retval;
}

sub delete_godkendelse {
    my ($this, $obvius, $godkendelse) = @_;

    # First delete relations
    $this->delete_godkendelse_egenskaber($obvius, {'godkendelse' => $godkendelse});
    $this->delete_udsaetninger($obvius, {'godkendelse' => $godkendelse});

    # Delete self
    my $set=DBIx::Recordset->SetupObject( {
                                            '!DataSource'   => $obvius->{DB},
                                            '!Table'        => 'fsu_godkendelser',
                                        } );
    my $retval = $set->Delete({ 'id' => $godkendelse });
    $set->Disconnect;

    return $retval;
}


#############################################################
#                                                           #
#                       Udsætninger                         #
#                                                           #
#############################################################

sub get_udsaetninger {
    my ($this, $obvius, $searchexpression, $order) = @_;

    $order ||= 'navn';

    my $set=DBIx::Recordset->SetupObject( {
                                            '!DataSource'   => $obvius->{DB},
                                            '!Table'        => 'fsu_udsaetninger',
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

sub insert_udsaetning {
    my ($this, $obvius, $udsaetning) = @_;

    my $set=DBIx::Recordset->SetupObject( {
                                            '!DataSource'   => $obvius->{DB},
                                            '!Table'        => 'fsu_udsaetninger',
                                            '!Serial'       => 'id'
                                        } );
    my $retval = $set->Insert($udsaetning);
    $set->Disconnect;

    return $retval ? $set->LastSerial : undef;
}

sub update_udsaetning {
    my ($this, $obvius, $udsaetning, $data) = @_;

    my $set=DBIx::Recordset->SetupObject( {
                                            '!DataSource'   => $obvius->{DB},
                                            '!Table'        => 'fsu_udsaetninger',
                                        } );
    my $retval = $set->Update($data, { 'id' => $udsaetning });
    $set->Disconnect;

    return $retval;
}

sub delete_udsaetninger {
    my ($this, $obvius, $where) = @_;

    return 0 unless($where);

    # Delete self
    my $set=DBIx::Recordset->SetupObject( {
                                            '!DataSource'   => $obvius->{DB},
                                            '!Table'        => 'fsu_udsaetninger',
                                        } );
    my $retval = $set->Delete($where);
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
                                            '!Table'        => 'fsu_egenskaber',
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
                                            '!Table'        => 'fsu_egenskaber',
                                        } );
    my $retval = $set->Update($data, { 'id' => $egenskab });
    $set->Disconnect;

    return $retval;
}

sub insert_egenskab {
    my ($this, $obvius, $data) = @_;

    my $set=DBIx::Recordset->SetupObject( {
                                            '!DataSource'   => $obvius->{DB},
                                            '!Table'        => 'fsu_egenskaber',
                                            '!Serial'       => 'id'
                                        } );
    my $retval = $set->Insert($data);
    $set->Disconnect;

    return $retval ? $set->LastSerial : undef;

}

sub delete_egenskab {
    my ($this, $obvius, $egenskab_id) = @_;

    # First delete relations
    $this->delete_godkendelse_egenskaber($obvius, {'egenskab' => $egenskab_id});

    # Delete self
    my $set=DBIx::Recordset->SetupObject( {
                                            '!DataSource'   => $obvius->{DB},
                                            '!Table'        => 'fsu_egenskaber',
                                        } );
    my $retval = $set->Delete({ 'id' => $egenskab_id });
    $set->Disconnect;

    return $retval;
}

#############################################################
#                                                           #
#             Godkendelse/egenskab realtioner               #
#                                                           #
#############################################################

sub get_godkendelse_egenskaber {
    my ($this, $obvius, $searchexpression, %options) = @_;

    my $tables = 'fsu_godkendelse_egenskaber';
    my $tabrelation = '';
    my $order;

    if($options{get_navn}) {
        $tables .= ', fsu_egenskaber';
        $tabrelation .= 'fsu_godkendelse_egenskaber.egenskab = fsu_egenskaber.id';
        $order = 'fsu_egenskaber.navn';
    }

    my $set=DBIx::Recordset->SetupObject( {
                                            '!DataSource'   => $obvius->{DB},
                                            '!Table'        => $tables,
                                            '!TabRelation'  => $tabrelation,
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

sub insert_godkendelse_egenskaber {
    my ($this, $obvius, $godkendelse, $egenskaber) = @_;

    $egenskaber ||= [];

    my $set=DBIx::Recordset->SetupObject( {
                                            '!DataSource'   => $obvius->{DB},
                                            '!Table'        => 'fsu_godkendelse_egenskaber',
                                        } );
    for(@$egenskaber) {
        $set->Insert({ godkendelse => $godkendelse, egenskab => $_ });
    }
}

sub delete_godkendelse_egenskaber {
    my ($this, $obvius, $where) = @_;

    my $set=DBIx::Recordset->SetupObject( {
                                            '!DataSource'   => $obvius->{DB},
                                            '!Table'        => 'fsu_godkendelse_egenskaber',
                                        } );
    my $retval = $set->Delete($where);
    $set->Disconnect;

    return $retval;
}


#############################################################
#                                                           #
#                        Produkter                          #
#                                                           #
#############################################################


sub get_produkter {
    my ($this, $obvius, $searchexpression) = @_;

    my $set=DBIx::Recordset->SetupObject( {
                                            '!DataSource'   => $obvius->{DB},
                                            '!Table'        => 'fsu_produkter',
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

sub update_produkt {
    my ($this, $obvius, $produkt, $data) = @_;

    my $set=DBIx::Recordset->SetupObject( {
                                            '!DataSource'   => $obvius->{DB},
                                            '!Table'        => 'fsu_produkter',
                                        } );
    my $retval = $set->Update($data, { 'id' => $produkt });
    $set->Disconnect;

    return $retval;
}

sub insert_produkt {
    my ($this, $obvius, $data) = @_;

    my $set=DBIx::Recordset->SetupObject( {
                                            '!DataSource'   => $obvius->{DB},
                                            '!Table'        => 'fsu_produkter',
                                            '!Serial'       => 'id'
                                        } );
    my $retval = $set->Insert($data);
    $set->Disconnect;

    return $retval ? $set->LastSerial : undef;

}

sub delete_produkt {
    my ($this, $obvius, $produkt_id) = @_;

    # Delete self
    my $set=DBIx::Recordset->SetupObject( {
                                            '!DataSource'   => $obvius->{DB},
                                            '!Table'        => 'fsu_produkter',
                                        } );
    my $retval = $set->Delete({ 'id' => $produkt_id });
    $set->Disconnect;

    return $retval;
}


1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Obvius::DocType::ForsoegsSearch - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Obvius::DocType::ForsoegsSearch;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Obvius::DocType::ForsoegsSearch, created by h2xs. It looks like the
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
