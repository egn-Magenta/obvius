// Functions for integrating TinyMCE in Obvius

var obvius_tinymce_editor_baserefs = new Object;

function obvius_tinymce_get_dialogfield(field_name) {
    // First try to find the form element we need to put the found filename in:
    var field_ref = null;
    if(window.tinymce_dialogrefs) {
        for(var i in window.tinymce_dialogrefs) {
            var dialog = window.tinymce_dialogrefs[i];
            if(dialog.document && dialog.document.forms) {
                for(var j=0;j<dialog.document.forms.length;j++) {
                    var form = dialog.document.forms[j];
                    if(form[field_name]) {
                        field_ref = form[field_name];
                        break;
                    }
                }

                if(field_ref) {
                    break;
                }
            }
        }
    }

    return field_ref;
}
function obvius_tinymce_navigator_callback(field_name, url, type) {

    var start_url = tinyMCE.getParam('document_base_url');

    // Make URL relative to /
    start_url = start_url.replace(/^https?:\/\/[^\/]+/, "");

    if(url && url.charAt(0) == '/') {
        start_url = url;
        // Remove query string:
        start_url = start_url.replace(/\?.*$/, "");
        // Add last /:
        if(! url.match(/\/$/)) {
            start_url += "/";
        }
    }

    var doctype_extra = '';
    if(type == 'image') {
        doctype_extra = "&doctype=Image";
    }

    var nav_features = ('toolbar=0,location=0,directories=0,status=0,'
        +'menubar=0,scrollbars=1,resizable=1,copyhistory=0,'
        +'width=750,height=550');


    window.open('/admin/?obvius_op=navigator' + doctype_extra + '&fieldname=' + field_name + '&path=' + start_url, '', nav_features); return false;

}
