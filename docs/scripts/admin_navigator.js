/* admin_navigator.js - javascript-functions for the navigator app,
                        part of the Obvius administration interface.

   Copyright (C) 2005, Magenta ApS. By Adam Sjøgren. Under the GPL.

   Inspired by the example functions for handling XMLHttp on:
    <http://developer.apple.com/internet/webcontent/xmlhttpreq.html>
   Thanks Apple.

   $Id$
*/

/*** subdocs: ***/
var subdocs_req;

var subdocs_id;
var subdocs_uri;

function obvius_navigator_toggle(uri, id) {
  var current_document_elt=document.getElementById(id);

  /* Check if we need to unfold or fold (check whether the last
     element, that is not #text, is an UL): */
  var node=current_document_elt.lastChild;
  var lastnodename=node.nodeName;
  while (lastnodename=='#text' && (node=node.previousSibling)) {
    lastnodename=node.nodeName;
  }
  if (lastnodename=='UL') {
    obvius_navigator_fold(id);
  }
  else {
    obvius_navigator_unfold(uri, id);
  }
}

function obvius_navigator_unfold(uri, id) {
  subdocs_id=id; /* Euw, global variables - how to I tell onreadystatechange to pass this? */
  subdocs_uri=uri;

  /* Fetch subdocs from "webservice": */
  var url='./?obvius_app_subdocs=1&url='+uri;

  /* branch for native XMLHttpRequest object */
  if (window.XMLHttpRequest) {
    obvius_navigator_start_fetch_notify(id);
    subdocs_req = new XMLHttpRequest();
    subdocs_req.onreadystatechange = obvius_navigator_unfold_process;
    subdocs_req.open("GET", url, true);
    subdocs_req.send(null);
  /* branch for IE/Windows ActiveX version */
  } else if (window.ActiveXObject) {
    obvius_navigator_start_fetch_notify(id);
    subdocs_req = new ActiveXObject("Microsoft.XMLHTTP");
    if (subdocs_req) {
      subdocs_req.onreadystatechange = obvius_navigator_unfold_process;
      subdocs_req.open("GET", url, true);
      subdocs_req.send();
    }
  }
}

function obvius_navigator_start_fetch_notify(id) {
  window.status="Fetching subdocuments...";
  /* Turn the arrow: */
  var current_document_elt=document.getElementById(id);
  current_document_elt.firstChild.src="/pics/icons/processing.gif";
}

function obvius_navigator_unfold_process() {
  /* only if subdocs_req shows "loaded" */
  if (subdocs_req.readyState == 4) {
    /* only if "OK" */
    if (subdocs_req.status == 200) {
      obvius_navigator_unfold_update_tree(subdocs_req.responseXML, subdocs_id, subdocs_uri);
    } else {
      alert("There was a problem retrieving the XML data:\n" +
            subdocs_req.statusText);
    }
  }
}

function obvius_navigator_unfold_update_tree(xmldoc, id, uri) {
  /* Check input: */
  var top=xmldoc.getElementsByTagName('documents');
  if (top.length==0) {
    alert("Malformed subdocuments information received from server:\n\n"+uri+"\n\nTell the programmer. Thanks.");
  }

  /* Extract documents: */
  var newdocuments=new Array();

  var documents=xmldoc.getElementsByTagName('document');
  for(var i=0; i<documents.length; i++) {
    var newdocument=new Object;
    for(var j=0; j<documents[i].childNodes.length; j++) {
      if (documents[i].childNodes[j].firstChild) {
        newdocument[documents[i].childNodes[j].nodeName]=documents[i].childNodes[j].firstChild.nodeValue;
      }
    }
    newdocuments.push(newdocument);
  }

  var current_document_elt=document.getElementById(id);

  if (newdocuments.length==0) {
    /* Turn the arrow back: */
    current_document_elt.firstChild.src="/pics/icons/right.png";
    return;
  }

  /* There is no ul-element-child, create one: */
  var newul=document.createElement('ul');
  current_document_elt.appendChild(newul);
  var ul=current_document_elt.lastChild;

  /* Add documents to the DOM: */
  var delta=(current_document_elt.getAttribute('class')=='obvius-a' ? 1 : 0); /* Make colours alternate (from the top) */
  var hrefargs=obvius_navigator_get_arguments(current_document_elt); /* Copy arguments */
  for(var i=0; i<newdocuments.length; i++) {
    obvius_navigator_add_subdoc(newdocuments[i], current_document_elt, ul, i+delta, hrefargs);
  }

  current_document_elt.firstChild.src="/pics/icons/down.png";
  window.status="Done";
}

