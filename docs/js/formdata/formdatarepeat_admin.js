// $Id$
// Global variables used

var rootDocs = new Object();

var formdata_field_dialog_width = 620;
var formdata_field_dialog_height = 560;

var formdata_option_dialog_width = 350;
var formdata_option_dialog_height = 180;

var formdata_valrule_dialog_width = 400;
var formdata_valrule_dialog_height = 250;

/* variables for repeatable use */
var obvius_rep_field_names = [ ];
var obvius_rep_field_displays = [ ];
var obvius_field_name_marker = {};
var obvius_rep_area_count = 0;

var formdata_admin_url = document.location.href.match(/https/) ?
	                 './' :
			 '/admin/';

function formdata_init(elem) {
    // Unhide the advanced editing controls:
    var edit_elem = document.getElementById("obvius_" + formdata_extract_name(elem.name) + "_advanced_editing");
    edit_elem.style.display = 'block';

    // Setup data:
    formdata_load_rootDoc_data(elem);

    // Populate fields table and repeatable area
    formdata_populate_fieldtable(elem.name, true);
}

function formdata_save(elem) {
    var rootDoc = formdata_get_rootDoc_by_name(elem.name);

    //Delete reppeatables if any leftover
    if ( rootDoc ) {
	var repeatselem = rootDoc.getElementsByTagName('repeatables');
	if ( repeatselem && repeatselem.getLength() > 0 ) {
            rootDoc.removeChild(repeatselem.item(0)); //Remove it now - inserted again when finished
	}
    }

    //Insert repeatables in rootDoc
    merge_rootDoc_repeatables(rootDoc);

    //Extract XML text
    var xml = rootDoc.getXML();
    xml = xml.replace(/<\/([^>]+)></g, "</$1>\n<");

    //Set form-emlement value to xml-text
    elem.value = xml;
    return true;
}

function formdata_populate_fieldtable(name, startup) {

    rootDoc = formdata_get_rootDoc_by_name(name);

    if(! rootDoc)
        return false;

    var table = document.getElementById('obvius_' + formdata_extract_name(name) + '_displaylist');

    if(! table)
        return false;

    // Cleanup existing table
    var table_children = table.getElementsByTagName('tr');
    for(var i=table_children.length;i>1;i--) {
        var child = table_children[i-1];
        child.parentNode.removeChild(child);
    }

    var fields = rootDoc.getElementsByTagName('field');

    //Reset repeatables info
    obvius_rep_field_names = [];
    obvius_rep_field_displays = [];
    obvius_field_name_marker = {};

    if(fields) {
        for(var i=0;i < fields.getLength();i++) {
            var item = fields.item(i);
            var obj = formdata_objectify_node(item);

	    //Update array of fields for repeatables
	    if ( obj.type != 'fieldset' && obj.type != 'fieldset_end' && 
		 obj.type != 'upload' && obj.type != 'password' &&
		 obj.type != 'selectmultiple' && obj.type != 'checkbox') { 
		obvius_rep_field_names.push(obj.name);
		obvius_rep_field_displays.push(obj.title);
	    }
            
	    // Generate a <tr> for the field:

            var tr = document.createElement('tr');

            var title_td = document.createElement('td');
            title_td.innerHTML = obj.title;
            tr.appendChild(title_td);

            var type_td = document.createElement('td');
            var translated_type = formdata_translations['field_type_' + obj.type] || 'Unknown fieldtype';
            type_td.innerHTML = translated_type;
            tr.appendChild(type_td);

            var man_td = document.createElement('td');

            var man_value = obj.mandatory || '';

            if(man_value == '' || man_value == 0) {
                man_td.innerHTML = formdata_translations['No'];
            } else if(man_value == 1) {
                man_td.innerHTML = formdata_translations['Yes'];
            } else if(man_value.match(/^!(.+)/)) {
                man_td.innerHTML = formdata_translations['mandatory_yes_if'] + ' ' + man_value.match(/^!(.+)/)[1] + ' ' + formdata_translations['mandatory_yes_if_has_not'];
            } else if(man_value.match(/^(.+)$/)) {
                man_td.innerHTML = formdata_translations['mandatory_yes_if'] + ' ' + man_value.match(/^(.+)$/)[1] + ' ' + formdata_translations['mandatory_yes_if_has'];
            }
            tr.appendChild(man_td);

            var unique_td = document.createElement('td');
            var unique_value = obj.unique || '';

            if(unique_value == 1) {
                unique_td.innerHTML = formdata_translations['Yes'];
            } else {
                unique_td.innerHTML = formdata_translations['No'];
            }

            tr.appendChild(unique_td);

            var edit_td = document.createElement('td');
            var edit_a = document.createElement('a');
            edit_a.href = document.location.href;

            // Hmmm, have to wrap this in eval to avoid problems with global variables
            var edit_url = formdata_admin_url + "?obvius_app_formdatarepeat=1&mode=edit&field=" + obj.name + "&fieldname=" + name;
            var window_options = "menubar=no,toolbar=no,scrollbars=yes,width=" + formdata_field_dialog_width + ",height=" + formdata_field_dialog_height;
            eval("edit_a.onclick = function () { window.open('" + edit_url + "', 'formdata_edit', '" + window_options + "'); return false; }");
            edit_a.innerHTML = formdata_translations['Edit'];
            edit_td.appendChild(edit_a);
            tr.appendChild(edit_td);

            var del_td = document.createElement('td');
            var del_a = document.createElement('a');
            del_a.href = document.location.href;
            eval("del_a.onclick = function () {formdata_delete_field('" + name + "', '" + obj.name + "'); return false; }");
            del_a.innerHTML = formdata_translations['Delete'];
            del_td.appendChild(del_a);
            tr.appendChild(del_td);

            var updown_td = document.createElement('td');
            updown_td.align="center";
            var up_a = document.createElement('a');
            up_a.href = document.location.href;
            eval("up_a.onclick = function() {formdata_move_field('" + name + "', " + i + ", 'up'); return false;}");
            up_a.innerHTML = formdata_translations['Up'];
            var down_a = document.createElement('a');
            down_a.href = document.location.href;
            eval("down_a.onclick = function() {formdata_move_field('" + name + "', " + i + ", 'down'); return false;}");
            down_a.innerHTML = formdata_translations['Down'];

            updown_td.appendChild(up_a);
            updown_td.appendChild(document.createTextNode(" / "));
            updown_td.appendChild(down_a);
            tr.appendChild(updown_td);

            var tbodies = table.getElementsByTagName('tbody');
            if(tbodies[0]) {
                tbodies[0].appendChild(tr);
            } else {
                table.appendChild(tr);
            }
        }
    }
    formdata_populate_sortorder_field(name, rootDoc);
    
    /* Repetables */
    for ( var markIdx = 0; markIdx < obvius_rep_field_names.length; markIdx++ ) {
	var cur = obvius_rep_field_names[markIdx];
	obvius_field_name_marker[cur] = obvius_rep_field_displays[markIdx];
    }
    if ( startup ) {
	//Make HTML structure from existing repeatables
	var repeatselem = rootDoc.getElementsByTagName('repeatables');
	if( repeatselem && repeatselem.getLength() > 0 ) {
	    var repeats = repeatselem.item(0).getElementsByTagName('repeatable');
	    for(var i=0;i < repeats.getLength();i++) {
		var item = repeats.item(i);
		var obj = formdata_objectify_repeat_node(item);
		insert_repeat_area(obj);
	    }
	}
    } else {
        //Reflect field change on existing repeatables
	reflectFields_on_repeatables();
    }
}

