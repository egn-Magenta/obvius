/* Import plugin specific language pack */
tinyMCE.importPluginLanguagePack('obvius', 'en,da');

function TinyMCE_obvius_getControlHTML(control_name) {
    switch (control_name) {
        case "w3ccheck":
            return '<img id="{$editor_id}_w3ccheck" src="{$pluginurl}/images/briller.gif" title="{$lang_w3ccheck_desc}" width="20" height="20" class="mceButtonNormal" onmouseover="tinyMCE.switchClass(this,\'mceButtonOver\');" onmouseout="tinyMCE.restoreClass(this);" onmousedown="tinyMCE.restoreAndSwitchClass(this,\'mceButtonDown\');" onclick="tinyMCE.execInstanceCommand(\'{$editor_id}\',\'mceW3cCheck\');" />';
        case "pasteastext":
            if(tinyMCE.isMSIE) {
                return '<img id="{$editor_id}_pasteastext" src="{$pluginurl}/images/pastetext.gif" title="{$lang_pasteastext_desc}" width="20" height="20" class="mceButtonNormal" onmouseover="tinyMCE.switchClass(this,\'mceButtonOver\');" onmouseout="tinyMCE.restoreClass(this);" onmousedown="tinyMCE.restoreAndSwitchClass(this,\'mceButtonDown\');" onclick="tinyMCE.execInstanceCommand(\'{$editor_id}\',\'mcePasteAsText\');" />';
            } else {
                return "";
            }
        case "pastefromword":
            if(tinyMCE.isMSIE) {
                return '<img id="{$editor_id}_pastefromword" src="{$pluginurl}/images/pasteword.gif" title="{$lang_pastefromword_desc}" width="20" height="20" class="mceButtonNormal" onmouseover="tinyMCE.switchClass(this,\'mceButtonOver\');" onmouseout="tinyMCE.restoreClass(this);" onmousedown="tinyMCE.restoreAndSwitchClass(this,\'mceButtonDown\');" onclick="tinyMCE.execInstanceCommand(\'{$editor_id}\',\'mcePasteFromWord\');" />';
            } else {
                return "";
            }
        case "addtoplink":
            if(window.obvius_addtoplink_src) {
                return '<img id="{$editor_id}_addtoplink" src="{$pluginurl}/images/addtoplink.gif" title="{$lang_addtoplink_desc}" width="20" height="20" class="mceButtonNormal" onmouseover="tinyMCE.switchClass(this,\'mceButtonOver\');" onmouseout="tinyMCE.restoreClass(this);" onmousedown="tinyMCE.restoreAndSwitchClass(this,\'mceButtonDown\');" onclick="tinyMCE.execInstanceCommand(\'{$editor_id}\',\'mceAddTopLink\');" />';
            }
    }
    return "";
}

/**
 * Executes the mceW3cCheck command.
 */
function TinyMCE_obvius_execCommand(editor_id, element, command, user_interface, value) {
    // Handle commands
    switch (command) {
        case "mceW3cCheck":
            // Trigger save:
            tinyMCE.triggerSave();
            // And open the validator window:
            var instance = tinyMCE.getInstanceById(editor_id);
            if(instance) {
                if (tinyMCE.settings['obvius_w3c_check_via_xmlhttprequest']) {
                  obvius_tinymce_plugin_w3c_validate_html(instance.formElement);
                }
                else {
                    window.open('/admin/?obvius_op=check_editor_xhtml&fieldname=' + instance.formElement.name);
                }
            }
            return true;
        case "mcePasteAsText":
            var instance = tinyMCE.getInstanceById(editor_id);
            if(instance) {
                instance.execCommand("mceAddUndoLevel");
                // Get text data from clipboard and clean it so it makes nice HTML:
                var html = obvius_tinymce_get_clipboard_text();
                html = html.replace(/\r/g, "");
                html = html.replace(/\n/g, "<br>\n");

                var sel = instance.getDoc().selection;
                var rng = sel.createRange();
                rng.pasteHTML(html);
            }
            return true;
        case "mcePasteFromWord":
            var instance = tinyMCE.getInstanceById(editor_id);
            if(instance) {
                instance.execCommand("mceAddUndoLevel");

                var html = obvius_tinymce_get_clipboard_html();

                // This assumes tiny_mce_obvius.js have been loaded:
                var cleanhtml = obvius_tinymce_html_cleanup("insert_to_editor", html);

                var sel = instance.getDoc().selection;
                var rng = sel.createRange();
                rng.pasteHTML(cleanhtml);

            }
            return true;
        case "mceAddTopLink":
            var instance = tinyMCE.getInstanceById(editor_id);
            if(instance) {
                instance.execCommand("mceAddUndoLevel");
                instance.execCommand("mceInsertContent", null, "<a href=\"#top\" title=\"Til toppen\" style=\"float: right;\"><img src=\"" + window.obvius_addtoplink_src + "\" alt=\"Til toppen\" /></a>");
            }
            return true;

   }
   // Pass to next handler in chain
   return false;
}

function obvius_tinymce_plugin_w3c_validate_html(formelt) {
  obvius_validator_validate(formelt.value);
}

function TinyMCE_obvius_handleNodeChange(editor_id, node, undo_index, undo_levels, visual_aid, any_selection) {
    // Does nothing yet
    return true;
}


/*
    Helper function to get the data from the clipboard.
    MSIE only for now.
*/
function obvius_tinymce_get_clipboard_html() {

    var doc = document; // Hmmm, seems to be ok to use the global document here

    htmlDiv = doc.createElement('div');
    htmlDiv.style.visibility = 'hidden';
    htmlDiv.style.overflow = 'hidden';
    htmlDiv.style.width = 1;
    htmlDiv.style.height = 1;
    htmlDiv.id = '____tmpHTMLPastediv';
    htmlDiv.innerHTML = "____tmpHTMLPasteContent";

    doc.body.appendChild(htmlDiv);

    var rng = doc.body.createTextRange();
    rng.findText('____tmpHTMLPasteContent', 0, 6);
    rng.execCommand('Paste');
    var html = htmlDiv.innerHTML;
    doc.body.removeChild(htmlDiv);

    return html;

}

function obvius_tinymce_get_clipboard_text(editor_id) {

    var doc = document; // Hmmm, seems to be ok to use the global document here

    htmlDiv = doc.createElement('div');
    htmlDiv.style.visibility = 'hidden';
    htmlDiv.style.overflow = 'hidden';
    htmlDiv.style.width = 1;
    htmlDiv.style.height = 1;
    htmlDiv.id = '____tmpHTMLPastediv';
    htmlDiv.innerHTML = "____tmpHTMLPasteContent";

    doc.body.appendChild(htmlDiv);

    var rng = doc.body.createTextRange();
    rng.findText('____tmpHTMLPasteContent', 0, 6);
    rng.execCommand('Paste');

    rng.moveToElementText(htmlDiv);
    var data = rng.text;
    doc.body.removeChild(htmlDiv);

    return data;

}