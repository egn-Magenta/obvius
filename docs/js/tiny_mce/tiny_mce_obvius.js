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

function obvius_tinymce_navigator_callback(field_name, url, type) {

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

    var nav_features = ('toolbar=0,location=0,directories=0,status=0,'
        +'menubar=0,scrollbars=1,resizable=1,copyhistory=0,'
        +'width=750,height=550');


    window.open('/admin/?obvius_op=navigator' + doctype_extra + '&fieldname=' + field_name + '&path=' + start_url, '', nav_features); return false;

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
        if(innerText == "" || innerText == " "){
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