function obvius_navigator_add_subdoc(subdoc, current_document_elt, ul, i, hrefargs) {
  /* Then add the subdoc as the last li-element-child: */
  var newimg=document.createElement('img');
  newimg.setAttribute('width', 7);
  newimg.setAttribute('height', 7);
  /* Only add a right-arrow if there are subdocs: */
  if (subdoc.subnum>0) {
    newimg.setAttribute('src', '/pics/icons/right.png');
    newimg.setAttribute('alt', '->');
    /* This is instead of just setting the onclick-attribute, because that doesn't work in MSIE: */
    newimg.onclick=new Function("", "obvius_navigator_toggle('"+subdoc.url+"', 'obvius-tree-"+subdoc.id+"');");
  }
  else {
    newimg.setAttribute('src', '/pics/icons/none.png');
    newimg.setAttribute('alt', '');
  }

  var newa=document.createElement('a');
  newa.setAttribute('href', '/admin'+subdoc.url+hrefargs); /* XXX $prefix */
  var newtext=document.createTextNode(subdoc.title);
  newa.appendChild(newtext);

  var newli=document.createElement('li');
  newli.setAttribute('id', 'obvius-tree-'+subdoc.id);
  if (i++%2) {
    newli.setAttribute('class', 'obvius-b');
  }
  else {
    newli.setAttribute('class', 'obvius-a');
  }
  newli.appendChild(newimg);
  newli.appendChild(newa);

  ul.appendChild(newli);
}

function obvius_navigator_get_arguments(current_document_elt) {
  for(var i=0; i<current_document_elt.childNodes.length; i++) {
    if (current_document_elt.childNodes[i].nodeName=='A') {
      var hrefparts=current_document_elt.childNodes[i].href.split(/\?/);
      return('?'+hrefparts[1]);
    }
  }
  return '?obvius_app_navigator=1&fieldname=href'; /* Fallback */
}

function obvius_navigator_fold(id) {
  var current_document_elt=document.getElementById(id);

  /* Recursively delete ul and all it's spawn: */
  while (current_document_elt.lastChild.nodeName=='UL' ||
         current_document_elt.lastChild.nodeName=='#text') {
    current_document_elt.removeChild(current_document_elt.lastChild);
  }

  /* Turn the arrow: */
  current_document_elt.firstChild.src="/pics/icons/right.png";
}

/*** passing info back: ***/
function obvius_navigator_done(selected) {
  if (obvius_navigator_fieldname!='') {
    /* Transfer the selected value to the field in the original window: */
    
    /* Look through the forms, insert into fields with the right name: */
    var found=0;
    for(var i=0; i<window.opener.document.forms.length; i++) {
      if (window.opener.document.forms[i][obvius_navigator_fieldname]) {
        window.opener.document.forms[i][obvius_navigator_fieldname].value=selected;
        found++;
      }
    }
    if (found!=1) {
      alert("The path from the navigator was inserted in "+found+" places ("+obvius_navigator_fieldname+"), which is probably wrong.\n\nTell the programmer (feedback@magenta-aps.dk). Thanks.");
    }
  }
  else {
    /* Go to selection in the original window: */
    window.opener.location.href='/admin'+selected;
  }

  /* Close navigator: */
  window.close();

  return false;
}


/*** search: ***/
function obvius_navigator_search(q) {
  /* Assumes that /soeg/ is a DBSearch-document: */
  window.opener.location.href='/admin/admin/search/?op=dbsearch&field1=title&how1=contain&data1='+escape(q);
  window.close();
  return false;
}
