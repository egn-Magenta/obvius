//obvius_<% $name %>_editor
//obvius_<% $name %>_html

function parseFrameInnerHTML(editNbr){
	var tmpFrame, tmpFmElement
	tmpFrame = eval("obvius_"+editNbr+"_editor")
	tmpFmElement = eval("'obvius_"+editNbr+"_html'")
	
	strTmp = tmpFrame.document.body.innerHTML

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
	
	tmpFrame.document.body.innerHTML = strTmp;
	//document.forms[0].elements[tmpFmElement].value = strTmp;
}

function fixInternalAnchorLinks(editNbr){
	var tmpFrame, tmpFmElement, tmpArrayA, root, tmpHref
	
	tmpFrame = eval("obvius_"+editNbr+"_editor")
	tmpFmElement = eval("'obvius_"+editNbr+"_html'")
	root = tmpFrame.document.documentElement.lastChild;
	
	tmpArrayA = root.getElementsByTagName("A")

	for(i=0;i<tmpArrayA.length;i++){
		tmpArrayA[i].normalize
		if(tmpArrayA[i].getAttribute("href").indexOf(tmpFrame.location.href)!= -1){
			tmpHref = tmpArrayA[i].getAttribute("href").substring(tmpArrayA[i].getAttribute("href").indexOf('#'))
			tmpArrayA[i].removeAttribute("href")
			tmpArrayA[i].setAttribute("href",tmpHref)
		}
	}
}


function fixInternalLinks(editNbr, doc_uri){
	// Always fix these first!
	fixInternalAnchorLinks(editNbr);
	
	var tmpFrame, tmpFmElement, tmpArrayA, root, tmpHref
	
	tmpFrame = eval("obvius_"+editNbr+"_editor")
	tmpFmElement = eval("'obvius_"+editNbr+"_html'")
	root = tmpFrame.document.documentElement.lastChild;

	var editor_href = tmpFrame.location.href;
	editor_href = editor_href.replace(/iframeSource\.html$/, '');
	
	tmpArrayA = root.getElementsByTagName("A")

	for(i=0;i<tmpArrayA.length;i++){
		tmpArrayA[i].normalize
		if(tmpArrayA[i].getAttribute("href").indexOf(editor_href)!= -1){
			tmpHref = tmpArrayA[i].getAttribute("href");
			tmpHref = tmpHref.replace(editor_href, '');
			tmpArrayA[i].removeAttribute("href")
			tmpArrayA[i].setAttribute("href",tmpHref)
		}
	}
}


function removeMutipleNBSP(tmpStr){
	/*while(tmpStr.indexOf("\&nbsp\;\&nbsp\;")!= -1){
		tmpStr = tmpStr.replace(/&nbsp;/g,"")
		alert(tmpStr.length)
	}*/
	tmpStr = tmpStr.replace(/&nbsp;&nbsp;/g,"")
	return tmpStr
}

function traverseDom(editNbr){
	var tmpFrame, tmpFmElement

	tmpFrame = eval("obvius_"+editNbr+"_editor")
	tmpFmElement = eval("'obvius_"+editNbr+"_html'")
	
	
	
	removeUnusedAttribute(editNbr,"OL","style")
	removeUnusedAttribute(editNbr,"UL","style")
	removeUnusedAttribute(editNbr,"SPAN","lang")
	removeUnusedAttribute(editNbr,"LI","style")
	removeUnusedAttribute(editNbr,"P","class")
	removeUnusedAttribute(editNbr,"P","style")
	removeUnusedAttribute(editNbr,"FONT","face")
	removeUnusedAttribute(editNbr,"FONT","style")
	removeUnusedAttribute(editNbr,"FONT","size")
	removeUnusedAttribute(editNbr,"SPAN","style")

	replaceWordParagraphs(editNbr);
	
	parseFrameInnerHTML(editNbr)

	removeEmptyTags(editNbr)

	tmpFrame.document.body.innerHTML = removeMutipleNBSP(tmpFrame.document.body.innerHTML)
	fixInternalLinks(editNbr)

	//    fix_ol(editNbr);
	//    fix_ul(editNbr);
	//document.forms[0].elements[tmpFmElement].value = tmpFrame.document.body.innerHTML;
}


