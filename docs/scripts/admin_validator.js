/* admin_validator.js - javascript-functions for the validator app,
                        part of the Obvius administration interface.

   Copyright (C) 2005, Magenta ApS. By Adam Sjøgren. Under the GPL.

   Inspired by the example functions for handling XMLHttp on:
    <http://developer.apple.com/internet/webcontent/xmlhttpreq.html>
   Thanks Apple.

   $Id$
*/

var validator_req;

function obvius_validator_validate(html) {
  /* Ask "webservice" to validate: */
  var url='./?obvius_app_validator=1&fromeditor=1&html='+escape(html);

  /* branch for native XMLHttpRequest object */
  if (window.XMLHttpRequest) {
    obvius_validator_start_fetch_notify();
    validator_req = new XMLHttpRequest();
    validator_req.onreadystatechange = obvius_validator_validate_process;
    validator_req.open("GET", url, true);
    validator_req.send(null);
    return;
  /* branch for IE/Windows ActiveX version */
  } else if (window.ActiveXObject) {
    obvius_validator_start_fetch_notify();
    validator_req = new ActiveXObject("Microsoft.XMLHTTP");
    if (validator_req) {
      validator_req.onreadystatechange = obvius_validator_validate_process;
      validator_req.open("GET", url, true);
      validator_req.send();
      return;
    }
  }

  /* Open a new window with a validation-thing if the browser in
     question does not support XMLHttpRequest at all: */
  window.open(url);
}

function obvius_validator_start_fetch_notify() {
  window.status="Validating HTML...";
}

function obvius_validator_validate_process() {
  /* only if validator_req shows "loaded" */
  if (validator_req.readyState == 4) {
    /* only if "OK" */
    if (validator_req.status == 200) {
      obvius_validator_show_response(validator_req.responseXML);
    } else {
      alert("There was a problem retrieving the XML data:\n" +
            validator_req.statusText);
    }
  }
}

function obvius_validator_show_response(xmldoc) {
  /* Check input: */
  var top=xmldoc.getElementsByTagName('validation');
  if (top.length==0) {
    alert("Malformed validation-response information received from server:\n\nTell the programmer. Thanks.");
  }

  /* Extract status: */
  var statuselts=xmldoc.getElementsByTagName('status');
  var status=statuselts[0].firstChild.nodeValue;

  var text="W3C XHTML 1.0 validation\n\nResult: "+status+"\n\n";

  if (status=='Valid') {
    text=text+"Congratulations.";
  }
  else if (status=='Unknown') {
    text=text+"The server probably hasn't got the relevant validator-programme installed.\nSorry.";
  }
  else {
    /* If status isn't Valid, get number of errors: */
    var errorcountelts=xmldoc.getElementsByTagName('errorcount');
    var errorcount=errorcountelts[0].firstChild.nodeValue;
    text=text+" Total number of errors: "+errorcount+"\n\n";

    /* Get first 10 messages: */
    var msgs=xmldoc.getElementsByTagName('msg');
    var last=msgs.length;

    if (last>10) {
      text=text+"First 10 errors:\n";
      last=10;
    }
    for (var i=0; i<last; i++) {
      text=text+'  '+(1+i)+': '+msgs[i].firstChild.nodeValue+"\n";
    }
  }

  alert(text);

  window.status="Done";
}
