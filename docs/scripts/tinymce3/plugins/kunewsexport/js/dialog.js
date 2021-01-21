tinyMCEPopup.requireLangPack();

var ExampleDialog = {
	init : function() {
		var f = document.forms[0];

		// Get the selected contents as text and place it in the input
		//f.someval.value = tinyMCEPopup.editor.selection.getContent({format : 'text'});
		//f.somearg.value = tinyMCEPopup.getWindowArg('some_custom_arg');
                document.getElementById('srcbrowsercontainer').innerHTML = getBrowserHTML('srcbrowser','multiselect_finder','image','theme_advanced_image');


	},

	insert : function() {

		// Insert the contents from the input into the document
		multiselect_select_all(); 

		var str = $("#documents_select").serializeArray();
		$("#result").html( '' );
		$("#result").load( '/admin/?obvius_app_newsletter_helper=1', str, function() {
	    	    var content = $("#result").html();
		    tinyMCEPopup.editor.execCommand('mceInsertContent', false, content);
		    tinyMCEPopup.close();
		});

	}
};

tinyMCEPopup.onInit.add(ExampleDialog.init, ExampleDialog);
