var ae = unescape('%E6');

tinyMCE.addI18n('da.kubuttons',{
    citat_desc : 'Inds'+ae+'t citat',
    tiltop_desc : 'Inds'+ae+"t 'Til top' link"
});

var clipboard_messages = {
    clipboard_msg: "Kopier/Klip/inds\u00E6t via knapper er ikke muligt i Mozilla eller Firefox. Brug tastaturgenveje i stedet: For kopier tryk control-c og for inds\u00E6t tryk control-v.\nKlik OK for at l\u00E6se om hvorfor det ikke muligt at bruge knapperne.",
    clipboard_no_support: "P\u00E5 nuv\u00E6rende tidspunkt ikke supporteret af din browser. For kopier tryk control-c og for inds\u00E6t tryk control-v."
}

tinyMCE.addI18n('da', clipboard_messages);
tinyMCE.addI18n('da.advanced', clipboard_messages);

if(tinymce.settings['restrict_advlink_features']) {
    /* Hack for displaying smaller dialog for advanced image dialog */
    tinymce.addI18n('da.advlink', { delta_height: -200 });
}
