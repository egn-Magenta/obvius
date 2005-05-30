/* admin_categories.js - utility script for category editing

   Copyright (C) 2005, Magenta ApS. By Adam Sjøgren. Under the GPL.

   $Id$
*/

function obvius_insert_category_subcategory_widget(prefix, name, categories, addlabel, removelabel) {
  obvius_insert_dropdown(name+'_top_level', 'onchange="javascript:obvius_fill_in_filtered(\''+name+'_sub_level\', obvius_internal_data_'+name+', \''+name+'_top_level\'); return false;"');
  obvius_insert_dropdown(name+'_sub_level', '', '');
  obvius_insert_button('onclick="javascript:obvius_add_selected_to_multiple(\''+name+'_sub_level\', \''+name+'_show_selected\', \''+prefix+name+'\'); return false;"', addlabel);
  obvius_insert_multiple(name+'_show_selected', '');
  obvius_insert_multiple_shadow(prefix+name);
  obvius_insert_button('onclick="javascript:obvius_remove_selected(\''+name+'_show_selected\', \''+prefix+name+'\'); return false;"', removelabel);

  var top_level_categories=obvius_top_level(categories);
  obvius_fill_in(name+'_top_level', top_level_categories);

  obvius_fill_in_filtered(name+'_sub_level', categories, name+'_top_level');

  obvius_fill_in_selected(name+'_show_selected', prefix+name, categories);
}

function obvius_insert_dropdown(name, attributes, post) {
  if (post==null) { post='</div>'; }
  document.write('<div><select name="'+name+'" '+attributes+'></select>'+post);
}

function obvius_insert_button(attributes, label) {
  document.write('<button '+attributes+'>'+label+'</button></div>');
}

function obvius_insert_multiple(name, post) {
  if (post==null) { post='</div>'; }
  document.write('<div><select name="'+name+'" multiple="multiple" size="8"></select>'+post);
}

function obvius_insert_multiple_shadow(name) {
  document.write('<div class="obvius-field-shadow"><select name="'+name+'" multiple="multiple"></select></div>');
}

function obvius_add_selected_to_multiple(selected_name, show_selected_name, multiple_name) {
  var selected=obvius_find_field(selected_name);
  var show_selected=obvius_find_field(show_selected_name);
  var multiple=obvius_find_field(multiple_name);

  /* Check if it is already there: */
  for(var i=0; i<multiple.options.length; i++) {
    if (multiple.options[i].value==selected.value) {
      /* alert(selected.value+' is already selected'); */
      return null;
    }
  }

  /* It is not there, so let us add it: */
  var option=new Option(selected.options[selected.selectedIndex].text, selected.value);
  show_selected.options[show_selected.options.length]=option;

  /* ... and shadow: */
  option=new Option(selected.options[selected.selectedIndex].text, selected.value, 1, 1);
  multiple.options[multiple.options.length]=option;

}

function obvius_remove_selected(show_name, name) {
  var show_field=obvius_find_field(show_name);
  var field=obvius_find_field(name);

  var result=new Array();
  for(var i=0; i<show_field.options.length; i++) {
    if (!show_field.options[i].selected) {
      /* Keep it: */
      var option=new Option(show_field.options[i].text, show_field.options[i].value);
      result.push(option);
    }
  }

  /* Any changes? */
  if (result.length!=show_field.options.length) {
    /* Ok, then update: */
    show_field.options.length=0;
    for(var i=0; i<result.length; i++) {
      show_field.options[show_field.options.length]=result[i];
    }

    field.options.length=0;
    for(var i=0; i<result.length; i++) {
      field.options[field.options.length]=new Option(result[i].text, result[i].value, 1, 1);
    }
  }
}


function obvius_top_level(categories) {
  var top_level=new Array;
  for(var i=0; i<categories.length; i++) {
    var parts=categories[i].id.split(/\s+/);
    if (parts.length==1) {
      top_level.push(categories[i]);
    }
  }

  return top_level;
}

function obvius_fill_in(name, options, selected, do_select) {
  var field=obvius_find_field(name);
  if (!field) {
    alert('Could not locate field: '+name+' in any form!');
    return null;
  }

  for(var i=0; i<options.length; i++) {
    var option=null;
    if (selected) {
      if (options[i].selected) {
        if (do_select) {
          option=new Option(options[i].id+' - '+options[i].name, options[i].id, 1, 1);
        }
        else {
          option=new Option(options[i].id+' - '+options[i].name, options[i].id);
        }
      }
    }
    else {
      option=new Option(options[i].id+' - '+options[i].name, options[i].id);
    }
    if (option!=null) {
      field.options[field.options.length]=option;
    }
  }
}

function obvius_fill_in_selected(show_name, name, options) {
  obvius_fill_in(show_name, options, 1, 0);
  obvius_fill_in(name, options, 1, 1);
}

function obvius_fill_in_filtered(name, options, filter) {
  var field=obvius_find_field(name);
  var filter_field=obvius_find_field(filter);

  /* Reset options: */
  field.options.length=0;
  var filtered_options=new Array();
  for(var i=0; i<options.length; i++) {
    if (options[i].id.substr(0, filter_field.value.length)==filter_field.value) {
      filtered_options.push(options[i]);
    }
  }

  return obvius_fill_in(name, filtered_options);
}


function obvius_find_field(name) {
  for(var i=0; i<document.forms.length; i++) {
    if (document.forms[i][name]) {
      return (document.forms[i][name]);
    }
  }

  alert('Could not locate field: '+name+'in any form!');
  return null;
}
