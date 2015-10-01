/* 
$Id$
*/
var ac_form;
var ac_arena;
var ac_editor;
var ac_entity;
var ac_editbox_current_id;
var ac_roles_hash;
var ac_roles_imperatives;
var ac_actions_hash;
var ac_allow_inherited;
var ac_readonly;

var ac_content;

function raise(exception)
{
	var v = document.getElementById('js-error');
	if ( v != null) {
		v.innerHTML = exception;
	} else {
		document.writeln('<font color="#FF0000">' + exception + '</font>');
	}
	throw(exception);
}


/*
inititalize internal variables. form is the name of form that is to be the arena
of dhtml play ( see above )
*/
function accessrules_init(
	form, 
	show_universal,  universal_rules, 
	allow_inherited, inherited_rules,
	readonly
) {
	// check fancy functions
	if ( typeof(Array.prototype.splice) != "function") {
		raise("Unable to work correctly under this browser, consider installing a newer version, or Firefox");
	}

	ac_allow_inherited = allow_inherited;
	ac_readonly        = readonly;

	// get hold of required dom elements
	ac_form = document.forms[form];
	if ( typeof(ac_form) == "undefined") {
		raise("error: accessrules_init(): form '" + form + "' not found");
	}

	get_control('accessrules');
	if ( ac_allow_inherited) {
		get_control('inherited');
	}
	get_control('users');
	get_control('groups');
	get_control('entity');
	get_control('roles');
	get_control('action');

	ac_arena           = get_element('arena');
	ac_editor          = get_element('editlayer');

	// initial positioning
	ac_editor.style.left = (document.body.clientWidth  - ac_editor.offsetWidth) / 2 + 'px';

	// populate roles lookup table
	ac_roles_hash = new Array;
	for (var i = 0; i < ac_form.roles.length; i++) {
		ac_roles_hash[ ac_form.roles[i].value ] = i; 
	}
	ac_roles_imperatives = new Array;
	ac_roles_imperatives['modes'] = 'change access';
	// all other role names (view, publish, etc) are imperative on their own
	
	
	// populate actions lookup table
	ac_actions_hash = new Array;
	for (var i = 0; i < ac_form.action.length; i++) {
		ac_actions_hash[ ac_form.action[i].value ] = i; 
	}

	// populate universal rules
	if ( show_universal) {
		var c = get_element('universal-content');
		var d = new Array();
		accessrules_parse( d, universal_rules);
		for ( i = 0; i < d.length; i++)
			d[i] = accessrules_create_readable_accessrule( d[i]);
		c.innerHTML = d.length ? d.join("<br>") : "<i>none</i>"
	}	
	
	// inherited 
	if ( ac_allow_inherited) {
		c = get_element('inherited-content');
		d = new Array();
		accessrules_parse( d, inherited_rules);
		for ( i = 0; i < d.length; i++)
			d[i] = accessrules_create_readable_accessrule( d[i]);
		c.innerHTML = d.length ? d.join("<br>") : "<i>none</i>"
	}

	// and the actual content
	accessrules_parse_textarea();
	
	// etc
	ac_editbox_current_id = -2;
}

function get_control(name)
{
	var g = ac_form[name];
	if ( typeof(g) == "undefined")
		raise("error: accessrules_init(): control '" + name + "' not found<br>");
	return g;
}

function get_element(id)
{
	var g = document.getElementById(id);
	if ( g == null)
		raise("error: accessrules_init(): element '" + id + "' not found<br>");
	return g;
}

