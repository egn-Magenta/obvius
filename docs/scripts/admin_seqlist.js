/* admin_seqlist.js - functions for the sequence list app.

   Copyright (C) 2005, Magenta ApS. By Adam Sjøgren. Under the GPL.

   $Id$
*/

/* Transfer the selected value to the field in the original window: */
function obvius_seqlist_save_and_close(value, fieldname) {
  /* Look through the forms, insert into fields with the right name: */
  var found=0;
  for(var i=0; i<window.opener.document.forms.length; i++) {
    if (window.opener.document.forms[i][fieldname]) {
      window.opener.document.forms[i][fieldname].value=value;
      /* Update the radiobuttons: */
      var radiolist=window.opener.document.forms[i][fieldname+'_radio'];
      for (var j=0; j<radiolist.length; j++) {
        if ( (value>=0 && j==0) || (value<0 && j==1) ) {
          radiolist[j].value=value;
          radiolist[j].checked=true;
        }
        else {
          radiolist[j].checked=false;
        }
      }

      found++;
    }
  }
  if (found!=1) {
    alert("The value from the sequence list was inserted in "+found+" places ("+fieldname+"), which is probably wrong.\n\nTell the programmer (feedback@magenta-aps.dk). Thanks.");
  }

  window.close();

  return false;
}