function formdata_populate_sortorder_field(name, rootDoc) {
    if(!$)
        return false;
    var select = $.grep($(document.pageform).find("select").get(), function(elem) {
        return elem.name.match(/infored_sortorder$/);
    })[0];

    if(select) {
        if(!rootDoc)
            rootDoc = formdata_get_rootDoc_by_name(name);
    
        if(!rootDoc)
            return false;

        var sj = $(select);
        var chosen = sj.val();
        while(select.options.length > 1)
            select.options[select.options.length - 1] = null;

        var fields = rootDoc.getElementsByTagName('field');
        for(var i=0;i < fields.getLength();i++) {
            var item = fields.item(i);
            var obj = formdata_objectify_node(item);
            sj.append($('<option>').val(obj.name).text(obj.title));
            sj.append($('<option>').val(obj.name + "_reverse").text(obj.title + " (Omvendt)"));
        }
        sj.val(chosen);
    }
}


function formdata_delete_field(formfield_name, fieldname) {
    if(! confirm(formdata_translations['really_delete'] + " '" + fieldname + "'?")) {
        return false;
    }

    var rootDoc = formdata_get_rootDoc_by_name(formfield_name);

    var names = rootDoc.getElementsByTagName('name');

    for(var i=0;i < names.getLength();i++) {
        if(formdata_get_node_text(names.item(i)) == fieldname) {
            var removeNode = names.item(i).parentNode;

            removeNode.parentNode.removeChild(removeNode);
            break;
        }
    }

    formdata_populate_fieldtable(formfield_name, false);
    document.pageform[formfield_name].value = rootDoc.getXML();
}

function formdata_add_new(elem) {
    var type_elem = document.pageform["obvius_" + formdata_extract_name(elem.name) + "_new_field_type"];
    if(! type_elem) {
        alert(formdata_translations['cant_find_type']);
        return false;
    }

    var type_value = type_elem.options[type_elem.selectedIndex].value;

    if(! type_value) {
        alert(formdata_translations['must_chose_type']);
        return false;
    }

    window.open(formdata_admin_url + "?obvius_app_formdatarepeat&mode=edit&new=" + type_value + "&fieldname=" + elem.name, "formdata_edit", "menubar=no,toolbar=no,scrollbars=yes,width=" + formdata_field_dialog_width + ",height=" + formdata_field_dialog_height);
}


// Field edit dialog related functions

function formdata_init_field_edit(form_fieldname, is_new, fieldname) {
    // Lookup rootDoc from opener window:
    var rootDoc;
    if(window.opener.formdata_get_rootDoc_by_name) {
        rootDoc = window.opener.formdata_get_rootDoc_by_name(form_fieldname);
    } else {
        alert(formdata_translations['parent_connection_lost']);
        return false;
    }

    // Get names for mandatory-if dropdown:

    var name_dropdown = document.pageform.mandatory_fields;

    name_dropdown.options[name_dropdown.options.length] = new Option("", "");

    var name_elems = rootDoc.getElementsByTagName('name');
    for(var i=0;i<name_elems.getLength();i++) {
        name = formdata_get_node_text(name_elems.item(i));

        name_dropdown.options[name_dropdown.options.length] = new Option(name, name);
    }

    if(is_new) {
        // Make a XML node with default values

        var tmpXML = "";
        tmpXML += "<root>";
        tmpXML += " <field>";
        tmpXML += "     <name></name>";
        tmpXML += "     <title></title>";
        tmpXML += "     <type>" + is_new + "</type>";
        tmpXML += "     <mandatory>0</mandatory>";
        tmpXML += "     <unique>0</unique>";
        tmpXML += "     <imagepath></imagepath>";
        tmpXML += "     <description></description>";
        tmpXML += "     <colindex>0</colindex>";
        tmpXML += "     <listpublic></listpublic>";
        tmpXML += "     <validaterules>";
        tmpXML += "     </validaterules>";
        tmpXML += "     <options>";
        tmpXML += "     </options>";
        tmpXML += " </field>";
        tmpXML += "</root>";

        var parser = new DOMImplementation();
        var tmpDomDoc = parser.loadXML(tmpXML);

        var tmpRootDoc = tmpDomDoc.getDocumentElement();

        fieldNode = tmpRootDoc.getElementsByTagName('field').item(0);
    } else {
        var names = rootDoc.getElementsByTagName('name');

        for(var i=0;i < names.getLength();i++) {
            if(formdata_get_node_text(names.item(i)) == fieldname) {
                // Need to clone here since we might have to replace it later
                fieldNode = names.item(i).parentNode.cloneNode(true);
		break;
            }
        }
    }

    var fieldObj = formdata_objectify_node(fieldNode);

    document.pageform.title.value = fieldObj.title || "";
    document.pageform.name.value = fieldObj.name || "";
    document.pageform.description.value = fieldObj.description || "";
    document.pageform.colindex.value = fieldObj.colindex || "0";
    document.pageform.listpublic.value = fieldObj.listpublic || "";
    document.pageform.imagepath.value = fieldObj.imagepath || "";

    document.getElementById('type_field').innerHTML = formdata_translations['field_type_' + fieldObj.type] || 'unknown fieldtype';


    var type = fieldObj.type || '';

    //Listpublic is almost certainly not displayed
    if (type == 'radio') {
	document.getElementById('listpublic').style.display = '';
    } else {
	document.pageform.listpublic.value = "";
	document.getElementById('listpublic').style.display = 'none';
    }

    if(type == 'text' || type == 'password' || type == 'textarea' || type == 'protected') {
        // Hide options and validaterules:
        document.getElementById('options').style.display = 'none';
    }

    if (type == 'email' ) {
        document.getElementById('options').style.display = 'none';
        document.getElementById('validaterules').style.display = 'none';
        document.getElementById('image').style.display = 'none';
        document.getElementById('description').style.display = 'none';
    }
    if(type == 'fieldset' || type == 'fieldset_end') {
        // Only edit name on title on fieldset:
        document.getElementById('options').style.display = 'none';
        document.getElementById('validaterules').style.display = 'none';
        document.getElementById('mandatory').style.display = 'none';
        document.getElementById('image').style.display = 'none';
        document.getElementById('description').style.display = 'none';
        document.getElementById('unique').style.display = 'none';
	document.getElementById('colindex').style.display = 'none';
    }

    if(type == 'upload') {
      document.getElementById('options').style.display = 'none';
      document.getElementById('validaterules').style.display = 'none';
      document.getElementById('image').style.display = 'none';
      document.getElementById('unique').style.display = 'none';
    }

    if (type == 'name' ) {
      document.getElementById('options').style.display = 'none';
      document.getElementById('maxlength').style.display = '';
      document.getElementById('size').style.display = '';
    }

    if(type == 'text' || type == 'password' || type == 'protected') {
      document.getElementById('maxlength').style.display = '';
      document.getElementById('size').style.display = '';
    }

    if(type == 'textarea') {
        document.getElementById('ta_dimensions').style.display = '';
    }

    if(type == 'protected') {
        document.pageform.colindex.value = "0";
        document.getElementById('colindex').style.display = 'none';
    }

    if(fieldObj.mandatory == 0 || ! fieldObj.mandatory) {
        document.getElementById('mand_yes').checked = 0;
        document.getElementById('mand_no').checked = 1;
        document.getElementById('mand_field').checked = 0;
    } else if(fieldObj.mandatory == 1) {
        document.getElementById('mand_yes').checked = 1;
        document.getElementById('mand_no').checked = 0;
        document.getElementById('mand_field').checked = 0;
    } else {
        document.getElementById('mand_yes').checked = 0;
        document.getElementById('mand_no').checked = 0;
        document.getElementById('mand_field').checked = 1;

        var fieldname;

        if(fieldObj.mandatory.match(/^!/)) {
            document.pageform.mandatory_operator.selectedIndex = 1;
            fieldname = fieldObj.mandatory.replace(/^!/, "");
        } else {
            document.pageform.mandatory_operator.selectedIndex = 0;
            fieldname = fieldObj.mandatory;
        }

        var name_dropdown = document.pageform.mandatory_fields;

        var field_ok = false;
        for(var i=0;i<name_dropdown.options.length;i++) {
            if(name_dropdown.options[i].value == fieldname) {
                name_dropdown.selectedIndex = i;
                field_ok = true;
                break;
            }
        }

        // If the name wasn't already in the dropdown, create it there:
        if(! field_ok) {
            name_dropdown.options[name_dropdown.options.length] = new Option(fieldname, fieldname);
            name_dropdown.selectedIndex = name_dropdown.options.length - 1;
        }
    }

    if(fieldObj.unique == 1) {
        document.getElementById('unique_yes').checked = 1;
        document.getElementById('unique_no').checked = 0;
    } else {
        document.getElementById('unique_yes').checked = 0;
        document.getElementById('unique_no').checked = 1;
    }

    // Populate params:
    var paramsNode = fieldNode.getElementsByTagName('params').item(0);
    if(paramsNode) {
        var params = formdata_objectify_node(paramsNode);

        var form = document.pageform;
        for(var i=0;i<form.length;i++) {
            var formElem = form[i];
            if(formElem.name.match(/^param_/)) {
                formElem.value = params[formElem.name] || "";
            }
        }
    }


    formdata_populate_validaterules(fieldNode);
    formdata_populate_options(fieldNode);

}

