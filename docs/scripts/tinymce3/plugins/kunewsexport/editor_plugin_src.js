/**
 * editor_plugin_src.js
 *
 * Copyright 2009, Moxiecode Systems AB
 * Released under LGPL License.
 *
 * License: http://tinymce.moxiecode.com/license
 * Contributing: http://tinymce.moxiecode.com/contributing
 */

(function() {
    tinymce.PluginManager.requireLangPack('kunewsexport');

    tinymce.create('tinymce.plugins.KUNewsExportPlugin', {
	init : function(ed, url) {
	    ed.addCommand('mceKUNewsExport', function() {
		ed.windowManager.open({
		    file : url + '/dialog.htm',
		    width : 520 + parseInt(ed.getLang('example.delta_width', 0)),
		    height : 400 + parseInt(ed.getLang('example.delta_height', 0)),
		    inline : 1
		}, {
		    plugin_url : url, // Plugin absolute URL
		    some_custom_arg : 'custom arg' // Custom argument
		});
	    });

	    ed.addButton('kunewsexport', {
		title : ed.getLang('kunewsexport.desc' ),
		cmd : 'mceKUNewsExport',
		image : url + '/img/i.png'
	    });
	},

	createControl : function(n, cm) {
	    return null;
	},

	getInfo : function() {
	    return {
		longname : 'KU News Export plugin',
		author : 'Magenta Aps',
		authorurl : 'http://www.magenta-aps.dk/',
		infourl : 'http://www.magenta-aps.dk/',
		version : "1.0"
	    };
	}
    });

    tinymce.PluginManager.add('kunewsexport', tinymce.plugins.KUNewsExportPlugin);
})();