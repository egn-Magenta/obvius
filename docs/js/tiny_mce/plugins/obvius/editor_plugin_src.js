/* Import plugin specific language pack */
tinyMCE.importPluginLanguagePack('obvius', 'en,da');

function TinyMCE_obvius_getControlHTML(control_name) {
    switch (control_name) {
        case "w3ccheck":
            return '<img id="{$editor_id}_w3ccheck" src="{$pluginurl}/images/w3c.gif" title="{$lang_w3ccheck_desc}" width="20" height="20" class="mceButtonNormal" onmouseover="tinyMCE.switchClass(this,\'mceButtonOver\');" onmouseout="tinyMCE.restoreClass(this);" onmousedown="tinyMCE.restoreAndSwitchClass(this,\'mceButtonDown\');" onclick="tinyMCE.execInstanceCommand(\'{$editor_id}\',\'mceW3cCheck\');" />';
    }
    return "";
}

/**
 * Executes the mceAdvanceHr command.
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
                window.open('/admin/?obvius_op=check_editor_xhtml&fieldname=' + instance.formElement.name);
            }
       return true;
   }
   // Pass to next handler in chain
   return false;
}

function TinyMCE_obvius_handleNodeChange(editor_id, node, undo_index, undo_levels, visual_aid, any_selection) {
    // Does nothing yet
    return true;
}