function formdata_populate_validaterules(fieldNode) {
    var fieldType = '';
    var fieldTypeNode = fieldNode.getElementsByTagName('type').item(0);
    if(fieldTypeNode) {
        fieldType = formdata_get_node_text(fieldTypeNode);
    }

    // No validation rules for radiobuttons and non-multiple selects
    if(fieldType == 'radio' || fieldType == 'select') {
        document.getElementById('validaterules').style.display = 'none';
        return;
    }
    
    
    // First get the table element and empty it:
    var table =  document.getElementById('validaterules_table');

    var table_children = table.getElementsByTagName('tr');
    for(var i=table_children.length;i>1;i--) {
        var child = table_children[i-1];
        child.parentNode.removeChild(child);
    }

    // Get validation nodes:
    var valNodes = fieldNode.getElementsByTagName('validaterule');
    for(var i = 0;i<valNodes.getLength();i++) {
        var valNode = valNodes.item(i);
        var valObj = formdata_objectify_node(valNode);

      var tr = document.createElement('tr');

        var type_td = document.createElement('td');
        type_td.innerHTML = formdata_translations['validate_type_' + valObj.validationtype] || valObj.validationtype;
        tr.appendChild(type_td);

        var arg_td = document.createElement('td');
        arg_td.innerHTML = valObj.validationargument;
        tr.appendChild(arg_td);

        var err_td = document.createElement('td');
        err_td.innerHTML = valObj.errormessage;
        tr.appendChild(err_td);

        var edit_td = document.createElement('td');
        var edit_a = document.createElement('a');
        edit_a.href = document.location.href;

	var edit_url = formdata_admin_url + "?obvius_app_formdatarepeat&mode=edit_validaterule&rulenr=" + i;
        var window_options = "menubar=no,toolbar=no,scrollbars=yes,width=" + formdata_valrule_dialog_width + ",height=" + formdata_valrule_dialog_height;
        eval("edit_a.onclick = function () { window.open('" + edit_url + "', 'formdata_edit_valrule', '" + window_options + "'); return false;}");
        edit_a.innerHTML = formdata_translations['Edit'];
        edit_td.appendChild(edit_a);
        tr.appendChild(edit_td);

        var del_td = document.createElement('td');
        var del_a = document.createElement('a');
        del_a.href = document.location.href;
        eval("del_a.onclick = function () { formdata_delete_validaterule(" + i + ");return false;}");
        del_a.innerHTML = formdata_translations['Delete'];
        del_td.appendChild(del_a);
        tr.appendChild(del_td);

        var updown_td = document.createElement('td');
        updown_td.align="center";
        var up_a = document.createElement('a');
        up_a.href = document.location.href;
        eval("up_a.onclick = function() {formdata_move_valrule(" + i + ", 'up'); return false;}");
        up_a.innerHTML = formdata_translations['Up'];
        var down_a = document.createElement('a');
        down_a.href = document.location.href;
        eval("down_a.onclick = function() {formdata_move_valrule(" + i + ", 'down'); return false;}");
        down_a.innerHTML = formdata_translations['Down'];

        updown_td.appendChild(up_a);
        updown_td.appendChild(document.createTextNode(" / "));
        updown_td.appendChild(down_a);
        tr.appendChild(updown_td);

        var tbodies = table.getElementsByTagName('tbody');
        if(tbodies[0]) {
            tbodies[0].appendChild(tr);
        } else {
            table.appendChild(tr);
        }
    }


}

function formdata_populate_options(fieldNode) {
    // First get the table element and empty it:
    var table =  document.getElementById('options_table');

    var table_children = table.getElementsByTagName('tr');
    for(var i=table_children.length;i>1;i--) {
        var child = table_children[i-1];
        child.parentNode.removeChild(child);
    }

    // Get validation nodes:
    var optNodes = fieldNode.getElementsByTagName('option');
    for(var i=0;i<optNodes.getLength();i++) {
        var optNode = optNodes.item(i);
        var optObj = formdata_objectify_node(optNode);

        var tr = document.createElement('tr')

        var title_td = document.createElement('td');
        title_td.innerHTML = optObj.optiontitle
        tr.appendChild(title_td);

        var value_td = document.createElement('td');
        value_td.innerHTML = optObj.optionvalue;
        tr.appendChild(value_td);

	var sel_td = document.createElement('td');
        sel_td.innerHTML = (optObj.initselect && optObj.initselect != '' ? formdata_translations['Yes'] : formdata_translations['No']);
        tr.appendChild(sel_td);

        var edit_td = document.createElement('td');
        var edit_a = document.createElement('a');
        edit_a.href = document.location.href;

        var edit_url = formdata_admin_url + "?obvius_app_formdatarepeat&mode=edit_option&rulenr=" + i;
        var window_options = "menubar=no,toolbar=no,scrollbars=yes,width=" + formdata_option_dialog_width + ",height=" + formdata_option_dialog_height;
        eval("edit_a.onclick = function () { window.open('" + edit_url + "', 'formdata_edit_option', '" + window_options + "'); return false;}");
        edit_a.innerHTML = formdata_translations['Edit'];
        edit_td.appendChild(edit_a);
        tr.appendChild(edit_td);

        var del_td = document.createElement('td');
        var del_a = document.createElement('a');
        del_a.href = document.location.href;
        eval("del_a.onclick = function () { formdata_delete_option(" + i + "); return false;}");
        del_a.innerHTML = formdata_translations['Delete'];
        del_td.appendChild(del_a);
        tr.appendChild(del_td);

        var updown_td = document.createElement('td');
        updown_td.align="center";
        var up_a = document.createElement('a');
        up_a.href = document.location.href;
        eval("up_a.onclick = function() {formdata_move_option(" + i + ", 'up'); return false;}");
        up_a.innerHTML = formdata_translations['Up'];
        var down_a = document.createElement('a');
        down_a.href = document.location.href;
        eval("down_a.onclick = function() {formdata_move_option(" + i + ", 'down'); return false;}");
        down_a.innerHTML = formdata_translations['Down'];

        updown_td.appendChild(up_a);
        updown_td.appendChild(document.createTextNode(" / "));
        updown_td.appendChild(down_a);
        tr.appendChild(updown_td);

        var tbodies = table.getElementsByTagName('tbody');
        if(tbodies[0]) {
            tbodies[0].appendChild(tr);
        } else {
            table.appendChild(tr);
        }
    }


}

