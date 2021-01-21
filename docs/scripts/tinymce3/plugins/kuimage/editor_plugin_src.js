/**
 * editor_plugin_src.js
 *
 * Based on the advimage plugin from the standard tinymce package
 * 
 */

(function() {
	tinymce.create('tinymce.plugins.KuAdvancedImagePlugin', {
		init : function(ed, url) {
			// Register commands
			ed.addCommand('kuAdvImage', function() {
				// Internal image object like a flash placeholder
				if (ed.dom.getAttrib(ed.selection.getNode(), 'class').indexOf('mceItem') != -1)
					return;

				ed.windowManager.open({
					file : url + '/image.htm',
					width : 480 + parseInt(ed.getLang('advimage.delta_width', 0)),
					height : 385 + parseInt(ed.getLang('advimage.delta_height', 0)),
					inline : 1
				}, {
					plugin_url : url
				});
			});

			// Register buttons
			ed.addButton('kuimage', {
				title : 'advimage.image_desc',
				"class" : 'mce_image',
				cmd : 'kuAdvImage'
			});

			ed.onNodeChange.add(function(ed, cm, n) {
                                cm.setActive('kuimage', n.nodeName == 'IMG');
                        });

			// Post-fixup inserted URLs:
			ed.onBeforeExecCommand.add(function(ed, e) {
				if(e == 'mceRepaint' && ed.fix_rel_urls && window.load_rel_urls) {
					load_rel_urls(ed);
					ed.fix_rel_urls = false;
				}
			});
			
			if(tinymce.isIE) {
				ed.onNodeChange.add(function(ed, cm, n) {
					var p = n.parentNode;
					if(n.nodeName == 'IMG' && p && p.nodeName == 'DIV' &&
					   (ed.dom.hasClass(p, 'img-with-caption-left') ||
					    ed.dom.hasClass(p, 'img-with-caption')
					   )) {
						ed.selection.select(n);
					}
				});
			}

			// Register new command for the contextmenu
			var cm_plugin = ed.plugins.contextmenu;
			if(cm_plugin) {
			    cm_plugin.onContextMenu.add(function(plugin, menu, el, col){
				for(var key in menu.items) {
				    var i = menu.items[key];
				    if(i.settings && i.settings.icon && i.settings.icon == 'image') {
					i.settings.cmd = 'kuAdvImage';
				    }
				}
			    }, this);
			}
		},

		getInfo : function() {
			return {
				longname : 'Advanced image (modified for Copenhagen University)',
				author : 'Magenta Aps',
				authorurl : 'http://magenta-aps.dk/',
				infourl : '',
				version : '1.0'
			};
		}
	});

	// Register plugin
	tinymce.PluginManager.add('kuimage', tinymce.plugins.KuAdvancedImagePlugin);
})();