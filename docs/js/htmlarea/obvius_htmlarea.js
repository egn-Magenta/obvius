/* Customized functions for HTMLarea used in Obvius */


// Called when the user clicks on "InsertImage" button.  If an image is already
// there, it will just modify it's properties.
function htmlarea_InsertImage_Obvius(image) {
    var editor = this;	// for nested functions
    var outparam = null;
    if (typeof image == "undefined") {
        image = this.getParentElement();
        if (image && !/^img$/i.test(image.tagName))
            image = null;
    }

    if (image) {
        outparam = {
            f_url    : HTMLArea.is_ie ? editor.stripBaseURL(image.src) : image.getAttribute("src"),
            f_alt    : image.alt,
            f_border : image.border,
            f_align  : image.align,
            f_vert   : image.vspace,
            f_horiz  : image.hspace,
            f_baseurl: editor.config.baseURL
        };
    } else {
        outparam = {
            f_baseurl: editor.config.baseURL
        };
    }

    this._popupDialog("../../../admin/?obvius_op=htmlarea_imagedialog", function(param) {
        if (!param) {	// user must have pressed Cancel
            return false;
        }
        var img = image;
        if (!img) {
            var sel = editor._getSelection();
            var range = editor._createRange(sel);
            editor._doc.execCommand("insertimage", false, param.f_url);
            if (HTMLArea.is_ie) {
                img = range.parentElement();
                // wonder if this works...
                if (img.tagName.toLowerCase() != "img") {
                    img = img.previousSibling;
                }
            } else {
                img = range.startContainer.previousSibling;
            }
        } else {
            img.src = param.f_url;
        }
        for (field in param) {
            var value = param[field];
            switch (field) {
                case "f_alt"    : img.alt	 = value; break;
                case "f_border" : img.border = parseInt(value || "0"); break;
                case "f_align"  : img.align	 = value; break;
                case "f_vert"   : img.vspace = parseInt(value || "0"); break;
                case "f_horiz"  : img.hspace = parseInt(value || "0"); break;
            }
        }
    }, outparam);
};


function htmlarea_CreateLink_Obvius(link) {
    var editor = this;
    var outparam = null;
    if (typeof link == "undefined") {
        link = this.getParentElement();
        if (link && !/^a$/i.test(link.tagName))
            link = null;
    }
    if (link) {
        outparam = {
            f_href   : HTMLArea.is_ie ? editor.stripBaseURL(link.href) : link.getAttribute("href"),
            f_title  : link.title,
            f_target : link.target,
            f_baseurl: editor.config.baseURL
        };
    } else {
        outparam = {
            f_baseurl: editor.config.baseURL
        };
    }
    this._popupDialog("../../../admin/?obvius_op=htmlarea_linkdialog", function(param) {
        if (!param)
            return false;
        var a = link;
        if (!a) {
            editor._doc.execCommand("createlink", false, param.f_href);
            a = editor.getParentElement();
            var sel = editor._getSelection();
            var range = editor._createRange(sel);
            if (!HTMLArea.is_ie) {
                a = range.startContainer;
                if (!/^a$/i.test(a.tagName))
                    a = a.nextSibling;
            }
        } else a.href = param.f_href.trim();
        if (!/^a$/i.test(a.tagName))
            return false;
        a.target = param.f_target.trim();
        a.title = param.f_title.trim();
        editor.selectNodeContents(a);
        editor.updateToolbar();
    }, outparam);
};

function htmlarea_stripBaseURL_Obvius(string) {
    // Replace http:/// with / (I don't know why this keeps showing up >_<)
    string = string.replace(/^http:\/\/\//, '/');
    return string;
}

// EOF
// Local variables: //
// c-basic-offset:8 //
// indent-tabs-mode:t //
// End: //