function formdata_validate_and_save_field(form_fieldname, old_name) {
    if(! formdata_validate_field_dialog(fieldNode)) {
        return false;
    }

    formdata_save_field_form_data(fieldNode);


    var rootDoc;
    if(window.opener.formdata_get_rootDoc_by_name) {
        rootDoc = window.opener.formdata_get_rootDoc_by_name(form_fieldname);
    } else {
        alert(formdata_translations['parent_connection_lost']);
        return false;
    }

    var nameNodes = rootDoc.getElementsByTagName('name');

    var replaceNode;

    for(var i=0;i<nameNodes.getLength();i++) {
        if(formdata_get_node_text(nameNodes.item(i)) == old_name) {
            replaceNode = nameNodes.item(i).getParentNode();
        }
    }

    if(replaceNode) {
        // Replace the replaceNode with fieldNode:
        replaceNode.getParentNode().replaceChild(fieldNode, replaceNode);
    } else {
        alert(formdata_translations["couldnt_find_node"] + " " + old_name);
        return false;
    }

    window.opener.formdata_populate_fieldtable(form_fieldname, false);

    window.close();
}

function formdata_validate_and_add_field(form_fieldname, old_name) {
    var rootDoc;
    if(window.opener.formdata_get_rootDoc_by_name) {
        rootDoc = window.opener.formdata_get_rootDoc_by_name(form_fieldname);
    } else {
        alert(formdata_translations['parent_connection_lost']);
        return false;
    }

    // First make sure we have a name value:
    if(! document.pageform.name.value) {
        var nameValue = document.pageform.title.value || '';
        nameValue = nameValue.replace(/[^a-zA-Z0-9]/g, "_");

        // Test if that name is already used and if it is
        // make a new name by adding an integer at the end
        // of the name.
        var names = rootDoc.getElementsByTagName('name');

        var namesObj = new Object;
        for(var i=0;i<names.getLength();i++) {
            var nameItem = names.item(i);
            namesObj[formdata_get_node_text(nameItem)] = 1;
        }

        var orgName = nameValue;
        var count_up = 1;
        while(namesObj[nameValue]) {
            nameValue = orgName + "_" + count_up;
            count_up++;
        }

        document.pageform.name.value = nameValue;
    }

    if(! formdata_validate_field_dialog(fieldNode)) {
        return false;
    }

    formdata_save_field_form_data(fieldNode);

    // First import the fieldNode into the rootDoc
    var newNode = rootDoc.importNode(fieldNode, true);

    // Hmmm, the type field seems to be reset for some reason in Internet Explorer.
    // Try to fix it like this:
    var newTypeNode = newNode.getElementsByTagName('type').item(0);
    if(newTypeNode.getFirstChild()) {
        var typeText = newTypeNode.getFirstChild().getXML();
        newTypeNode.removeChild(newTypeNode.getFirstChild());
        newTypeNode.appendChild(newTypeNode.getOwnerDocument().createTextNode(typeText));
    }

    // Then add it as a child of the fields element:
    var fieldsNode = rootDoc.getElementsByTagName('fields').item(0);
    fieldsNode.appendChild(newNode);

    window.opener.formdata_populate_fieldtable(form_fieldname, false);

    window.close();
}

function formdata_save_field_form_data(fieldNode) {
    // Save new name value:
    var nameNode = fieldNode.getElementsByTagName('name').item(0);
    var newName = nameNode.getOwnerDocument().createTextNode(document.pageform.name.value);
    if(nameNode.getFirstChild()) {
        nameNode.replaceChild(newName, nameNode.getFirstChild());
    } else {
        nameNode.appendChild(newName);
    }

    // Save new title value:
    var titleNode = fieldNode.getElementsByTagName('title').item(0);
    var newTitle = titleNode.getOwnerDocument().createTextNode(document.pageform.title.value);
    if(titleNode.getFirstChild()) {
        titleNode.replaceChild(newTitle, titleNode.getFirstChild());
    } else {
        titleNode.appendChild(newTitle);
    }


    var mand_value;
    if(document.getElementById('mand_yes').checked) {
        mand_value = "1";
    } else if(document.getElementById('mand_no').checked) {
        mand_value = "0";
    } else {
        var fields_dropdown = document.pageform.mandatory_fields;
        var fields_value = fields_dropdown.options[fields_dropdown.selectedIndex].value;
        if(document.pageform.mandatory_operator.selectedIndex == 0) {
            mand_value = fields_value;
        } else {
            mand_value = "!" + fields_value;
        }
    }

    var mandNode = fieldNode.getElementsByTagName('mandatory').item(0);
    var newMand = mandNode.getOwnerDocument().createTextNode(mand_value);
    if(mandNode.getFirstChild()) {
        mandNode.replaceChild(newMand, mandNode.getFirstChild());
    } else {
        mandNode.appendChild(newMand);
    }

    var unique_value = document.getElementById('unique_yes').checked ? 1 : 0;

    var uniqueNode = fieldNode.getElementsByTagName('unique').item(0);

    // Can't be sure if unique is there, so if it doesn't exist, create it:
    if(! uniqueNode) {
        uniqueNode = fieldNode.getOwnerDocument().createElement('unique');
        fieldNode.appendChild(uniqueNode);
    }

    var uniqueText = fieldNode.getOwnerDocument().createTextNode(unique_value);
    if(uniqueNode.getFirstChild()) {
        uniqueNode.replaceChild(uniqueText, uniqueNode.getFirstChild());
    } else {
        uniqueNode.appendChild(uniqueText);
    }


    // Imagepath:
    var imgNode = fieldNode.getElementsByTagName('imagepath').item(0);
    if(! imgNode) {
        // Create an imagepath node if none was present
        imgNode = fieldNode.getOwnerDocument().createElement('imagepath');
        fieldNode.appendChild(imgNode);
    }
    var img_value = document.pageform.imagepath.value || "";
    var newImg = imgNode.getOwnerDocument().createTextNode(img_value);
    if(imgNode.getFirstChild()) {
        imgNode.replaceChild(newImg, imgNode.getFirstChild());
    } else {
        imgNode.appendChild(newImg);
    }

    // Description/explanation:
    var descNode = fieldNode.getElementsByTagName('description').item(0);
    if(! descNode) {
        descNode = fieldNode.getOwnerDocument().createElement('description');
        fieldNode.appendChild(descNode);
    }
    var desc_value = document.pageform.description.value || "";
    var newDesc = descNode.getOwnerDocument().createTextNode(desc_value);
    if(descNode.getFirstChild()) {
        descNode.replaceChild(newDesc, descNode.getFirstChild());
    } else {
        descNode.appendChild(newDesc);
    }

    // Col index for public lists
    var colIndexNode = fieldNode.getElementsByTagName('colindex').item(0);
    if(! colIndexNode) {
        colIndexNode = fieldNode.getOwnerDocument().createElement('colindex');
        fieldNode.appendChild(colIndexNode);
    }
    var colidx_value = document.pageform.colindex.value || "0";
    var newColIdx = colIndexNode.getOwnerDocument().createTextNode(colidx_value);
    if(colIndexNode.getFirstChild()) {
        colIndexNode.replaceChild(newColIdx, colIndexNode.getFirstChild());
    } else {
        colIndexNode.appendChild(newColIdx);
    }

    // Determinies public list visibility
    var listPublicNode = fieldNode.getElementsByTagName('listpublic').item(0);
    if(! listPublicNode) {
        listPublicNode = fieldNode.getOwnerDocument().createElement('listpublic');
        fieldNode.appendChild(listPublicNode);
    }
    var listpub_value = document.pageform.listpublic.value || "";
    var newListPub = listPublicNode.getOwnerDocument().createTextNode(listpub_value);
    if(listPublicNode.getFirstChild()) {
        listPublicNode.replaceChild(newListPub, listPublicNode.getFirstChild());
    } else {
        listPublicNode.appendChild(newListPub);
    }

    // Check for params from the form. Params are defined
    // as form elements whose name start with "param_".
    var form = document.pageform;
    var params = new Array();
    for(var i=0;i<form.length;i++) {
        var formElem = form[i];
        if(formElem.name.match(/^param_/) && formElem.value) {
            params[params.length] = { name: formElem.name, value: formElem.value };
        }
    }

    if(params.length) {
        // Check for existing params node. If none exists, create one.
        var paramsNode = fieldNode.getElementsByTagName('params').item(0);
        if(! paramsNode) {
            paramsNode = fieldNode.getOwnerDocument().createElement('params');
            fieldNode.appendChild(paramsNode);
        }

        // Set the params given from the form:
        for(var i=0;i<params.length;i++) {
            var paramElem = paramsNode.getElementsByTagName(params[i].name).item(0);
            if(! paramElem) {
                paramElem = paramsNode.getOwnerDocument().createElement(params[i].name);
                paramsNode.appendChild(paramElem);
            }

            var newValue = paramsNode.getOwnerDocument().createTextNode(params[i].value);
            if(paramElem.getFirstChild()) {
                paramElem.replaceChild(newValue, paramElem.getFirstChild());
            } else {
                paramElem.appendChild(newValue);
            }
        }
    } else {
        // No params, so remove whole params block from the XML:
        var paramsNode = fieldNode.getElementsByTagName('params').item(0);
        if(paramsNode) {
            paramsNode.getParentNode().removeChild(paramsNode);
        }
    }

    // Validationrules and options should always be up to date, so
    // don't mess around with them.

}