/*
crudely parse the content, store parsed data in the passed array,
returns boolean flag if INHERIT section is present.
*/
function accessrules_parse(storage, text) {
	var chunks;
	var lines = text.match(/[^\n\r]+/g);
	var has_inherited = false;

	/* special case as written in Obvius/Access.pm: document without
	access rules is treated as INHERITED . Go figure why not vice versa. */
	if (lines == null) {
		return true;
	}

	var lineparser = /^(\@?)([^=]+)(\+|-|=|=!|!)([\w,]+)$/g;

	for (var i = 0; i < lines.length; i++) {
		var line = lines[i];
		if (ac_allow_inherited && line.toLowerCase() === "inherit") {
			has_inherited = true;
		} else {
			lineparser.lastIndex = 0;
			var chunks = lineparser.exec(line);
			if (chunks) {
				var rule = {};
				rule['valid']        = true;
				rule['is_group']     = (chunks[1] == '@');
				rule['entity']       = chunks[2];
				rule['action']       = chunks[3];
				rule['roles']        = chunks[4].match(/\w+/g);
				rule['line']         = line;

				/*
				check that group/owner is ok
				*/
				if (accessrules_find_select_value( (rule['is_group'] ? ac_form.groups : ac_form.users), rule['entity'] ) < 0) {
					rule['warning'] = ( rule['is_group'] ? 'Group ' : 'User ') + "'" + rule['entity'] + "'" +	' is invalid. ';
				}

				/*
				check that all roles are understood
				*/
				var bad_roles = new Array;

				for (var j = 0; j < rule['roles'].length; j++) {
					if (ac_roles_hash[rule['roles'][j]] >= 0){
						continue;
					}
					bad_roles.push(rule['roles'][j]);
				}
				if (bad_roles.length > 0) {
					rule['warning'] = ( rule['warning'] ? rule['warning'] : '') + 'Role(s) [' + bad_roles.join(',') + '] is/are invalid';
				}

				storage.push(rule);
			} else {
				console.log("invalid rule!",line,!!lineparser.exec(line));
				var rule = {};
				rule['valid']    = false;
				rule['line']     = line;
				storage.push(rule);
			}
		}
	}
	return has_inherited;
}

/*
reads the current content of textarea, updates the controls
*/
function accessrules_parse_textarea()
{
	ac_content = new Array();
	var has_inherited = accessrules_parse( ac_content, ac_form.accessrules.value);
	if ( ac_allow_inherited) {
		ac_form.inherited.checked = has_inherited;
	}
	accessrules_reshape_controls();
}

/*
finds select index by value 
*/
function accessrules_find_select_value( select, value)
{
	var i, o;
	o = select.options;
	for ( i = 0; i < o.length; i++) {
		if ( o[i].value == value) return i;
	}
	return -1;
}

/*
given a rule index, creates a human readable string
*/
function accessrules_create_readable_accessrule(rule)
{
	if (rule['valid']) {
		var i, can, what;
		var capabilities = [];
		var roles = rule['roles'];

		for (i = 0; i < roles.length; i++) {
			capabilities.push(
				(ac_roles_imperatives[roles[i]] != null) ?
					ac_roles_imperatives[roles[i]] :
					roles[i]
			);
		}

		// only, not, always, etc
		can = ac_actions_hash[rule['action']];
		if (can == null) {
			return rule['line'];
		}
		can = ac_form.action[can].text;

		switch ( capabilities.length) {
			case 0:
				can = '';
				what = 'do nothing, empty rule';
				break;
			case 1:
				what = capabilities[0];
				break;
			case 2:
				what = capabilities[0] + ' and ' + capabilities[1];
				break;
			default:
				var local = capabilities[capabilities.length-1];
				capabilities[capabilities.length-1] = 'and ' + local;
				what = capabilities.join(', ');
				capabilities[capabilities.length-1] = local;
		}

		var entity_name = ( rule['is_group'] ? '' : 'User ') + 'with id=\''+ rule['entity'] +'\'';
		var entity = rule['is_group'] ? ac_form.groups : ac_form.users;
		for (var j = 0; j < entity.length; j++) {
			if (rule['entity'] != entity[j].value) {
				continue;
			}
			entity_name = '<i>' + entity[j].text + '</i>';
			break;
		}

		var text = (rule['is_group'] ? 'Group ' : '') +	entity_name + " can " + can + ' ' + what;
		if (rule['warning'] != null) {
			text += '<br>(<font size="-1" color="#CC0000">warning: ' + rule['warning'] + '</font>)';
		}
		return text;

	} else {
		return '<font color="#CC0000">Invalid rule: </font><b>' + rule['line'] + '</b>';
	}
}

/*
based on ac_content() information, reshapes accesrule controls
*/
function accessrules_reshape_controls()
{
	var arena = '';
	for (var i = 0; i < ac_content.length; i++) {
		arena = arena +
			accessrules_create_readable_accessrule(ac_content[i]) +
			( ac_readonly ? '' : (
				( ac_content[i]['valid'] ?
				' <a href="" onClick="accessrules_edit(' + 
					i + 
					');return false;">Edit</a>' :
				' '
				) +
				' <a href="" onClick="accessrules_delete(' + 
					i + 
					');return false;">Delete</a>'
			)) + 
			'<br>';
	}
	ac_arena.innerHTML = arena;
}

