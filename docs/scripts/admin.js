/* admin.js - utility scripts for Obvius administration.

   Copyright (C) 2004-2005, Magenta ApS. By Adam Sjøgren. Under the GPL.

   $Id$
*/

function obvius_display_toggle(elementid) {
  var elt=document.getElementById(elementid);

  var on='block';
  if (elt.nodeName=="SPAN") { on='inline'; };

  if (elt) {
    if (elt.style.display!=on) {
      elt.style.display=on;
    }
    else {
      elt.style.display='none';
    }
  }

  return false;
}

/* obvius_display_off - sets the display-style to 'none'. The argument
                        can be either a string or an array of
                        strings. Returns false. */
function obvius_display_off(elementid) {
  if (typeof elementid == 'object') {
    for(var i=0; i<elementid.length; i++) {
      obvius_display_off(elementid[i]);
    }
  }
  else { /* string */
    var elt=document.getElementById(elementid);

    if (elt) {
      if (elt.style.display!='none') {
        elt.style.display='none';
      }
    }
  }

  return false;
}

function obvius_display_on(elementid) {
  if (typeof elementid == 'object') {
    for(var i=0; i<elementid.length; i++) {
      obvius_display_on(elementid[i]);
    }
  }
  else { /* string */
    var elt=document.getElementById(elementid);
    if (!elt) {
      alert('No element with id '+elementid);
      return false;
    }

    var on='block';
    if (elt.nodeName=="SPAN") { on='inline'; };

    if (elt) {
      if (elt.style.display!=on) {
        elt.style.display=on;
      }
    }
  }
  return false;
}

/* Window-opener: */
function obvius_open_window(url, name) {
  /* Default options: */
  var options=new Object;
  options['width']=260;
  options['height']=350;
  options['status']='no';
  options['resizable']='yes';
  options['scrollbars']='yes';
  options['dependent']='yes';

  /* Gather any extra incoming options: */
  for(var i=2; i<arguments.length; i++) {
    var arg=arguments[i].split('=');
    options[arg[0]]=arg[1];
  }

  /* Construct options string: */
  var options_array=new Array();
  for (option in options) {
    options_array.push(option+'='+options[option]);
  }
  var options_string=options_array.join(', ');

  var new_window=window.open(url, name, options_string);

  return false;
}

/*********** Editing functions ***************/
function obvius_goto_editpage(editpageid, all_ids) {
  if (!all_ids) { return true; } /* Do nothing */

  if (editpageid=='obvius-edit-page-A') { /* The special case; all fields */
    obvius_display_on(all_ids);
    var none=new Array();
    for (var i=0; i<all_ids.length; i++) {
      obvius_set_current_edittab(all_ids[i], none);
    }

    /* Update prev/next buttons */
    obvius_set_inactive_prevnext_buttons(editpageid, all_ids);

    return false;
  }

  var hide_ids=new Array();
  for(var i=0; i<all_ids.length; i++) {
    if (all_ids[i]!=editpageid) {
      hide_ids.push(all_ids[i]);
    }
  }

  /* Display only the selected editpageid: */
  obvius_display_on(editpageid);
  obvius_display_off(hide_ids);

  /* Update the styles on the tabs: */
  obvius_set_current_edittab(editpageid, hide_ids);

  /* Update prev/next buttons */
  obvius_set_inactive_prevnext_buttons(editpageid, all_ids);

  return false;
}


function obvius_goto_prevpage(all_ids) {
  return obvius_goto_deltapage(all_ids, -1);
}

function obvius_goto_nextpage(all_ids) {
  return obvius_goto_deltapage(all_ids, +1);
}

function obvius_goto_deltapage(all_ids, delta) {
  var current=obvius_current_pageid(all_ids);
  if (current) {
    var num=get_trailing_num(current);
    num=parseInt(num)+parseInt(delta);
    if (num>0 && num<=all_ids.length) {
      obvius_goto_editpage('obvius-edit-page-'+num, all_ids); /* XXX prefix */
    }
  }
}

