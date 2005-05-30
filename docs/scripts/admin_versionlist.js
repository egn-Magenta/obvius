/* admin_versionlist.js - utility scripts for Obvius administration.

   Copyright (C) 2004-2005, Magenta ApS. By Adam Sjøgren. Under the GPL.

   $Id$
*/


/* Moves this windows opener to the current url with
   name=values{checked} added, and closes the current window: */
function obvius_open_selected(name, values) {
  var chosen='';
  for(var i=0; i<values.length; i++) {
    if (values[i].checked) {
      chosen=values[i].value;
    }
  }

  if (chosen) {
    window.opener.location.href='./?'+name+'='+chosen;
    window.close();
  }
  else {
    alert('Nothing chosen!');
  }

  return false;
}
