// Global variables used

var rootDocs = new Object();

var formdata_field_dialog_width = 550;
var formdata_field_dialog_height = 400;

var formdata_option_dialog_width = 350;
var formdata_option_dialog_height = 180;

var formdata_valrule_dialog_width = 400;
var formdata_valrule_dialog_height = 250;


function formdata_init(elem) {
    // Unhide the advanced editing controls:
    var edit_elem = document.getElementById("obvius_" + elem.name + "_advanced_editing");
    edit_elem.style.display = 'block';

    // Hide the normal editing element:
    elem.style.display = "none";

    // Setup data:
    formdata_load_rootDoc_data(elem);
    formdata_populate_fieldtable(elem.name);

}

function formdata_save(elem) {
    var rootDoc = formdata_get_rootDoc_by_name(elem.name);

    var xml = rootDoc.getXML();

    xml = xml.replace(/></g, ">\n<");

    elem.value = xml;

}

function formdata_populate_fieldtable(name) {

    rootDoc = formdata_get_rootDoc_by_name(name);

    if(! rootDoc)
        return false;

    var table = document.getElementById('obvius_' + name + '_displaylist');

    if(! table)
        return false;

    // Cleanup existing table
    var table_children = table.getElementsByTagName('tr');
    for(var i=table_children.length;i>1;i--) {
        var child = table_children[i-1];
        child.parentNode.removeChild(child);
    }

    var fields = rootDoc.getElementsByTagName('field');

    if(fields) {
        for(var i=0;i < fields.getLength();i++) {
            var item = fields.item(i);
            var obj = formdata_objectify_node(item);

            // Generate a <tr> for the field:

            var tr = document.createElement('tr');

            var name_td = document.createElement('td');
            name_td.innerHTML = obj.name;
            tr.appendChild(name_td);

            var title_td = document.createElement('td');
            title_td.innerHTML = obj.title;
            tr.appendChild(title_td);

            var type_td = document.createElement('td');
            type_td.innerHTML = obj.type;
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

            var edit_td = document.createElement('td');
            var edit_a = document.createElement('a');
            edit_a.href = document.location.href;

            // Hmmm, have to wrap this in eval to avoid problems with global variables
            var edit_url = "/admin/?obvius_op=formdata_edit&field=" + obj.name + "&fieldname=" + name;
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
}

function formdata_delete_field(formfield_name, fieldname) {
    var rootDoc = formdata_get_rootDoc_by_name(formfield_name);

    var names = rootDoc.getElementsByTagName('name');

    for(var i=0;i < names.getLength();i++) {
        if(formdata_get_node_text(names.item(i)) == fieldname) {
            var removeNode = names.item(i).parentNode;

            removeNode.parentNode.removeChild(removeNode);
            break;
        }
    }

    formdata_populate_fieldtable(formfield_name);
    document.pageform[formfield_name].value = rootDoc.getXML();
}

function formdata_add_new(elem) {
    var type_elem = document.pageform["obvius_" + elem.name + "_new_field_type"];
    if(! type_elem) {
        alert(formdata_translations['cant_find_type']);
        return false;
    }

    var type_value = type_elem.options[type_elem.selectedIndex].value;

    if(! type_value) {
        alert(formdata_translations['must_chose_type']);
        return false;
    }


    window.open("/admin/?obvius_op=formdata_edit&new=" + type_value + "&fieldname=" + elem.name, "formdata_edit", "menubar=no,toolbar=no,scrollbars=yes,width=" + formdata_field_dialog_width + ",height=" + formdata_field_dialog_height);
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
            }
        }
    }

    var fieldObj = formdata_objectify_node(fieldNode);

    document.pageform.title.value = fieldObj.title || "";
    document.pageform.name.value = fieldObj.name || "";
    document.getElementById('type_field').innerHTML = formdata_translations['field_type_' + fieldObj.type] || 'unknown fieldtype';

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

    formdata_populate_validaterules(fieldNode);
    formdata_populate_options(fieldNode);

}

