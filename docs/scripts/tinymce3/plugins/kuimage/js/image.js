var ImageDialog = {
	preInit : function() {
		var url;

		tinyMCEPopup.requireLangPack();

		if (url = tinyMCEPopup.getParam("external_image_list_url"))
			document.write('<script language="javascript" type="text/javascript" src="' + tinyMCEPopup.editor.documentBaseURI.toAbsolute(url) + '"></script>');
	},

	init : function(ed) {
		var f = document.forms[0], nl = f.elements, ed = tinyMCEPopup.editor, dom = ed.dom, n = ed.selection.getNode(), fl = tinyMCEPopup.getParam('external_image_list', 'tinyMCEImageList');

		tinyMCEPopup.resizeToInnerSize();
		this.fillClassList('class_list');
		this.fillFileList('src_list', fl);
		this.fillFileList('over_list', fl);
		this.fillFileList('out_list', fl);
		TinyMCE_EditableSelects.init();

		if (n.nodeName == 'IMG') {
			nl.src.value = dom.getAttrib(n, 'src');
			nl.width.value = dom.getAttrib(n, 'width');
			nl.height.value = dom.getAttrib(n, 'height');
			nl.alt.value = dom.getAttrib(n, 'alt');
			nl.title.value = dom.getAttrib(n, 'title');
			nl.vspace.value = this.getAttrib(n, 'vspace');
			nl.hspace.value = this.getAttrib(n, 'hspace');
			nl.border.value = this.getAttrib(n, 'border');
			selectByValue(f, 'align', this.getAttrib(n, 'align'));
			selectByValue(f, 'class_list', dom.getAttrib(n, 'class'), true, true);
			nl.style.value = dom.getAttrib(n, 'style');
			nl.id.value = dom.getAttrib(n, 'id');
			nl.dir.value = dom.getAttrib(n, 'dir');
			nl.lang.value = dom.getAttrib(n, 'lang');
			nl.usemap.value = dom.getAttrib(n, 'usemap');
			nl.longdesc.value = dom.getAttrib(n, 'longdesc');
			nl.insert.value = ed.getLang('update');

			if (/^\s*this.src\s*=\s*\'([^\']+)\';?\s*$/.test(dom.getAttrib(n, 'onmouseover')))
				nl.onmouseoversrc.value = dom.getAttrib(n, 'onmouseover').replace(/^\s*this.src\s*=\s*\'([^\']+)\';?\s*$/, '$1');

			if (/^\s*this.src\s*=\s*\'([^\']+)\';?\s*$/.test(dom.getAttrib(n, 'onmouseout')))
				nl.onmouseoutsrc.value = dom.getAttrib(n, 'onmouseout').replace(/^\s*this.src\s*=\s*\'([^\']+)\';?\s*$/, '$1');

			if (ed.settings.inline_styles) {
				// Move attribs to styles
				if (dom.getAttrib(n, 'align'))
					this.updateStyle('align');

				if (dom.getAttrib(n, 'hspace'))
					this.updateStyle('hspace');

				if (dom.getAttrib(n, 'border'))
					this.updateStyle('border');

				if (dom.getAttrib(n, 'vspace'))
					this.updateStyle('vspace');
			}
		}

		// Setup browse button
		document.getElementById('srcbrowsercontainer').innerHTML = getBrowserHTML('srcbrowser','src','image','theme_advanced_image');
		if (isVisible('srcbrowser'))
			document.getElementById('src').style.width = '260px';

		// Setup browse button
		document.getElementById('onmouseoversrccontainer').innerHTML = getBrowserHTML('overbrowser','onmouseoversrc','image','theme_advanced_image');
		if (isVisible('overbrowser'))
			document.getElementById('onmouseoversrc').style.width = '260px';

		// Setup browse button
		document.getElementById('onmouseoutsrccontainer').innerHTML = getBrowserHTML('outbrowser','onmouseoutsrc','image','theme_advanced_image');
		if (isVisible('outbrowser'))
			document.getElementById('onmouseoutsrc').style.width = '260px';

		// If option enabled default contrain proportions to checked
		if (ed.getParam("advimage_constrain_proportions", true))
			f.constrain.checked = true;

		// Check swap image if valid data
		if (nl.onmouseoversrc.value || nl.onmouseoutsrc.value)
			this.setSwapImage(true);
		else
			this.setSwapImage(false);

		this.changeAppearance();
		this.showPreviewImage(nl.src.value, 1);
	},

	insert : function(file, title) {
		var ed = tinyMCEPopup.editor, t = this, f = document.forms[0];

		if (f.src.value === '') {
			if (ed.selection.getNode().nodeName == 'IMG') {
				ed.dom.remove(ed.selection.getNode());
				ed.execCommand('mceRepaint');
			}

			tinyMCEPopup.close();
			return;
		}

		if (tinyMCEPopup.getParam("accessibility_warnings", 1)) {
			if (!f.alt.value) {
				tinyMCEPopup.confirm(tinyMCEPopup.getLang('advimage_dlg.missing_alt'), function(s) {
					if (s)
						t.insertAndClose();
				});

				return;
			}
		}

		t.insertAndClose();
	},

	insertAndClose : function() {
		var ed = tinyMCEPopup.editor, f = document.forms[0], nl = f.elements, v, args = {}, el;

		tinyMCEPopup.restoreSelection();

		// Fixes crash in Safari
		if (tinymce.isWebKit)
			ed.getWin().focus();

		if (!ed.settings.inline_styles) {
			args = {
				vspace : nl.vspace.value,
				hspace : nl.hspace.value,
				border : nl.border.value,
				align : getSelectValue(f, 'align')
			};
		} else {
			// Remove deprecated values
			args = {
				vspace : '',
				hspace : '',
				border : '',
				align : ''
			};
		}

		tinymce.extend(args, {
			src : nl.src.value.replace(/ /g, '%20'),
			width : nl.width.value,
			height : nl.height.value,
			alt : nl.alt.value,
			title : nl.title.value,
			'class' : getSelectValue(f, 'class_list'),
			style : nl.style.value,
			id : nl.id.value,
			dir : nl.dir.value,
			lang : nl.lang.value,
			usemap : nl.usemap.value,
			longdesc : nl.longdesc.value
		});

		args.onmouseover = args.onmouseout = '';

		if (f.onmousemovecheck.checked) {
			if (nl.onmouseoversrc.value)
				args.onmouseover = "this.src='" + nl.onmouseoversrc.value + "';";

			if (nl.onmouseoutsrc.value)
				args.onmouseout = "this.src='" + nl.onmouseoutsrc.value + "';";
		}

		el = ed.selection.getNode();

		if (el && el.nodeName == 'IMG') {
			ed.dom.setAttribs(el, args);
		} else {
			tinymce.each(args, function(value, name) {
				if (value === "") {
					delete args[name];
				}
			});

			ed.execCommand('mceInsertContent', false, tinyMCEPopup.editor.dom.createHTML('img', args), {skip_undo : 1});
			ed.undoManager.add();
		}

		tinyMCEPopup.editor.execCommand('mceRepaint');
		tinyMCEPopup.editor.focus();
		tinyMCEPopup.close();
	},

	getAttrib : function(e, at) {
		var ed = tinyMCEPopup.editor, dom = ed.dom, v, v2;

		if (ed.settings.inline_styles) {
			switch (at) {
				case 'align':
					if (v = dom.getStyle(e, 'float'))
						return v;

					if (v = dom.getStyle(e, 'vertical-align'))
						return v;

					break;

				case 'hspace':
					v = dom.getStyle(e, 'margin-left')
					v2 = dom.getStyle(e, 'margin-right');

					if (v && v == v2)
						return parseInt(v.replace(/[^0-9]/g, ''));

					break;

				case 'vspace':
					v = dom.getStyle(e, 'margin-top')
					v2 = dom.getStyle(e, 'margin-bottom');
					if (v && v == v2)
						return parseInt(v.replace(/[^0-9]/g, ''));

					break;

				case 'border':
					v = 0;

					tinymce.each(['top', 'right', 'bottom', 'left'], function(sv) {
						sv = dom.getStyle(e, 'border-' + sv + '-width');

						// False or not the same as prev
						if (!sv || (sv != v && v !== 0)) {
							v = 0;
							return false;
						}

						if (sv)
							v = sv;
					});

					if (v)
						return parseInt(v.replace(/[^0-9]/g, ''));

					break;
			}
		}

		if (v = dom.getAttrib(e, at))
			return v;

		return '';
	},

	setSwapImage : function(st) {
		var f = document.forms[0];

		f.onmousemovecheck.checked = st;
		setBrowserDisabled('overbrowser', !st);
		setBrowserDisabled('outbrowser', !st);

		if (f.over_list)
			f.over_list.disabled = !st;

		if (f.out_list)
			f.out_list.disabled = !st;

		f.onmouseoversrc.disabled = !st;
		f.onmouseoutsrc.disabled  = !st;
	},

	fillClassList : function(id) {
		var dom = tinyMCEPopup.dom, lst = dom.get(id), v, cl;

		if (v = tinyMCEPopup.getParam('theme_advanced_styles')) {
			cl = [];

			tinymce.each(v.split(';'), function(v) {
				var p = v.split('=');

				cl.push({'title' : p[0], 'class' : p[1]});
			});
		} else
			cl = tinyMCEPopup.editor.dom.getClasses();

		if (cl.length > 0) {
			lst.options.length = 0;
			lst.options[lst.options.length] = new Option(tinyMCEPopup.getLang('not_set'), '');

			tinymce.each(cl, function(o) {
				lst.options[lst.options.length] = new Option(o.title || o['class'], o['class']);
			});
		} else
			dom.remove(dom.getParent(id, 'tr'));
	},

	fillFileList : function(id, l) {
		var dom = tinyMCEPopup.dom, lst = dom.get(id), v, cl;

		l = typeof(l) === 'function' ? l() : window[l];
		lst.options.length = 0;

		if (l && l.length > 0) {
			lst.options[lst.options.length] = new Option('', '');

			tinymce.each(l, function(o) {
				lst.options[lst.options.length] = new Option(o[0], o[1]);
			});
		} else
			dom.remove(dom.getParent(id, 'tr'));
	},

	resetImageData : function() {
		var f = document.forms[0];

		f.elements.width.value = f.elements.height.value = '';
	},

	updateImageData : function(img, st) {
		var f = document.forms[0];

		if (!st) {
			f.elements.width.value = img.width;
			f.elements.height.value = img.height;
		}

		this.preloadImg = img;
	},

	changeAppearance : function() {
		var ed = tinyMCEPopup.editor, f = document.forms[0], img = document.getElementById('alignSampleImg');

		if (img) {
			if (ed.getParam('inline_styles')) {
				ed.dom.setAttrib(img, 'style', f.style.value);
			} else {
				img.align = f.align.value;
				img.border = f.border.value;
				img.hspace = f.hspace.value;
				img.vspace = f.vspace.value;
			}
		}
	},

	changeHeight : function() {
		var f = document.forms[0], tp, t = this;

		if (!f.constrain.checked || !t.preloadImg) {
			return;
		}

		if (f.width.value == "" || f.height.value == "")
			return;

		tp = (parseInt(f.width.value) / parseInt(t.preloadImg.width)) * t.preloadImg.height;
		f.height.value = tp.toFixed(0);
	},

	changeWidth : function() {
		var f = document.forms[0], tp, t = this;

		if (!f.constrain.checked || !t.preloadImg) {
			return;
		}

		if (f.width.value == "" || f.height.value == "")
			return;

		tp = (parseInt(f.height.value) / parseInt(t.preloadImg.height)) * t.preloadImg.width;
		f.width.value = tp.toFixed(0);
	},

	updateStyle : function(ty) {
		var dom = tinyMCEPopup.dom, b, bStyle, bColor, v, isIE = tinymce.isIE, f = document.forms[0], img = dom.create('img', {style : dom.get('style').value});

		if (tinyMCEPopup.editor.settings.inline_styles) {
			// Handle align
			if (ty == 'align') {
				dom.setStyle(img, 'float', '');
				dom.setStyle(img, 'vertical-align', '');

				v = getSelectValue(f, 'align');
				if (v) {
					if (v == 'left' || v == 'right')
						dom.setStyle(img, 'float', v);
					else
						img.style.verticalAlign = v;
				}
			}

			// Handle border
			if (ty == 'border') {
				b = img.style.border ? img.style.border.split(' ') : [];
				bStyle = dom.getStyle(img, 'border-style');
				bColor = dom.getStyle(img, 'border-color');

				dom.setStyle(img, 'border', '');

				v = f.border.value;
				if (v || v == '0') {
					if (v == '0')
						img.style.border = isIE ? '0' : '0 none none';
					else {
						var isOldIE = tinymce.isIE && (!document.documentMode || document.documentMode < 9);

						if (b.length == 3 && b[isOldIE ? 2 : 1])
							bStyle = b[isOldIE ? 2 : 1];
						else if (!bStyle || bStyle == 'none')
							bStyle = 'solid';
						if (b.length == 3 && b[isIE ? 0 : 2])
							bColor = b[isOldIE ? 0 : 2];
						else if (!bColor || bColor == 'none')
							bColor = 'black';
						img.style.border = v + 'px ' + bStyle + ' ' + bColor;
					}
				}
			}

			// Handle hspace
			if (ty == 'hspace') {
				dom.setStyle(img, 'marginLeft', '');
				dom.setStyle(img, 'marginRight', '');

				v = f.hspace.value;
				if (v) {
					img.style.marginLeft = v + 'px';
					img.style.marginRight = v + 'px';
				}
			}

			// Handle vspace
			if (ty == 'vspace') {
				dom.setStyle(img, 'marginTop', '');
				dom.setStyle(img, 'marginBottom', '');

				v = f.vspace.value;
				if (v) {
					img.style.marginTop = v + 'px';
					img.style.marginBottom = v + 'px';
				}
			}

			// Merge
			dom.get('style').value = dom.serializeStyle(dom.parseStyle(img.style.cssText), 'img');
		}
	},

	changeMouseMove : function() {
	},

	showPreviewImage : function(u, st) {
		if (!u) {
			tinyMCEPopup.dom.setHTML('prev', '');
			return;
		}

		if (!st && tinyMCEPopup.getParam("advimage_update_dimensions_onchange", true))
			this.resetImageData();

		u = tinyMCEPopup.editor.documentBaseURI.toAbsolute(u);

		if (!st)
			tinyMCEPopup.dom.setHTML('prev', '<img id="previewImg" src="' + u + '" border="0" onload="ImageDialog.updateImageData(this);" onerror="ImageDialog.resetImageData();" />');
		else
			tinyMCEPopup.dom.setHTML('prev', '<img id="previewImg" src="' + u + '" border="0" onload="ImageDialog.updateImageData(this, 1);" />');
	}
};

ImageDialog.preInit();
tinyMCEPopup.onInit.add(ImageDialog.init, ImageDialog);
/**
 * KU modifications starts here
 */

ImageDialog['change_caption_checkbox'] = function(elem) {
    var f = document.forms[0],
        fe = f.elements,
        ho = document.getElementById("hiddenalignoptions").options,
        opts = fe.align.options,
        align = fe.align.value;

    var cr = document.getElementById('captionrow');

    if(elem.checked) {
        if(align != "left" && align != "right") {
            if(align != "")
                tinyMCEPopup.alert(tinyMCEPopup.getLang('advimage_dlg.caption_align_conflict'));
            align = "left";
        }
        while(opts.length > 0) opts[0] = null;
        tinymce.each(ho, function(o) {
            if(o.value == "left" || o.value == "right")
                opts[opts.length] = new Option(o.text, o.value)
        });
        var mode = ((tinymce.isIE && /MSIE [2-7]/.test(navigator.userAgent)) ? 'block' : 'table-row');
        tinyMCE.DOM.setStyle(cr, "display", mode);
    } else {
        while(opts.length > 0) opts[0] = null;
        tinymce.each(ho, function(o) {
            opts[opts.length] = new Option(o.text, o.value);
        });
        tinyMCE.DOM.setStyle(cr, "display", "none");
        document.getElementById('caption').value = "";
    }

    selectByValue(f, "align", align);
    ImageDialog.updateStyle('align');
    ImageDialog.changeAppearance()
};

ImageDialog['align_to_margins'] = function(dontOverwrite) {
    var alignElem = document.getElementById('align');
    var val = alignElem.options[alignElem.selectedIndex].value;
    var mLeft = 0, mRight = 0, mTop = 5, mBottom = 10;
    if(val == "left") {
        mRight = 20;
    } else if(val == "right") {
        mLeft = 20;
    } else {
        mTop = mBottom = 0;
    }
    if(dontOverwrite !== true || document.getElementById('margintop').value === '')
        document.getElementById('margintop').value = mTop;
    if(dontOverwrite !== true || document.getElementById('marginleft').value === '')
        document.getElementById('marginleft').value = mLeft;
    if(dontOverwrite !== true || document.getElementById('marginbottom').value === '')
        document.getElementById('marginbottom').value = mBottom;
    if(dontOverwrite !== true || document.getElementById('marginright').value === '')
        document.getElementById('marginright').value = mRight;
    
    ImageDialog.changeAppearance();
    ImageDialog.updateStyle();
}

ImageDialog['link_to_attributestring'] = function(dom, elem) {
    var attrs = [];
    tinymce.each(dom.getAttribs(elem), function(a) {
        attrs.push(a.nodeName + "=" + escape(dom.getAttrib(elem, a.nodeName)));
    })
    return attrs.join(",");
}

ImageDialog['get_caption_html'] = function(dom, fe) {
    var attr_str = fe.captionlinkdata.value;

    if(!fe.caption.value)
        return "";

    if(attr_str) {
        var attrs = {};
        tinymce.each(attr_str.split(","), function(s) {
            var d = s.split("=");
            attrs[d[0]] = unescape(d[1]);
        })
        return dom.createHTML("A", attrs, fe.caption.value);
    } else {
        return fe.caption.value;
    }
}

function billedbase_callback(w, url) {
    document.getElementById('src').value = url;
    w.close();
    ImageDialog.showPreviewImage(url, 1)
    return false;
}

ImageDialog['ku_init'] = function(ed, v1, v2, v3) {
    var n = ed.selection.getNode(), dom = ed.dom, fe = document.forms[0].elements
    // Hide the advanced tab
    document.getElementById("advanced_panel").style.display="none";
    document.getElementById("advanced_tab").style.display="none";

    // Rename the default selection in the alignment dropdown
    document.getElementById("align").options[0].text = "P" + unescape('%E5') + " linje med tekst";

    // Remove some table rows by finding their containing label
    var labels = tinymce.each(
        document.getElementsByTagName("label"),
        function(elem) {
            if((elem.htmlFor || dom.getAttrib(elem, 'for') || '').match(/^vspace|hspace|class_list|style$/))
                elem.parentNode.parentNode.style.display="none";
        }
    );

    // Copy old-style margin-fields from source HTML to the dialog:
    var beforetr = fe.border.parentNode.parentNode;
    var stable = document.getElementById('marginsourcetable');
    for(var i=0,j=stable.childNodes.length;i<j;i++) {
        var c = stable.childNodes[0];
        stable.removeChild(c);
        beforetr.parentNode.insertBefore(c, beforetr);
    }
    // Adjust rowspan on the image preview td
    beforetr.parentNode.childNodes[0].rowspan=10;

    // Add caption input
    var title_tr = document.getElementById("title").parentNode.parentNode;
    var ctable = document.getElementById("captionsourcetable");
    for(var i=0,j=ctable.childNodes.length;i<j;i++) {
        var c = ctable.childNodes[0];
        ctable.removeChild(c);
        title_tr.parentNode.appendChild(c);
    }

    var getCaptionElem = function() {
        if(n.nodeName != 'IMG')
            return null;

        var parents = dom.getParents(n, null, dom.getRoot());
        parents.shift();
        for(var i=0,j=parents.length;i<j;i++) {
            if(parents[i].nodeName == 'DIV' && (parents[i].className || '').substr(0, 16) == 'img-with-caption')
                return parents[i].getElementsByTagName('p')[0];
        }

        return null;
    }

    // Restore existing values if an image was selected
    if(n.nodeName == 'IMG') {
        var dom = ed.dom;
        var mt = (dom.getStyle(n, 'margin-top') || '').replace(/[^-0-9]/g, ''),
            mb = (dom.getStyle(n, 'margin-bottom') || '').replace(/[^-0-9]/g, ''),
            ml = (dom.getStyle(n, 'margin-left') || '').replace(/[^-0-9]/g, ''),
            mr = (dom.getStyle(n, 'margin-right') || '').replace(/[^-0-9]/g, '');

        var p = getCaptionElem();
        if(p) {
            mt = (dom.getStyle(p.parentNode, 'margin-top') || '').replace(/[^-0-9]/g, '');
            mb = (dom.getStyle(p.parentNode, 'margin-bottom') || '').replace(/[^-0-9]/g, '');
            ml = (dom.getStyle(p.parentNode, 'margin-left') || '').replace(/[^-0-9]/g, '');
            mr = (dom.getStyle(p.parentNode, 'margin-right') || '').replace(/[^-0-9]/g, '');

            var links = dom.select('a', p);
            if(links && links[0]) {
                fe.captionlinkdata.value = 
                    ImageDialog.link_to_attributestring(dom, links[0]);
                fe.caption.value = links[0].innerHTML;
            } else {
                fe.caption.value = p.innerHTML;
            }
            var align = dom.getStyle(n.parentNode, "float") || '';
            selectByValue(document.forms[0], "align", align);
            fe.usecaption.checked = 1;
        }

        fe.margintop.value = (mt === 0 || mt) ? mt : '';
        fe.marginbottom.value = (mb === 0 || mb) ? mb : '';
        fe.marginleft.value = (ml === 0 || ml) ? ml : '';
        fe.marginright.value = (mr === 0 || mr) ? mr : '';

    } else {
        // Default to left alignment
        selectByValue(document.forms[0], "align", "left");
    }

    // Change margins when alignment is changed and when caption choice is
    // changed
    dom.bind(
        document.getElementById('align'),
        "change",
        ImageDialog.align_to_margins
    );
    dom.bind(
        document.getElementById('usecaption'),
        "click",
        ImageDialog.align_to_margins
    );

    // KU billedbase integration
    if(ed.settings.billedbase_url) {
        if(!document.getElementById('billedbasebrowser_link')) {
            var a = document.createElement('a');
            dom.setAttrib(a, 'href', "#billedbaseopen");
            var ow = tinyMCEPopup.getWin();
            var d = ow.document;
            dom.bind(a, 'click', function(e) {
                if(e.preventDefault)
                    e.preventDefault();
                else
                    e.returnValue = false;

                var w = 800, h = 600;
                if( typeof( ow.innerWidth ) == 'number' ) {
                    w = ow.innerWidth;
                    h = ow.innerHeight;
                } else if( d.documentElement && ( d.documentElement.clientWidth || d.documentElement.clientHeight ) ) {
                  w = d.documentElement.clientWidth;
                  h = d.documentElement.clientHeight;
                } else if( d.body && ( d.body.clientWidth || d.body.clientHeight ) ) {
                  w = d.body.clientWidth;
                  h = d.body.clientHeight;
                }
                var l = parseInt(w * 0.05);
                var t = parseInt(h * 0.05);
                w = parseInt(w * 0.9);
                h = parseInt(h * 0.9);
                window.open(
                    ed.settings.billedbase_url + '&cms_host=' + escape(document.location.host),
                    "billedbasebrowser",
                    "width=" + w + ",height=" + h + ",left=" + l + ",top=" + t + ",location=no,menubar=no,scrollbars=yes,toolbar=no");
                return false;
            });
            a.className = "billedbasebrowse";
            a.id="billedbasebrowser_link";
            var span = document.createElement('span');
            span.innerHTML = '&nbsp;';
            span.id="billedbasebrowser"
            dom.setAttrib(span, 'title', 'Hent billede fra billedbasen');
            a.appendChild(span);
            document.getElementById('srcbrowsercontainer').appendChild(a);
            dom.setAttrib(document.getElementById('src'), 'style', 'width: 234px;');
        }
    }

    // Clear existing events for srcbrowser
    var srcbrowser_link = document.getElementById('srcbrowser_link')
    tinymce.each([srcbrowser_link, document.getElementById('srcbrowser')], function(e, i) {
        dom.setAttrib(e, "href", "javascript:void(0)");
        dom.setAttrib(e, "onmousedown", "");
    });
    dom.bind(srcbrowser_link, "click", function(e) {
        if(e.preventDefault)
            e.preventDefault();
        else
            e.returnValue = false;
        ed.settings.file_browser_callback('src', fe.src.value, 'image', window, function(nav_win) {
            ImageDialog.windowchecker = function() {
                if(nav_win.closed) {
                    ImageDialog.showPreviewImage(fe.src.value, 1);
                } else {
                    setTimeout(ImageDialog.windowchecker, 100);
                }
            }
            ImageDialog.windowchecker();
        });
    });
    
    ImageDialog.oldUpdateImageData = ImageDialog.updateImageData;
    ImageDialog.updateImageData = function(img, st) {
        ImageDialog.oldUpdateImageData(img, st);
        ImageDialog.imageWidthForCaption = parseInt(
            img.style.width ||
            img.width ||
            0
        );
    }
    
    ImageDialog['change_caption_checkbox'](fe.usecaption);
    ImageDialog.align_to_margins(n.nodeName == 'IMG' ? true : false);

    var oldInsertAndClose = ImageDialog.insertAndClose;
    
    ImageDialog.insertAndClose = function () {
        // Update style field with margin values
        var fe = document.forms[0].elements;
        var mt = parseInt(fe.margintop.value),
            mb = parseInt(fe.marginbottom.value),
            ml = parseInt(fe.marginleft.value),
            mr = parseInt(fe.marginright.value);

        fe.style.value = (fe.style.value || '').replace(/margin:\s*[^;]+;\s*/i, "");
        fe.style.value = (fe.style.value || '').replace(/\s*margin-(top|bottom|left|right):[^;]+;/g, '');
        
        var margins = {}, marginStyle = "";

        if(mt || mt === 0)
            margins['top'] = mt;
        if(mb || mb === 0)
            margins['bottom'] = mb
        if(ml || ml === 0)
            margins['left'] = ml;
        if(mr || mr === 0)
            margins['right'] = mr;

        for(var marginType in margins) {
            marginStyle += " margin-" + marginType + ": " + margins[marginType] + "px;";
        }

        if(!fe.usecaption.checked || !fe.caption.value) {
            // Transfer new margins to the image
            fe.style.value += marginStyle;
        }

        var dw = parseInt(
            document.getElementById('width').value ||
            ImageDialog.imageWidthForCaption
        ); 
            
        var divWidth = (dw || 0);

        var p = getCaptionElem();
        if(p) {
            var div = dom.getParent(n, function(e) {
                return (
                    e.nodeName == 'DIV' &&
                    (e.className || '').match(/img-with-caption/)
                );
            });
            if(fe.usecaption.checked && fe.caption.value) {
                p.innerHTML = ImageDialog.get_caption_html(dom, fe);
                if(fe.align.value != 'left' && fe.align.value != 'right') {
                    selectByValue(document.forms[0], "align", "left");
                }
                dom.setStyle(p.parentNode, "float", fe.align.value);
                // Fixup class if alignment was changed.
                align = fe.align.value || 'left';
                var c = align == 'left' ? 'img-with-caption-left' : 'img-with-caption';
                if(!dom.hasClass(p.parentNode, c)) {
                    var oc = align == 'left' ? 'img-with-caption' : 'img-with-caption-left';
                    dom.removeClass(p.parentNode, oc);
                    dom.addClass(p.parentNode, c);
                }
                dom.setStyle(p.parentNode, "width", divWidth || null);
                var st = (dom.getAttrib(p.parentNode, 'style') || '').replace(/\s*margin:[^;]+;/, '');
                st = st.replace(/\s*margin-(top|bottom|left|right):[^;]+;/g, '');
                dom.setAttrib(p.parentNode, "style", marginStyle + st);
                fe.style.value = (fe.style.value || '').replace(/float:[^;]+;/, '').replace(/vertical-align:[^;]+;/);

                // Check if the surrounding div is the last element in the editor
                // and if so add an empty <p>&nbsp;</p> at the end
                if(! dom.getNext(div, function(n) {return n.tagName}))
                    dom.add(div.parentNode, 'p', {}, '&nbsp;');
            } else {
                var divParent = div.parentNode || dom.getRoot();

                // Try to find next block node in which we want to reinsert the image
                var nextBlock = (divParent.nodeName || '').match(/^TD|TH$/) ?
                    div.parentNode :
                    dom.getNext(div, function(n) {
                    return (n.tagName || '').toLowerCase().match(/^p|h\d+$/)
                });

                // Image might be surrounded by a link we want to keep
                var replaceElem = n.parentNode.nodeName == "A" ? n.parentNode : n;
                dom.remove(replaceElem.parentNode);
                if(nextBlock) {
		    if(nextBlock.childNodes[0]) {
			nextBlock.insertBefore(replaceElem, nextBlock.childNodes[0])
		    } else {
			nextBlock.appendChild(replaceElem);
		    }
                } else {
                    // Insert into last node of root if it exists
                    if(divParent && divParent.childNodes && divParent.childNodes.length) {
                        divParent.childNodes[divParent.childNodes.length - 1].appendChild(replaceElem);
                    } else {
                        // Old method: Just insert the element at current selection and hope for the best
                        ed.execCommand('mceInsertContent', false, '<img id="__mce_tmp_caption_img" />', {skip_undo : 1});
                        n = dom.get('__mce_tmp_caption_img');
                        dom.setAttrib('__mce_tmp_caption_img', 'id', '');
                    }

                }
                ed.selection.select(n);
                tinyMCEPopup.storeSelection();
            }
        } else {
            var createCaptionDiv = function(existingElem) {
                var img = existingElem;
                if(existingElem && existingElem.parentNode &&
                   existingElem.parentNode.nodeName == "A") {
                    existingElem = existingElem.parentNode;
                }
                if(!img)
                    img = existingElem = dom.create("img");

                var align = fe.align.value;
                if(align != "left" && align != "right")
                    align = "left";

                // Make sure image doesn't get aligned as well
                fe.style.value = (fe.style.value || '').replace(/float:[^;]+;/, '').replace(/vertical-align:[^;]+;/);

                var widthStyle = divWidth ? ("width:" + divWidth + "px;") : "";

                // Create a new caption surrounding the existing image
                var html = dom.createHTML("div", {
                    "class" : align == 'left' ? 'img-with-caption-left' : 'img-with-caption',
                    "style" : "float: " + align + ";" + widthStyle,
                    "id" : "__obvius_tmp_image_div"
                });

                // Remove existing image/link
                dom.remove(existingElem);

                // insert the div
                ed.execCommand('mceInsertContent', false, html, {skip_undo : 1});
                var div = dom.get('__obvius_tmp_image_div');
                dom.setAttrib(div, 'id', '');

                // Add image and caption to the div
                div.appendChild(existingElem);
                dom.add(div, "p", {}, ImageDialog.get_caption_html(dom, fe));

                var st = (dom.getAttrib(div, 'style') || '').replace(/\s*margin:[^;]+;/, '');
                st = st.replace(/\s*margin-(top|bottom|left|right):[^;]+;/g, '');
                dom.setAttrib(div, "style", marginStyle + st);

                // This, for some reason insterts an extra br tag in MSIE, which
                // we have to remove
                if(
                    div.firstChild &&
                    div.firstChild.nodeName &&
                    div.firstChild.nodeName == "BR") {
                    div.removeChild(div.firstChild);
                }

                // If no following block element exists, add a paragraph tag
                // right after the div, so continued editing is possible
                var nextP = dom.getNext(div, function(n) {
                    return n.nodeName && n.nodeName.match(/P|DIV|H\d/)
                });

                if(!nextP) {
                    dom.add(div.parentNode, 'p', {}, '&nbsp;');
                } else {
                    // Mozilla inserts extra empty p tags even when not needed,
                    // so we might have to remove one
                    if(dom.getNext(nextP, function(n) {
                        return n.nodeName && n.nodeName.match(/P|DIV|H\d/)
                    })) {
                        if(
                            !nextP.innerHTML ||
                            nextP.innerHTML == "&nbsp;" ||
                            nextP.innerHTML == "<br>"
                        ) {
                            dom.remove(nextP);
                        }
                    }
                }


                // Change selection to the image in its new location
                ed.selection.select(img);
                tinyMCEPopup.storeSelection();
            };

            if(n.nodeName == 'IMG') {
                if(fe.usecaption.checked && fe.caption.value) {
                    createCaptionDiv(n);
                }
            } else {
                if(fe.usecaption.checked && fe.caption.value) {
                    createCaptionDiv();
                }
            }
        }

        // Set flag that lets call to mceRepaint fix up relative URLs
        ed.fix_rel_urls = true;
        
        if(!p && tinymce.isGecko) {
            // If we didn't add a caption to the image we have to check if the
            // image was inserted at the end of the editor's content, and if so
            // add an extra p tag to the editor, so editing can continue after the
            // image.
            var afterClose = function() {
                var getLastChildElem = function(n) {
                    if(!n)
                        return n;
                    x=n.lastChild;
                    while (
                            x &&
                            (x.nodeType!=1 || x.nodeName == 'BR') &&
                            (x.nodeValue || '').match(/^\s*$/)
                    ) {
                        x=x.previousSibling;
                    }
                    return x;
                }
                var lastElem = getLastChildElem(getLastChildElem(dom.getRoot()));
                if(lastElem && lastElem.nodeName == 'IMG') {
                    dom.add(dom.getRoot(), 'p', {}, '&nbsp;');
                }
                // Fixup for FF adding an empty <p>-tag instead of one with a
                // &nbsp; in it
                var lastRootChild = getLastChildElem(dom.getRoot());
                if(
                    lastRootChild &&
                    lastRootChild.nodeName == 'P' &&
                    !lastRootChild.innerHTML) {
                    lastRootChild.innerHTML = "&nbsp;"
                }
                ed.windowManager.onClose.remove(afterClose);
            }
            ed.windowManager.onClose.add(afterClose);
        }

        oldInsertAndClose();

    };

    ImageDialog.oldShowPreviewImage = ImageDialog.showPreviewImage;

    // Probably some smarter way to do this, but it seems to work...
    var rel_func = tinyMCEPopup.getWin().dereference_rel;

    ImageDialog.showPreviewImage = function(u, st) {
        u = rel_func(ed, u);
        this.oldShowPreviewImage(u, st);
    }

    this.showPreviewImage(fe.src.value, 1)

}
tinyMCEPopup.onInit.add(ImageDialog.ku_init, ImageDialog);