function formdata_validate_field_dialog(fieldNode) {
    if(! document.pageform.title.value) {
        alert(formdata_translations['must_specify_title']);
        return false;
    }
    if(! document.pageform.name.value) {
        alert(formdata_translations['must_specify_name']);
        return false;
    }

    if(!(document.getElementById('mand_yes').checked || document.getElementById('mand_no').checked || document.getElementById('mand_field').checked)) {
        alert(formdata_translations['must_specify_mandatory']);
        return false;
    }

    if(document.getElementById('mand_field').checked) {
        var fields_dropdown = document.pageform.mandatory_fields;
        var fieldname = fields_dropdown.options[fields_dropdown.selectedIndex].value;

        if(! fieldname) {
            alert(formdata_translations['must_specify_mandatory_depends']);
            return false;
        }

        if(fieldname == document.pageform.name.value) {
            alert(formdata_translations['cant_depend_on_self']);
            return false;
        }
    }


    return true;
}

function formdata_delete_option(optionNr) {
    var options = fieldNode.getElementsByTagName('option');
    var delOpt = options.item(optionNr);
    if(delOpt) {
        delOpt.getParentNode().removeChild(delOpt);
        formdata_populate_options(fieldNode);
    } else {
        alert(formdata_translations["cant_delete_option"] + " " + optionNr);
    }
}

function formdata_delete_validaterule(valNr) {
    var valRules = fieldNode.getElementsByTagName('validaterule');
    var delVal = valRules.item(valNr);
    if(delVal) {
        delVal.getParentNode().removeChild(delVal);
        formdata_populate_validaterules(fieldNode);
    } else {
        alert(formdata_translations["cant_delete_valrule"] + " " + optionNr);
    }
}


function formdata_init_option_edit(ruleNr) {
    var fieldNode = window.opener.fieldNode;

    if(! fieldNode) {
        alert(formdata_translations["no_parent_fieldnode"] + " - " +  formdata_translations['cant_edit_option']);
        return false;
    }

    if(ruleNr != "") {
        var options = fieldNode.getElementsByTagName('option');
        optionNode = options.item(ruleNr).cloneNode(true);
    } else {
        // Make a XML node with default values
        var tmpXML = "";
        tmpXML += "<root>";
        tmpXML += " <option>";
        tmpXML += "  <optiontitle></optiontitle>";
        tmpXML += "  <optionvalue></optionvalue>";
	tmpXML += "  <initselect></initselect>";
        tmpXML += " </option>";
        tmpXML += "</root>";

        var parser = new DOMImplementation();
        var tmpDomDoc = parser.loadXML(tmpXML);

        var tmpRootDoc = tmpDomDoc.getDocumentElement();

        optionNode = tmpRootDoc.getElementsByTagName('option').item(0);
    }

    var titleNode = optionNode.getElementsByTagName('optiontitle').item(0);
    if(titleNode) {
        document.pageform.title.value = formdata_get_node_text(titleNode);
    }

    var valueNode = optionNode.getElementsByTagName('optionvalue').item(0);
    if(valueNode) {
        document.pageform.optionvalue.value = formdata_get_node_text(valueNode);
    }

    var initSelNode = optionNode.getElementsByTagName('initselect').item(0);
    if(initSelNode) {
	var selTxt = formdata_get_node_text(initSelNode);
	document.pageform.initselect.value = selTxt == '1' ? '1' : '';
	document.pageform.initselect.checked = selTxt == '1';
    }
}

function formdata_validate_options_dialog() {
    var title = document.pageform.title.value;
    if(! title) {
        alert(formdata_translations['must_specify_title']);
        return false;
    }

    var value = document.pageform.optionvalue.value;
    if(! value) {
        alert(formdata_translations['must_specify_value']);
        return false;
    }

    // Save the valid data to the xml:
    var titleNode = optionNode.getElementsByTagName('optiontitle').item(0);
    var newTitle = optionNode.getOwnerDocument().createTextNode(document.pageform.title.value);
    if(titleNode.getFirstChild()) {
        titleNode.replaceChild(newTitle, titleNode.getFirstChild());
    } else {
        titleNode.appendChild(newTitle);
    }

    var valueNode = optionNode.getElementsByTagName('optionvalue').item(0);
    var newValue = optionNode.getOwnerDocument().createTextNode(document.pageform.optionvalue.value);
    if(valueNode.getFirstChild()) {
        valueNode.replaceChild(newValue, valueNode.getFirstChild());
    } else {
        valueNode.appendChild(newValue);
    }

    var selNode = optionNode.getElementsByTagName('initselect').item(0);
    var checked = document.pageform.initselect.checked;
    var selValue = optionNode.getOwnerDocument().createTextNode(checked ? '1' : '');
    if(selNode.getFirstChild()) {
        selNode.replaceChild(selValue, selNode.getFirstChild());
    } else {
        selNode.appendChild(selValue);
    }

    return true;
}