function formdata_populate_validaterules(fieldNode) {
    // First get the table element and empty it:
    var table =  document.getElementById('validaterules_table');

    var table_children = table.getElementsByTagName('tr');
    for(var i=table_children.length;i>1;i--) {
        var child = table_children[i-1];
        child.parentNode.removeChild(child);
    }

    // Get validation nodes:
    var valNodes = fieldNode.getElementsByTagName('validaterule');
    for(var i=0;i<valNodes.getLength();i++) {
        var valNode = valNodes.item(i);
        var valObj = formdata_objectify_node(valNode);

        var tr = document.createElement('tr')

        var type_td = document.createElement('td');
        type_td.innerHTML = valObj.validationtype;
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

        var edit_url = "/admin/?obvius_op=formdata_edit_validaterule&rulenr=" + i
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

        var edit_td = document.createElement('td');
        var edit_a = document.createElement('a');
        edit_a.href = document.location.href;

        var edit_url = "/admin/?obvius_op=formdata_edit_option&rulenr=" + i;
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

    window.opener.formdata_populate_fieldtable(form_fieldname);


    window.close();
}

function formdata_validate_and_add_field(form_fieldname, old_name) {
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

    // First import the fieldNode into the rootDoc
    var newNode = rootDoc.importNode(fieldNode, true);

    // Then add it as a child of the fields element:
    var fieldsNode = rootDoc.getElementsByTagName('fields').item(0);
    fieldsNode.appendChild(newNode);

    window.opener.formdata_populate_fieldtable(form_fieldname);

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

    return true;
}


function formdata_validate_and_save_option(ruleNr) {
    if(! formdata_validate_options_dialog()) {
        return false
    }

    var fieldNode = window.opener.fieldNode;
    if(! fieldNode) {
        alert(formdata_translations["no_parent_fieldnode"] + " - " +  formdata_translations['cant_save_option']);
    }

    var options = fieldNode.getElementsByTagName('option');
    var replaceOption = options.item(ruleNr);
    alert(replaceOption);
    alert(optionNode);
    if(replaceOption) {
        replaceOption.getParentNode().replaceChild(optionNode, replaceOption);
    }

    window.opener.formdata_populate_options(fieldNode);

    window.close();
}

function formdata_validate_and_add_option() {
    if(! formdata_validate_options_dialog()) {
        return false
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
    window.open("/admin/?obvius_op=formdata_edit_option", "formdata_edit_option", "menubar=no,toolbar=no,scrollbars=yes,width=" + formdata_option_dialog_width + ",height=" + formdata_option_dialog_height);
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

    var typeNode = valruleNode.getElementsByTagName('validationtype').item(0);
    if(typeNode) {
        var typeVal = formdata_get_node_text(typeNode);
        if(typeVal == "regexp") {
            document.pageform.type.selectedIndex = 1;
        } else if(typeVal == "min_checked") {
            document.pageform.type.selectedIndex = 2;
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
            alert(formdata_translations['must_specify_arg_regexp']);
            return false;
        }
    } else if(typeVal == 'min_checked') {
        if(! arg || ! arg.match(/^\d+$/)) {
            alert(formdata_translations['must_specify_arg_min_checked']);
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
        return false
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
        return false
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
    window.open("/admin/?obvius_op=formdata_edit_validaterule", "formdata_edit_valrule", "menubar=no,toolbar=no,scrollbars=yes,width=" + formdata_valrule_dialog_width + ",height=" + formdata_valrule_dialog_height);
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
    firstElem.getParentNode().insertBefore(secondClone, firstElem)

    formdata_populate_fieldtable(name);
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
    firstElem.getParentNode().insertBefore(secondClone, firstElem)

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
    firstElem.getParentNode().insertBefore(secondClone, firstElem)

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


function formdata_objectify_node(node) {
    var obj = new Object();
    var children = node.getChildNodes();
    for(var i=0;i < children.getLength();i++) {
        var child = children.item(i);
        var content = child.getChildNodes().item(0);
        if(content && content.getNodeType() == 3) {
            obj[child.getNodeName()] = content.getXML();
        }
    }

    return obj;
}

function formdata_get_rootDoc_by_name(name) {
    if(! rootDocs[name]) {
        var formElem = document.pageform[name];
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