function obvius_set_inactive_prevnext_buttons(current, all_ids) {
  var last=all_ids.length-1;

  /* Start: */
  if (current==all_ids[0]) {
    obvius_inactivate_buttons('obvius-prev');
    obvius_activate_buttons('obvius-next');
    return;
  }

  /* End: */
  if (current==all_ids[last]) {
    obvius_activate_buttons('obvius-prev');
    obvius_inactivate_buttons('obvius-next');
    return;
  }

  /* Special case, All: */
  if (current=='obvius-edit-page-A') {
    obvius_inactivate_buttons('obvius-prev');
    obvius_inactivate_buttons('obvius-next');
    return;
  }

  /* Otherwise: */
  obvius_activate_buttons('obvius-prev');
  obvius_activate_buttons('obvius-next');
}

function obvius_inactivate_buttons(cssclass) {
  obvius_change_buttons(cssclass, "true", cssclass+" obvius-disabled");
}

function obvius_activate_buttons(cssclass) {
  obvius_change_buttons(cssclass, "", cssclass);
}

function obvius_change_buttons(cssclass, disabled, setcssclass) {
  var buttons=document.getElementsByTagName('BUTTON');
  for(var i=0; i<buttons.length; i++) {
    if (buttons[i].className.substr(0, cssclass.length)==cssclass) {
      buttons[i].disabled=disabled;
      /* MSIE seems not to actually apply the classes when
         .setAttribute is used, so assign to .className instead: */
      /*   buttons[i].setAttribute("class", setcssclass); */
      buttons[i].className=setcssclass;
    }
  }
}

function obvius_current_pageid(all_ids) {
  var current;
  var found=0;
  for(var i=0; i<all_ids.length; i++) {
    var elt=document.getElementById(all_ids[i]);
    if (elt.style.display!='none') {
      current=all_ids[i];
      found++;
    }
  }

  return(found==1 ? current : null);
}

function obvius_set_style(id, style) {
  var elt=document.getElementById(id);
  if (!elt) { return false; }

  return elt.className=style;
}

function obvius_set_current_edittab(editpageid, hide_ids) {
  var id_start='obvius-edit-tab-'; /* XXX See mason/admin/portal/editing */

  for(var i=0; i<hide_ids.length; i++) {
    var num=get_trailing_num(hide_ids[i]);
    var style=(num=='1' ? 'obvius-first-child' : '');
    obvius_set_style(id_start+num, style);
  }

  var current_style=(editpageid=='obvius-edit-page-1' ? 'obvius-current obvius-first-child' : 'obvius-current');
  obvius_set_style(id_start+get_trailing_num(editpageid), current_style);
}

function get_trailing_num(string) {
  var num=string.match(/(\w+)$/);

  return num[0];
}