function formdata_validate_and_save_option(ruleNr) {
    if(! formdata_validate_options_dialog()) {
      return false;
    }

    var fieldNode = window.opener.fieldNode;
    if(! fieldNode) {
        alert(formdata_translations["no_parent_fieldnode"] + " - " +  formdata_translations['cant_save_option']);
    }

    var options = fieldNode.getElementsByTagName('option');
    var replaceOption = options.item(ruleNr);
    if(replaceOption) {
        replaceOption.getParentNode().replaceChild(optionNode, replaceOption);
    }

    window.opener.formdata_populate_options(fieldNode);

    window.close();
}

function formdata_validate_and_add_option() {
    if(! formdata_validate_options_dialog()) {
      return false;
    }

    var fieldNode = window.opener.fieldNode;
    if(! fieldNode) {
        alert(formdata_translations["no_parent_fieldnode"] + " - " +  formdata_translations['cant_save_option']);
    }

    var options = fieldNode.getElementsByTagName('options').item(0);

    var newOption = fieldNode.getOwnerDocument().importNode(optionNode, true);
    options.appendChild(newOption);

    window.opener.formdata_populate_options(fieldNode);

    window.close();
}

function formdata_add_new_option() {
    window.open(formdata_admin_url + "?obvius_app_formdatarepeat&mode=edit_option", "formdata_edit_option", "menubar=no,toolbar=no,scrollbars=yes,width=" + formdata_option_dialog_width + ",height=" + formdata_option_dialog_height);
    return false;
}


function formdata_init_valrule_edit(ruleNr) {
    var fieldNode = window.opener.fieldNode;

    if(! fieldNode) {
        alert(formdata_translations["no_parent_fieldnode"] + " - " +  formdata_translations['cant_edit_valrule']);
        return false;
    }

    if(ruleNr != "") {
        var valrules = fieldNode.getElementsByTagName('validaterule');
        valruleNode = valrules.item(ruleNr).cloneNode(true);
    } else {
        // Make a XML node with default values
        var tmpXML = "";
        tmpXML += "<root>";
        tmpXML += " <validaterule>";
        tmpXML += "  <validationtype></validationtype>";
        tmpXML += "  <validationargument></validationargument>";
        tmpXML += "  <errormessage></errormessage>";
        tmpXML += " </validaterule>";
        tmpXML += "</root>";

        var parser = new DOMImplementation();
        var tmpDomDoc = parser.loadXML(tmpXML);

        var tmpRootDoc = tmpDomDoc.getDocumentElement();

        valruleNode = tmpRootDoc.getElementsByTagName('validaterule').item(0);
    }

    var typeVal = "";
    var typeNode = valruleNode.getElementsByTagName('validationtype').item(0);
    if(typeNode) {
        typeVal = formdata_get_node_text(typeNode);
    }

    var fieldType = '';
    var fieldTypeNode = fieldNode.getElementsByTagName('type').item(0);
    if(fieldTypeNode) {
        fieldType = formdata_get_node_text(fieldTypeNode);
    }

    var rulesByFieldType = {
                            'checkbox': {
                                            'min_checked':  1,
                                            'max_checked':  1,
                                            'x_checked':    1,
                                            'dummy':        0
                                        },
                            'text': {
                                        'regexp':       1,
                                        'min_length':   1,
                                        'max_length':   1,
                                        'dummy':        0
                                    },
                            'select': {
                                        'dummy':        0
                                    },
                            'fieldset': {},
                            'dummy': {}
                        };
    rulesByFieldType['selectmultiple'] = rulesByFieldType['checkbox'];
    rulesByFieldType['password'] = rulesByFieldType['text'];
    rulesByFieldType['textarea'] = rulesByFieldType['text'];
    rulesByFieldType['radio'] = rulesByFieldType['select'];

    var enabledTypes = rulesByFieldType[fieldType] || {};

    // Show predefined validationrules only if the regexp type
    // is enabled:
    if(enabledTypes['regexp']) {
        document.getElementById('predefined').style.display = '';
    }


    var types = document.pageform.type.options;

    // Loop over contents of the type dropdown and remove types
    // that we do not want. Must loop backwards since we'll be
    // removing stuff as we go.
    for(var i=types.length - 1;i>=0;i--) {
        if(! enabledTypes[types[i].value]) {
            types[i] = null;
        }
    }

    // And then loop over the options now present and set
    // selectedIndex:
    for(var i=0;i<types.length;i++) {
        if(typeVal == types[i].value) {
            document.pageform.type.selectedIndex = i;
            break;
        }
    }


    var argNode = valruleNode.getElementsByTagName('validationargument').item(0);
    if(argNode) {
        document.pageform.argument.value = formdata_get_node_text(argNode);
    }

    var errNode = valruleNode.getElementsByTagName('errormessage').item(0);
    if(errNode) {
        document.pageform.errormessage.value = formdata_get_node_text(errNode);
    }
}

var predefined_valrules = {
                            'valid_email': ['regexp', '^.+\\@.+\\.\\w+$', formdata_translations['predef_valrule_valid_email']],
                            'numbers_only': ['regexp', '^\\d+$', formdata_translations['predef_valrule_numbers_only']],
                            'postal_code': ['regexp', '^\\d\\d\\d\\d$', formdata_translations['predef_valrule_postal_code']],
                            'phone_number': ['regexp', '^([+0]\\d\\d)?\\d\\d[- ]*\\d\\d[- ]*\\d\\d[- ]*\\d\\d$', formdata_translations['predef_valrule_phone_number']],
                            'dummy': []
                        };


function formdata_set_predefined_valrule(optionElem) {
    if(! optionElem) {
        return false;
    }

    if(! optionElem.value) {
        return true;
    }

    var data = predefined_valrules[optionElem.value];

    if(! data) {
        return true;
    }


    var typeDropDown = document.pageform.type;
    for(var i=0;i<typeDropDown.options.length;i++) {
        if(typeDropDown.options[i].value == data[0]) {
            typeDropDown.selectedIndex = i;
            break;
        }
    }

    document.pageform.argument.value = data[1];
    document.pageform.errormessage.value = data[2];
}


function formdata_validate_valrule_dialog() {
    var typeSelect = document.pageform.type;

    var typeVal = typeSelect.options[typeSelect.selectedIndex].value;

    if(! typeVal) {
        alert(formdata_translations['must_specify_validation_type']);
        return false;
    }

    var arg = document.pageform.argument.value;

    if(typeVal == 'regexp') {
        if(! arg) {
            alert(formdata_translations['must_specify_arg']);
            return false;
        }
    } else if(typeVal == 'min_checked' || typeVal == 'max_checked' || typeVal == 'x_checked' || typeVal == 'min_length' || typeVal == 'max_length') {
        if(! arg || ! arg.match(/^\d+$/)) {
            alert(formdata_translations['must_specify_integer_arg']);
            return false;
        }
    } else {
        alert(formdata_translations['unknown_validate_type'] + ': '+ typeVal);
        return false;
    }

    if(! document.pageform.errormessage.value) {
        alert(formdata_translations['must_specify_errormessage']);
        return false;
    }


    // Save the valid data to the xml:
    var typeNode = valruleNode.getElementsByTagName('validationtype').item(0);
    var newType = valruleNode.getOwnerDocument().createTextNode(typeVal);
    if(typeNode.getFirstChild()) {
        typeNode.replaceChild(newType, typeNode.getFirstChild());
    } else {
        typeNode.appendChild(newType);
    }

    var argNode = valruleNode.getElementsByTagName('validationargument').item(0);
    var newArg = valruleNode.getOwnerDocument().createTextNode(document.pageform.argument.value);
    if(argNode.getFirstChild()) {
        argNode.replaceChild(newArg, argNode.getFirstChild());
    } else {
        argNode.appendChild(newArg);
    }

    var errNode = valruleNode.getElementsByTagName('errormessage').item(0);
    var newErr = valruleNode.getOwnerDocument().createTextNode(document.pageform.errormessage.value);
    if(errNode.getFirstChild()) {
        errNode.replaceChild(newErr, errNode.getFirstChild());
    } else {
        errNode.appendChild(newErr);
    }

    return true;
}

