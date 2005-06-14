// Functions for integrating TinyMCE in Obvius

var obvius_tinymce_editor_baserefs = new Object;

function obvius_tinymce_get_dialogfield(field_name) {
    // First try to find the form element we need to put the found filename in:
    var field_ref = null;
    if(window.tinymce_dialogrefs) {
        for(var i in window.tinymce_dialogrefs) {
            var dialog = window.tinymce_dialogrefs[i];
            if(dialog.document && dialog.document.forms) {
                for(var j=0;j<dialog.document.forms.length;j++) {
                    var form = dialog.document.forms[j];
                    if(form[field_name]) {
                        field_ref = form[field_name];
                        break;
                    }
                }

                if(field_ref) {
                    break;
                }
            }
        }
    }

    return field_ref;
}

function obvius_tinymce_navigator_callback(field_name, url, type, win) {
  var nav_features = ('toolbar=0,location=0,directories=0,status=0,'
      +'menubar=0,scrollbars=1,resizable=1,copyhistory=0,'
      +'width=750,height=550');

  return obvius_tinymce_navigator_callback_p(field_name, url, type, 'obvius_op=navigator', nav_features, win);
}

/* This function performs the same task as the one above, only for the
   new administration system. Notice that Tiny MCE passes the
   window-object of the opening window as the last argument. (This is
   because window.opener is an odd thing, referring to the window that
   loaded the javascript that called open, not to the window that called
   the function that called open(!)) */
function obvius_tinymce_new_navigator_callback(field_name, url, type, win) {
  return obvius_tinymce_navigator_callback_p(field_name, url, type, 'obvius_app_navigator=1', 'width=700, height=432, status=yes', win); /* See mason/admin/portal/util/navigator_link_start */
}

function obvius_tinymce_navigator_callback_p(field_name, url, type, arg, options, win) {

    var start_url = tinyMCE.getParam('document_base_url');

    // Make URL relative to /
    start_url = start_url.replace(/^https?:\/\/[^\/]+/, "");

    if(url && url.charAt(0) == '/') {
        start_url = url;
        // Remove query string:
        start_url = start_url.replace(/\?.*$/, "");
        // Add last /:
        if(! url.match(/\/$/)) {
            start_url += "/";
        }
    }

    var doctype_extra = '';
    if(type == 'image') {
        doctype_extra = "&doctype=Image";
    }

    /* The win argument - window object of the opening window - is
       optional for compability with the previous use of Tiny MCE in
       Obvius: */
    if (!win) {
      win=window;
    }
    win.open('/admin/?' +arg + doctype_extra + '&fieldname=' + field_name + '&path=' + start_url, '', options); return false;

}

function obvius_tinymce_unhide_textarea_buttons() {
    var textareas = document.getElementsByTagName('textarea') || new Array();
    for(var i=0;i<textareas.length;i++) {
        var ta = textareas[i];
        if(ta.getAttribute('mce_editable')) {
            var button_elem = document.getElementById("obvius_" + ta.name + '_buttons');
            if(button_elem) {
                button_elem.style.display = 'block';
            }
        }
    }
}