function obvius_update_seq() {


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

function start_ror_navigator(url, path, fallback_uri, field_name) {
    var elem = document.getElementById(field_name);
    if (elem) {
        if (elem.value) {
            path = elem.value;
        } else {
            path = fallback_uri;
        }
    }
    
    if (path) {
        path = escape(path);
        url += "&path=" + path;
    }
    return window.open(url, 'navigator','resizable=1,width=1150,height=500');
}

$(function(){
    $("form").on("submit", function(){
        var form = $(this);
        form.find("input[type=checkbox]").each(function(){
            if (this.checked && this.name) {
                form.find("input.checkboxmirror[type=hidden][name='"+this.name+"']").attr("disabled","disabled");
            }
        });
    });
});

function show_hide_fields(checkbox_source) {
    var do_show = checkbox_source.checked;
    var fields = checkbox_source.getAttribute("data-dependent-fields").split("|");
    var edit_key_prefix = "edit_.key::KRAKOW._save:editengine_value:key::KRAKOW:";
    for (var i = 0; i < fields.length; i++) {
        var editengine_field = document.getElementById(edit_key_prefix + fields[i]);
        if (!editengine_field) {
            editengine_field = document.getElementById(fields[i]); // some input fields do not have edit_key_prefix
        }
        if (!editengine_field) {
            console.log("Could not find input field " + fields[i]);
            continue;
        }
        var editengine_parent = editengine_field.parentNode;
        if (do_show) {
            editengine_field.value = editengine_field.value.replace("0000-00-00", ""); // remove placeholder date for optional field
            editengine_parent.classList.remove("hidden");
        } else {
            if (editengine_field.value === "") {
              editengine_field.value = "0000-00-00";
            }
            editengine_parent.classList.add("hidden");
        }
    }
}

window.addEventListener("load", function() {
    var control_checkboxes = document.querySelectorAll('input[data-dependent-fields][type="checkbox"]:not([data-dependent-fields=""])');
    for (var i = 0; i < control_checkboxes.length; i++) {
        show_hide_fields(control_checkboxes[i]);
    }
});

function wrap_edit_fields_in_accordion(startField, additionalFields, header, non_bootstrap) {
  var startFieldNode = document.querySelector('[name="' + startField + '"]');
  if (!startFieldNode) {
    console.log("Couldn't find " + startField);
    return;
  }
  var additionalFieldNodes = [];
  for (var i = 0; i < additionalFields.length; i++) {
    var additionalFieldNode = document.querySelector('[name="' + additionalFields[i] + '"]');
    if (!additionalFieldNode) {
      console.log("Couldn't find " + additionalFields[i]);
      return;
    }
    additionalFieldNodes.push(additionalFieldNode.parentNode);
  }
  var id = new Date().getTime();
  var editengine_field = startFieldNode.parentNode;
  var accordionHtml;
  if (non_bootstrap) {
    accordionHtml = generate_old_accordion_html(id, header, editengine_field.outerHTML);
  } else {
    accordionHtml = generate_accordion_html(id, header, editengine_field.outerHTML);
  }
  editengine_field.outerHTML = accordionHtml;

  var editFieldParentDivSelector;
  var editFieldContentSelector;
  if (non_bootstrap) {
    editFieldParentDivSelector = "#accordion-" + id;
    editFieldContentSelector = "#content-" + id;
  } else {
    editFieldParentDivSelector = "#editfield-parent-" + id;
  }
  var editFieldParentDiv;
  if (non_bootstrap) {
    editFieldParentDiv = document.querySelector(editFieldContentSelector);
  } else {
    editFieldParentDiv = document.querySelector(editFieldParentDivSelector);
  }
  for (var j = 0; j < additionalFieldNodes.length; j++) {
    editFieldParentDiv.appendChild(additionalFieldNodes[j]);
  }
  return editFieldParentDivSelector; // DOM ID of accordion content
}

var generate_accordion_html = function(id, header, content) {
  return '<div class="panel panel-accordion">' +
      '    <div class="panel-heading" role="tab" id="heading-' + id + '">' +
      '        <h4 class="panel-title">' +
      '            <a class="collapsed bootstrap-accordion-title"' +
      '                role="button" data-toggle="collapse"' +
      '                href="#collapse-' + id + '"' +
      '                aria-expanded="false"' +
      '                aria-controls="collapse-' + id + '">' + header +
      '                </a>' +
      '        </h4>' +
      '    </div>' +
      '    <div id="collapse-' + id + '"' +
      '        class="panel-collapse collapse"' +
      '        role="tabpanel"' +
      '        aria-expanded="false"' +
      '        aria-labelledby="heading-' + id + '">' +
      '        <div class="panel-body bootstrap-accordion-content" id="editfield-parent-' + id + '">' +
                  content +
      '        </div>' +
      '    </div>' +
      ' </div>';
};

var generate_old_accordion_html = function(id, header, content) {
  return '<div id="accordion-' + id + '">' +
      '<h3>' + header + '</h3>' +
      '<div id="content-' + id + '">' + content + '</div>'+
      '</div>';
};