function formdata_validate_and_save_valrule(ruleNr) {
    if(! formdata_validate_valrule_dialog()) {
      return false;
    }

    var fieldNode = window.opener.fieldNode;
    if(! fieldNode) {
        alert(formdata_translations["no_parent_fieldnode"] + " - " +  formdata_translations['cant_save_valrule']);
    }

    var valrules = fieldNode.getElementsByTagName('validaterule');
    var replaceValrule = valrules.item(ruleNr);
    if(replaceValrule) {
        replaceValrule.getParentNode().replaceChild(valruleNode, replaceValrule);
    }

    window.opener.formdata_populate_validaterules(fieldNode);

    window.close();
}

function formdata_validate_and_add_valrule() {
    if(! formdata_validate_valrule_dialog()) {
      return false;
    }

    var fieldNode = window.opener.fieldNode;
    if(! fieldNode) {
        alert(formdata_translations["no_parent_fieldnode"] + " - " +  formdata_translations['cant_save_valrule']);
    }

    var valrules = fieldNode.getElementsByTagName('validaterules').item(0);

    var newValrule = fieldNode.getOwnerDocument().importNode(valruleNode, true);
    valrules.appendChild(newValrule);

    window.opener.formdata_populate_validaterules(fieldNode);

    window.close();
}

function formdata_add_new_valrule() {
    window.open(formdata_admin_url + "?obvius_app_formdatarepeat&mode=edit_validaterule", "formdata_edit_valrule", "menubar=no,toolbar=no,scrollbars=yes,width=" + formdata_valrule_dialog_width + ",height=" + formdata_valrule_dialog_height);
    return false;
}


function formdata_move_field(name, nr, direction) {

    rootDoc = formdata_get_rootDoc_by_name(name);

    var fields = rootDoc.getElementsByTagName('field');


    var firstElem;
    var secondElem;

    if(direction == 'up') {
        firstElem = fields.item(nr - 1);
        secondElem = fields.item(nr);
    } else {
        firstElem = fields.item(nr);
        secondElem = fields.item(nr + 1);
    }

    if(! (firstElem && secondElem))
        return false;

    var secondClone = secondElem.cloneNode(true);
    secondElem.getParentNode().removeChild(secondElem);
    firstElem.getParentNode().insertBefore(secondClone, firstElem);

    formdata_populate_fieldtable(name, false);
}

function formdata_move_valrule(nr, direction) {

    var valrules = fieldNode.getElementsByTagName('validaterule');


    var firstElem;
    var secondElem;

    if(direction == 'up') {
        firstElem = valrules.item(nr - 1);
        secondElem = valrules.item(nr);
    } else {
        firstElem = valrules.item(nr);
        secondElem = valrules.item(nr + 1);
    }

    if(! (firstElem && secondElem))
        return false;

    var secondClone = secondElem.cloneNode(true);
    secondElem.getParentNode().removeChild(secondElem);
    firstElem.getParentNode().insertBefore(secondClone, firstElem);

    formdata_populate_validaterules(fieldNode);
}

function formdata_move_option(nr, direction) {

    var options = fieldNode.getElementsByTagName('option');

    var firstElem;
    var secondElem;

    if(direction == 'up') {
        firstElem = options.item(nr - 1);
        secondElem = options.item(nr);
    } else {
        firstElem = options.item(nr);
        secondElem = options.item(nr + 1);
    }

    if(! (firstElem && secondElem))
        return false;

    var secondClone = secondElem.cloneNode(true);
    secondElem.getParentNode().removeChild(secondElem);
    firstElem.getParentNode().insertBefore(secondClone, firstElem);

    formdata_populate_options(fieldNode);
}


// Helper functions

function formdata_get_node_text(node) {
    var firstChild = node.getFirstChild();

    if(! firstChild) {
        return "";
    }

    if(firstChild.getNodeType() == 3) {
        return firstChild.getXML();
    }

    return "NOT_TEXT";
}

function formdata_objectify_repeat_node(node) {
    var obj = new Object();
    var children = node.getChildNodes();
    var titleNode = children.item(0);
    var title = titleNode.getChildNodes().item(0);
    obj['title'] = __unescapeString(title.getXML());
    
    var fieldMap = {};
    var fields = children.item(1).getChildNodes();
    for(var i=0;i < fields.getLength();i++) {
        var field = fields.item(i);
	var nameElem = field.getChildNodes().item(0);
        var titleElem = field.getChildNodes().item(1);
	var nameContent = nameElem.getChildNodes().item(0);
        var titleContent = titleElem.getChildNodes().item(0);
	fieldMap[__unescapeString(nameContent.getXML())] = __unescapeString(titleContent.getXML());
    }
    obj['repfields'] = fieldMap;
    return obj;
}

function formdata_objectify_node(node) {
    var obj = new Object();
    var children = node.getChildNodes();
    for(var i=0;i < children.getLength();i++) {
        var child = children.item(i);
        var content = child.getChildNodes().item(0);
        if(content && content.getNodeType() == 3) {
          obj[child.getNodeName()] = __unescapeString(content.getXML());
        }
    }

    return obj;
}

function formdata_get_rootDoc_by_name(name) {
    if(! rootDocs[name]) {
        // Small hack to work with the new admin: Try to lookup the element
        // by id first - id and name on the form element should be the same
        // in the new admin.
        var formElem = document.getElementById(name) || document.pageform[name];
        if(formElem) {
            formdata_load_rootDoc_data(formElem);
        }
    }
    return rootDocs[name];
}

function formdata_load_rootDoc_data(elem) {
    var xmlText = elem.value || '<fields></fields>';
    var parser = new DOMImplementation();
    var domDoc = parser.loadXML(xmlText);
    var rootDoc = domDoc.getDocumentElement();

    rootDocs[elem.name] = rootDoc;

    return rootDoc;
}

function formdata_extract_name(name) {
    return name.replace(/.*:([^:]+)$/, "$1");
}

function OpenWin(url, w, h) {
  window.name="main";
  if (w == null || w == 0) w = 350;
  if (h == null || h == 0) h = 450;
  var features = ('toolbar=0,location=0,directories=0,status=0,'
                  +'menubar=0,scrollbars=1,resizable=1,copyhistory=0,'
                  +'width='+w+',height='+h);
  window.open (url + '', '', features);
}

