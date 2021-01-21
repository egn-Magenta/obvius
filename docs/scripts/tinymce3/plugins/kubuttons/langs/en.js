tinyMCE.addI18n('en.kubuttons',{
    citat_desc : 'Format as quote',
    tiltop_desc : "Insert 'Back to top' link"
});

if(tinymce.settings['restrict_advlink_features']) {
    /* Hack for displaying smaller dialog for advanced image dialog */
    tinymce.addI18n('en.advlink', { delta_height: -200 });
}