function removeUnusedAttribute(editNbr,tag,attribute){
    /* Notice: 
	   This method cannot be used to remove the attributes: align, class, style or event handler!
	   This is due to removeAttribute not wanting to remove those. 
	   Use element.className = '' to set an empty class.
	*/
	var tmpFrame, tmpFmElement, tmpArray, root
	
	tmpFrame = eval("obvius_"+editNbr+"_editor")
	tmpFmElement = eval("'obvius_"+editNbr+"_html'")
	root = tmpFrame.document.documentElement.lastChild;
	
	tmpArray = root.getElementsByTagName(tag)
	
	for(i=0;i<tmpArray.length;i++){
		tmpArray[i].normalize
		tmpArray[i].removeAttribute(attribute)
	}
	
}

function removeEmptyTags(editNbr){
	var tmpFrame, tmpFmElement, tmpArray, root, tmpArrayToRemove, j
	tmpFrame = eval("obvius_"+editNbr+"_editor")
	tmpFmElement = eval("'obvius_"+editNbr+"_html'")
	root = tmpFrame.document.documentElement.lastChild;
	tmpArrayToRemove = new Array()
	j = 0
	
	tmpArray = root.getElementsByTagName("P")
	for(i=0;i<tmpArray.length;i++){
		if(tmpArray[i].innerText == "" || tmpArray[i].innerText == " "){
				tmpArrayToRemove[j] = tmpArray[i];
				j++
		}
	}
	for(i=0;i<tmpArrayToRemove.length;i++){
		tmpArrayToRemove[i].parentNode.removeChild(tmpArrayToRemove[i])
	}

	// Remove empty span tags
	strTmp = tmpFrame.document.body.innerHTML;
	strTmp = strTmp.replace(/<\/?SPAN>/gi, '');
	tmpFrame.document.body.innerHTML = strTmp;
}

function fix_ol(editNbr){
    var tmpFrame = eval("obvius_"+editNbr+"_editor");
    var root = tmpFrame.document.documentElement.lastChild;

    ol_tags = root.getElementsByTagName("OL");
    for(i=0;i<ol_tags.length;i++){
        var new_html = '';

        var ol_tag = ol_tags[i];
        if(! ol_tag.outerHTML.match(/<OL TYPE=1 START/i)) {
            var li_tags = new Array();
            li_tags = ol_tag.getElementsByTagName("LI");

            for(num_li=0;num_li < li_tags.length;num_li++) {
                new_html += '<OL TYPE=1 START="' + (num_li + 1) + '">' + li_tags[num_li].outerHTML + "\n</OL>\n";
            }
            ol_tag.outerHTML=new_html;
        }
    }
}

function fix_ul(editNbr){
    var tmpFrame = eval("obvius_"+editNbr+"_editor");
    var root = tmpFrame.document.documentElement.lastChild;

    ul_tags = root.getElementsByTagName("UL");
    for(i=0;i<ul_tags.length;i++){
        var new_html = '';

        var ul_tag = ul_tags[i];
        if(! ul_tag.outerHTML.match(/<UL COMPACT><LI>/i)) {
            var li_tags = new Array();
            li_tags = ul_tag.getElementsByTagName("LI");

            for(num_li=0;num_li < li_tags.length;num_li++) {
                new_html += '<UL COMPACT>' + li_tags[num_li].outerHTML + "\n</UL>\n";
            }
            ul_tag.outerHTML=new_html;
        }
    }
}

function replaceWordParagraphs(editNbr)
{
  /* Word has a nasty habit of using <P> of some class instead of the correct 
	 HTML tag. This method tries to do something about it.
   */
  var tmpFrame, tmpFmElement, tmpArray; 

  var classMap = new Object();
  classMap["Hoved1"] = "h1";//Headings
  classMap["Hoved2"] = "h2";
  classMap["Hoved3"] = "h3";
  classMap["Hoved4"] = "h4";
  classMap["Citat"] = "cite";
  
  tmpFrame = eval("obvius_"+editNbr+"_editor");
  root = tmpFrame.document.documentElement.lastChild;
  
  tmpArray = root.getElementsByTagName("P");

  //Walk backwards through the array since we are modifying it as we go along
  for(i=tmpArray.length-1;i>=0;i--) {
	if (classMap[tmpArray[i].className] != null) {
	  var newElem = root.document.createElement(classMap[tmpArray[i].className]);
	  
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