/* Funtions for repeatable areas */
function reflectFields_on_repeatables() {
    var all = document.getElementById('obvius_all_rep_areas');
    
    var areas = all.children;
    var patt = /^obvius_repeated_area_/;
    for ( var idx = 0; idx < areas.length; idx++ ) {
	var curid = areas[idx].id;
	var curindex = curid.replace(patt, '');
	var select = document.getElementById('obvius_repeated_area_fields_' + curindex);
	var opts = select.children;
	var optsMap = {};

	/* Find currently selected */
	for (var selidx = 0; selidx < opts.length; selidx++) {
	    var curnam = opts[selidx].value;
	    var cursel = opts[selidx].selected;
	    if ( curnam && cursel ) {
		optsMap[curnam] = true;
	    }
	}

	/* Delete all options */
	while (select.firstChild) {
	    select.removeChild(select.firstChild);
	}

	/* Insert all "new" field */
	for (var namekey in obvius_field_name_marker) {
	    var theopt = document.createElement('option');
	    theopt.value = namekey;
	    theopt.innerHTML = obvius_field_name_marker[namekey];
	    if ( optsMap[namekey] )
		theopt.selected = true;
	    select.appendChild(theopt);
	}
    }
}

function insert_repeat_area(theobj) {
    var objfields = theobj ? theobj.repfields : {};
    var fieldsMarker = objfields;

    var all = document.getElementById('obvius_all_rep_areas');
    var count = obvius_rep_area_count + 1;
    
    /* new area */
    var newArea = document.createElement('div');
    newArea.setAttribute('className', 'RepArea');
    newArea.id = 'obvius_repeated_area_' + count;
    
    /* fieldset */
    var fs = document.createElement('fieldset');
    var leg = document.createElement('legend');
    leg.innerHTML = formdata_translations['Repeatable area'];
    fs.appendChild(leg);
    
    /* title and options */
    var lab = document.createElement('label');
    lab.setAttribute('for', 'obvius_repeated_area_title_' + count);
    lab.innerHTML = formdata_translations['Title'];
    fs.appendChild(lab);
    
    var inp = document.createElement('input');
    inp.setAttribute('type', 'text');
    inp.setAttribute('id', 'obvius_repeated_area_title_' + count);
    inp.setAttribute('value', theobj ? theobj.title : '');
    inp.setAttribute('size', '60');
    fs.appendChild(inp);
    
    var para = document.createElement('p');
    lab = document.createElement('label');
    lab.setAttribute('for', 'obvius_repeated_area_fields_' + count);
    lab.innerHTML = formdata_translations['Chosen formfields'];
    para.appendChild(lab);
    para.appendChild(document.createElement('br'));
    var sel = document.createElement('select');
    sel.setAttribute('size', 10);
    sel.setAttribute('multiple', 'multiple');
    sel.setAttribute('style', 'width:40%');
    sel.setAttribute('id', 'obvius_repeated_area_fields_' + count);
    for (var i = 0; i < obvius_rep_field_names.length; i++) {
	var opt = document.createElement('option');
	opt.setAttribute('value', obvius_rep_field_names[i]);
	opt.innerHTML = obvius_rep_field_displays[i];
	if ( fieldsMarker[obvius_rep_field_names[i]] ) {
	    opt.setAttribute('selected', true);
	}
	sel.appendChild(opt);
    }
    para.appendChild(sel);
    fs.appendChild(para);
    
    /* buttons */
    var butdiv = document.createElement('div');
    butdiv.setAttribute('className', 'RepAreaButs');
    
    /* Below is outcommented for now - only one repeat area */
    /* var but = document.createElement('button');
    but.onclick = function () { move_repeat_area(-1, 'obvius_repeated_area_' + count); return false };
    but.innerHTML = 'Flyt opad';
    butdiv.appendChild(but);
    but = document.createElement('button');
    but.onclick = function () { move_repeat_area(1, 'obvius_repeated_area_' + count); return false };
    but.innerHTML = 'Flyt nedad';
    butdiv.appendChild(but); */

    var but = document.createElement('button');
    but.onclick = function () { remove_repeat_area('obvius_repeated_area_' + count); return false };
    but.innerHTML = formdata_translations['Delete'];
    butdiv.appendChild(but);
    fs.appendChild(butdiv);
    
    /* Finish up */
    newArea.appendChild(fs);	   
    all.appendChild(newArea);
    obvius_rep_area_count = count;
    newArea.scrollIntoView(true);

    /* Only one area */
    var newButArea = document.getElementById('obvius_new_rep_area');
    if ( newButArea )
	newButArea.style.display = 'none';
}

function remove_repeat_area(theid) {
    var all = document.getElementById('obvius_all_rep_areas');
    var cur = document.getElementById(theid);
    if ( cur ) {
	all.removeChild(cur);
	var newButArea = document.getElementById('obvius_new_rep_area');
	if ( newButArea )
	    newButArea.style.display = '';
    }
}

function move_repeat_area(offset, theid) {
    var all = document.getElementById('obvius_all_rep_areas');
    var cur = document.getElementById(theid);
    var ioff = offset == '-1' ? -1 : 1;
    var curarea1;
    var curarea2;
    var trackarea;
    
    if ( cur ) {
	var areas = all.children;
	for ( var idx = 0; idx < areas.length; idx++ ) {
	    if ( areas[idx].id == theid ) {
                if ( (ioff == -1) && (idx > 0) ) {
		    curarea1 = areas[idx - 1];
                    curarea2 = areas[idx];
                    trackarea = curarea2;
                } 
                if ( (ioff == 1) && (idx < (areas.length - 1)) ) {
                    curarea1 = areas[idx];
                    curarea2 = areas[idx + 1];
                    trackarea = curarea1;
                }
                break;
	    }
	}
	if ( curarea1 && curarea2 ) {
	    // create marker element and insert it where obj1 is
	    var temp = document.createElement("div");
	    all.insertBefore(temp, curarea1);
	    
	    // move obj1 to right before obj2
	    all.insertBefore(curarea1, curarea2);
	    
	    // move obj2 to right before where obj1 used to be
	    all.insertBefore(curarea2, temp);
	    
	    // remove temporary marker node
	    all.removeChild(temp);
	    
	    trackarea.scrollIntoView(true);
	}
    }
}

function merge_rootDoc_repeatables(rootDoc) {
    var tmpXML = "<root><repeatables>";
    var all = document.getElementById('obvius_all_rep_areas');
    var areas = all.children;
    var result = new Array();
    var patt = /^obvius_repeated_area_/;
    for ( var idx = 0; idx < areas.length; idx++ ) {
	var curid = areas[idx].id;
	var curindex = curid.replace(patt, '');
	var title = document.getElementById('obvius_repeated_area_title_' + curindex);
	var select = document.getElementById('obvius_repeated_area_fields_' + curindex);
	if ( title && select ) {
	    var fields = new Array();
	    var opts = select.children;
	    for ( var fidx = 0; fidx < opts.length; fidx++ ) {
		if ( opts[fidx].selected )
		    fields.push(opts[fidx].value);
	    }
	    if ( title.value && fields.length > 0 ) {
		tmpXML += '<repeatable><title>' + title.value + '</title>';
		tmpXML += '<repfields>';
		for (var fidx = 0; fidx < fields.length; fidx++) {
		    tmpXML += '<repfield><name>' + fields[fidx] + '</name>';
		    tmpXML += '<title>' + obvius_field_name_marker[fields[fidx]] + '</title></repfield>';
		}
		tmpXML += '</repfields></repeatable>';
	    }
	}
    }
    tmpXML += "</repeatables></root>";

    var parser = new DOMImplementation();
    var tmpDomDoc = parser.loadXML(tmpXML);
    var tmpRootDoc = tmpDomDoc.getDocumentElement();
    var elem = tmpRootDoc.getElementsByTagName('repeatables').item(0);
    // First import the elem into the rootDoc
    var elemNode = rootDoc.importNode(elem, true);
    rootDoc.getElementsByTagName('fields').item(0).appendChild(elemNode);
}