function obvius_tinymce_html_cleanup(type, content) {

    if(type != "insert_to_editor") {
        return content;
    }

    var tmpContainer = document.createElement('div');

    tmpContainer.innerHTML = content;

    obvius_tinymce_removeUnusedAttribute(tmpContainer,"OL","style")
    obvius_tinymce_removeUnusedAttribute(tmpContainer,"UL","style")
    obvius_tinymce_removeUnusedAttribute(tmpContainer,"SPAN","lang")
    obvius_tinymce_removeUnusedAttribute(tmpContainer,"LI","style")
    obvius_tinymce_removeUnusedAttribute(tmpContainer,"P","class")
    obvius_tinymce_removeUnusedAttribute(tmpContainer,"P","style")
    obvius_tinymce_removeUnusedAttribute(tmpContainer,"FONT","face")
    obvius_tinymce_removeUnusedAttribute(tmpContainer,"FONT","style")
    obvius_tinymce_removeUnusedAttribute(tmpContainer,"FONT","size")
    obvius_tinymce_removeUnusedAttribute(tmpContainer,"SPAN","style")

    obvius_tinymce_replaceWordParagraphs(tmpContainer);

    obvius_tinymce_parseFrameInnerHTML(tmpContainer);

    obvius_tinymce_removeEmptyTags(tmpContainer);

    obvius_tinymce_removeMutipleNBSP(tmpContainer);

    // Fixup wrong placement of strong and b tags:
    obvius_tinymce_remove_wrong_span_type_tags(tmpContainer, 'b');
    obvius_tinymce_remove_wrong_span_type_tags(tmpContainer, 'strong');

    // Fixup <p> inside <caption> on tables:
    obvius_tinymce_fix_caption_p_tags(tmpContainer);

    content = tmpContainer.innerHTML;

    return content;

}


/* HTML cleaup helpers */

function obvius_tinymce_removeUnusedAttribute(rootElem, tag, attribute){
    /* Notice:
        This method cannot be used to remove the attributes: align, class, style or event handler!
        This is due to removeAttribute not wanting to remove those.
        Use element.className = '' to set an empty class.
    */

    tmpArray = rootElem.getElementsByTagName(tag)

    for(i=0;i<tmpArray.length;i++){
        tmpArray[i].normalize
        tmpArray[i].removeAttribute(attribute)
    }

}

function obvius_tinymce_replaceWordParagraphs(rootElem)
{
    /* Word has a nasty habit of using <P> of some class instead of the correct
        HTML tag. This method tries to do something about it.
    */
    var classMap = new Object();
    classMap["Hoved1"] = "h1";//Headings
    classMap["Hoved2"] = "h2";
    classMap["Hoved3"] = "h3";
    classMap["Hoved4"] = "h4";
    classMap["Citat"] = "cite";

    tmpArray = rootElem.getElementsByTagName("P");

    //Walk backwards through the array since we are modifying it as we go along
    for(i=tmpArray.length-1;i>=0;i--) {
        if (classMap[tmpArray[i].className] != null) {
            var newElem = document.createElement(classMap[tmpArray[i].className]);

            //Add all descendants of the old node to the new node
            var children = tmpArray[i].childNodes;
            for (n=0;n<children.length;n++) {
                nNode = children[n].cloneNode(true); //We need to clone the child because its removed later on
                newElem.appendChild(nNode);
            }

            tmpArray[i].parentNode.replaceChild(newElem, tmpArray[i]);
        }
    }
}