/* 
collects all info from user-driven controls and pushes text represenation
into textarea::accessrules.
*/
function accessrules_update_textarea()
{
	var i;
	var t = '';

	if ( ac_allow_inherited && ac_form.inherited.checked) {
		t = t + "INHERIT\n";
	}
	
	for ( i = 0; i < ac_content.length; i++) {
		var rule;
		var e = ac_content[i];
		if ( e['valid']) {
			rule =
				( e['is_group'] ? '@' : '') +
				e['entity'] + 
				e['action'] +
				e['roles'].join(",")
				;
		} else {
			rule = e['line'];
		}
		t = t + rule + "\n";
	}
	ac_form.accessrules.value = t;
}

/*
open/close edit box
*/
function accessrules_editbox_visible(visible)
{
	if ( visible) {
		ac_editor.style.display = "inline";
		ac_editor.style.left = (document.body.clientWidth  - ac_editor.offsetWidth) / 2 + 'px';
	} else {
		ac_editor.style.display = "none";
	}
}

/*
create a new rule
*/
function accessrules_new()
{
	if ( ac_readonly) return;

	ac_editbox_current_id     = -1;
	ac_form.entity[0].checked = true;
	ac_form.users.selectedIndex = 0;
	ac_form.groups.selectedIndex = 0;
	ac_form.action.selectedIndex = 0;
	var i;
	for ( i = 0; i < ac_form.roles.length; i++) {
		ac_form.roles[i].checked = false;
	}
	accessrules_editbox_visible(true);
}

/*
edit a rule
*/
function accessrules_edit(id)
{
	if ( ac_readonly) return;

	var e = ac_content[id];

	if ( !e['valid']) {
		alert("Cannot parse this item, please edit it using the text box below");
		return;
	}
	
	ac_editbox_current_id = id;
	
	if ( e['is_group']) {
		ac_form.entity[1].checked = true;
		ac_form.users.selectedIndex = -1;
		ac_form.groups.value = e['entity'];
	} else {
		ac_form.entity[0].checked = true;
		ac_form.users.value = e['entity'];
		ac_form.groups.selectedIndex = -1;
	}

	ac_form.action.value = e['action'];

	var i;
	for ( i = 0; i < ac_form.roles.length; i++) {
		ac_form.roles[i].checked = false;
	}
	for ( i = 0; i < e['roles'].length; i++) {
		var idx = ac_roles_hash[
			e['roles'][i]
		];
		if ( idx == null) continue;
		ac_form.roles[idx].checked = true;
	}
	
	accessrules_editbox_visible(true);
}

/*
delete a rule
*/
function accessrules_delete(id)
{
	if ( ac_readonly) return;
	accessrules_editbox_visible(false);

	ac_content.splice(id, 1);
	accessrules_reshape_controls();
	accessrules_update_textarea();
}

/*
edit box ok pressed, validate, close the box, update ac_content and ac_arena
*/
function accessrules_editbox_ok()
{

	var e;
	
	// select the storage
	if ( ac_editbox_current_id == -1) {
		e = new Array;
	} else if ( ac_editbox_current_id >= 0) {
		e = ac_content[ac_editbox_current_id];
	} else {
		accessrules_editbox_visible(false);
		return;
	}

	// validate the input
	var i, is_group, entity, roles;

	if ( ac_form.entity[0].checked) {
		is_group = false;
		entity   = ac_form.users;
	} else if ( ac_form.entity[1].checked) {
		is_group = true;
		entity   = ac_form.groups;
	} else {
		alert("Please select owner or group");
		ac_form.entity[0].focus;
		return;
	}


	if ( entity.selectedIndex < 0) {
		alert("Please select an item from the user or group list");
		entity.focus;
		return;
	}
	
	if ( ac_form.action.selectedIndex < 0) {
		alert("Please select an item from the actions list");
		ac_form.action.focus;
		return;
	}

	roles = new Array;
	for ( i = 0; i < ac_form.roles.length; i++) {
		if ( ac_form.roles[i].checked) {
			roles.push(ac_form.roles[i].value);
		}
	}

	if ( roles.length == 0) {
		alert("Please select at least one role; empty capability rules not supported");
		ac_form.roles[0].focus;
		return;
	}


	// hide the box
	accessrules_editbox_visible(false);

	// store data
	e['valid']    = true;
	e['is_group'] = is_group;
	e['entity']   = entity.value;
	e['action']   = ac_form.action.value;
	e['roles']    = roles;
	e['warning']  = null;
	if ( ac_editbox_current_id == -1) 
		ac_content.push(e);

	// update view
	accessrules_reshape_controls();
	accessrules_update_textarea();
}
