/* admin_newsboxes.js - javascript-functions for newsboxes in the
                        Obvius administration interface.

   Copyright (C) 2004-2005, Magenta ApS. By Adam Sjøgren. Under the GPL.

   $Id$
*/

/* newsbox_click - to be called from onclick on the newsbox-checkboxes
                   with the checkbox' id as argument. If the box is
                   now checked, unfold the info-div below, otherwise
                   hide it. */
function newsbox_click(elementid) {
  var elt=document.getElementById(elementid);

  if (elt.checked) {
    return obvius_display_on(elementid+'_info');
  }
  else {
    return obvius_display_off(elementid+'_info');
  }
}

function news_up(num) {
  if (num==1) {
    alert("Can't move top item up, sorry.");
    return false;
  }

  news_swap(num-1, num);

  return false;
}

function news_down(num) {
  var nextnum=num+1;
  if (!document.getElementById('newsitem_'+nextnum)) {
    alert("Can't move last item down, sorry.");
    return false;
  }

  news_swap(num, nextnum);

  return false;
}

function news_swap(a, b) {
  var elta;
  var eltb;
  var tmp;

  /* swap label: */
  elta=document.getElementById('newsitem_label_'+a);
  eltb=document.getElementById('newsitem_label_'+b);

  tmp=elta.firstChild.nodeValue;
  elta.firstChild.nodeValue=eltb.firstChild.nodeValue;
  eltb.firstChild.nodeValue=tmp;

  /*  swap link: */
  tmp=elta.href;
  elta.href=eltb.href;
  eltb.href=tmp;

  news_swap_value('newsitem_'+a, 'newsitem_'+b);
  news_swap_value('start_'+a, 'start_'+b);
  news_swap_value('end_'+a, 'end_'+b);
}

function news_swap_value(aid, bid) {
  elta=document.getElementById(aid);
  eltb=document.getElementById(bid);
  tmp=elta.value;
  elta.value=eltb.value;
  eltb.value=tmp;
}

function news_delete(num) {
  var elt;

  /* Reset everything here: */
  elt=document.getElementById('newsitem_'+num);
  elt.value='';
  elt=document.getElementById('newsitem_label_'+num);
  elt.firstChild.nodeValue='';
  elt.href='';
  elt=document.getElementById('start_'+num);
  elt.value='';
  elt=document.getElementById('end_'+num);
  elt.value='';

  /* Move anything below up one notch: */
  var i=num;
  var eltb;
  i++;
  while(eltb=document.getElementById('newsitem_'+i)) {
    news_swap(i-1, i);
    i++;
  }

  return false;
}