function obvius_tinymce_parseFrameInnerHTML(rootElem){

    strTmp = rootElem.innerHTML;

    strTmp = strTmp.replace(/<\?xml.*\/>/g,'')
    strTmp = strTmp.replace(/\s*mso-[^;"]*;*(\n|\r)*/g,'')
    strTmp = strTmp.replace(/\s*page-break-after[^;]*;/g,'')
    strTmp = strTmp.replace(/\s*tab-interval:[^'"]*['"]/g,'')
    strTmp = strTmp.replace(/\s*tab-stops:[^'";]*;?/g,'')
    strTmp = strTmp.replace(/\s*LETTER-SPACING:[^\s'";]*;?/g,'')
    strTmp = strTmp.replace(/\s*class=MsoNormal/g,'')
    strTmp = strTmp.replace(/\s*class=MsoBodyText[2345678]?/g,'')

    strTmp = strTmp.replace(/<o:p>/g,'')
    strTmp = strTmp.replace(/<\/o:p>/g,'')

    strTmp = strTmp.replace(/<v:[^>]*>/g,'')
    strTmp = strTmp.replace(/<\/v:[^>]*>/g,'')

    strTmp = strTmp.replace(/<w:[^>]*>/g,'')
    strTmp = strTmp.replace(/<\/w:[^>]*>/g,'')

    rootElem.innerHTML = strTmp;
}

function obvius_tinymce_removeEmptyTags(rootElem){
    var tmpArray, root, tmpArrayToRemove, j
    root = rootElem;
    tmpArrayToRemove = new Array()
    j = 0

    tmpArray = root.getElementsByTagName("P")
    for(i=0;i<tmpArray.length;i++){
        // We have to simulate MSIE innerText:
        var innerText = tmpArray[i].innerHTML + "";
        innerText = innerText.replace(/<[^>]+>/g,"");
        if(!tmpArray[i].childNodes[0] && (innerText == "" || innerText == " ")){
                tmpArrayToRemove[j] = tmpArray[i];
                j++
        }
    }
    for(i=0;i<tmpArrayToRemove.length;i++){
        tmpArrayToRemove[i].parentNode.removeChild(tmpArrayToRemove[i])
    }

    // Remove empty span tags
    strTmp = root.innerHTML;
    strTmp = strTmp.replace(/<\/?SPAN>/gi, '');
    // Remove _all_ font tags
    strTmp = root.innerHTML;
    strTmp = strTmp.replace(/<\/?font[^>]*>/gi, '');
    root.innerHTML = strTmp;
}

function obvius_tinymce_removeMutipleNBSP(rootElem){
    rootElem.innerHTML = rootElem.innerHTML.replace(/&nbsp;&nbsp;/g,"")
}

// Fixes spans being placed around block and table tags
function obvius_tinymce_remove_wrong_span_type_tags(rootElem, tagName) {
    var keepGoing = 1;
    var last_run = 0;
    while(keepGoing) {
        var tags = rootElem.getElementsByTagName(tagName);

        // Do a check to avoid endless loops
        // If the number of tags from last run doesn't differ from this one
        // break out:
        var this_run = tags.length || 0;
        if(this_run == last_run) {
            break;
        } else {
            last_run = this_run;
        }

        var fixNode;
        for(var i=0;i<tags.length;i++) {
            var tagElem = tags[i];

            if(tagElem.childNodes.length) {
                for(var j=0;j<tagElem.childNodes.length;j++) {
                    var childNode = tagElem.childNodes[j];
                    if(childNode.tagName && childNode.tagName.match(/^p|h\d|table$/i)) {
                        fixNode = tagElem;
                        break;
                    }
                }
            } else {
                // Element have no childnodes, so just remove it:
                tagElem.parentNode.removeChild(tagElem);
                break;
            }

            // If we get here, we're done
            keepGoing = 0;
        }

        if(fixNode) {
            // If the parent is not set on the node it must be the rootelem
            var parent = fixNode.parentNode;
            if(parent) {
                for(var j=0;j<fixNode.childNodes.length;j++) {
                    // Insert a clone of the current node before the tag we want to remove
                    parent.insertBefore(fixNode.childNodes[j].cloneNode(true), fixNode);
                }
                // Remove the tag and all it's children
                parent.removeChild(fixNode);
            } else {
                alert(oldNode.tagName + ": " + oldNode.innerHTML + " has no parent");
            }
        }
    }
}

function obvius_tinymce_fix_caption_p_tags(rootElem) {
    var captions = rootElem.getElementsByTagName('caption');
    if(captions) {
        for(var i=0;i<captions.length;i++) {
            var caption = captions[i];
            var paragraphs = caption.getElementsByTagName('p');
            if(paragraphs) {
                for(var j=0;j<paragraphs.length;j++) {
                    var paragraph = paragraphs[j];
                    for(var k=0;k<paragraph.childNodes.length;k++) {
                        paragraph.parentNode.insertBefore(paragraph.childNodes[k].cloneNode(true), paragraph);
                    }
                    paragraph.parentNode.removeChild(paragraph);
                }
            }
        }
    }
}
