function add_menu_reset(name) {
    document.write('<INPUT CLASS=button TYPE=button VALUE="Reset" onClick="' +
		   'reset_menu(this.form.' + name + ')' +
		   '">\n');
}

function add_field_reset(name) {
    document.write('<INPUT CLASS=button TYPE=button VALUE="Reset" onClick="' +
		   'reset_field(this.form.' + name + ')' +
		   '">\n');
}

function add_field_value(name, value, title) {
    document.write('<INPUT CLASS=button TYPE=button VALUE="'+title+'" onClick="' +
		   'this.form.' + name + '.value = \''+value+'\'' +
		   '">\n');
}

function reset_field(field) {
    field.value = field.defaultValue;
}

function reset_checkbox(checkbox) {
    checkbox.checked = checked.defaultChecked;
}

function reset_menu(menu) {
    for (var i = 0; i < menu.length; i++) {
	if (menu.options[i].defaultSelected == true) {
	    menu.options[i].selected=true;
	} else {
	    menu.options[i].selected=false;
	}
    }
}

function date_from_field(field) {
    var res;
    if ((res = field.value.match(/^(\d{4})-(\d\d)-(\d\d)( (\d\d):(\d\d))?$/)) != null) {
	var d = new Date;
	//window.status=field.name+'_'+res[1]+'_'+res[2]+'_'+res[3]+'_'+res[5]+'_'+res[6]+'_'+res.length;
	d.setFullYear(res[1]);
	d.setMonth(res[2]-1);
	d.setDate(res[3]);

	d.withTime = false;
	if (res[5] != null && res[5] != '') {
	    d.setHours(res[5]);
	    d.setMinutes(res[6]);
	    d.withTime = true;
	}


	return d;
    }
    return null;
}

function date_to_field(d, field) {
    var s, t;

    s = d.getFullYear() + "";

    // year
    //alert(s);

    if (s == "-2" || s== "-1")
        s = "9999";

    if (s == "10000")
        s = "0000";

    while (s.length < 4)
        s = "0" + s;

    s += '-';

    t = 1+d.getMonth();
    if (t < 10) s += '0';
    s += t + '-';

    t = d.getDate();
    if (t < 10) s += '0';
    s += t;

    if (d.withTime) {
	s += ' ';

	t = d.getHours();
	if (t < 10) s += '0';
	s += t + ':';

	t = d.getMinutes();
	if (t < 10) s += '0';
	s += t;
    }

    field.value = s;
}

function synchronise_field(field, other_field) {
    var d = date_from_field(field);
    var o = date_from_field(other_field);
    if (d.getTime() > o.getTime()) {
	other_field.value = field.value;
    }
}

function adjust_date(field, other_field) {
    var res;

    if ((res = field.value.match(/^\s*(\d\d?)[\/.](\d\d?)[\/.](\d{2,4})\b(.*)$/)) != null) {
	if (res[1] < 10) res[1] = '0' + res[1];
	if (res[2] < 10) res[2] = '0' + res[2];
	if (res[3] < 100) res[3] = (res[3]-0) + 1900;
	if (res[3] < 1950) res[3] = (res[3]-0) + 100;
	field.value = res[3] + '-' + res[2] + '-' + res[1] + res[4];
	return;
    }

    if ((res = field.value.match(/^\s*(\d\d?)[\/.](\d\d?)\b(.*)$/)) != null) {
        var date = new Date;
	if (res[1] < 10) res[1] = '0'+res[1];
	if (res[2] < 10) res[2] = '0'+res[2];
	field.value = date.getFullYear() + '-' + res[2] + '-' + res[1] + res[3];
	return;
    }
}

function year_forward(field, other_field) {
    var d;

    if ((d = date_from_field(field)) != null) {
        d.setFullYear(d.getFullYear()+1);
        date_to_field(d, field);
    }
}

function year_backward(field) {
    var d;

    if ((d = date_from_field(field)) != null) {
	d.setFullYear(d.getFullYear()-1);
	date_to_field(d, field);
    }
}

function month_forward(field) {
    var d;

    if ((d = date_from_field(field)) != null) {
	if (d.getMonth == 11) {
	    d.setMonth(0);
	    d.setFullYear(d.getFullYear()+1);
	} else {
	    d.setMonth(d.getMonth()+1);
	}

	date_to_field(d, field);
    }
}

function month_backward(field) {
    var d;

    if ((d = date_from_field(field)) != null) {
	if (d.getMonth == 0) {
	    d.setMonth(11);
	    d.setFullYear(d.getFullYear()-1);
	} else {
	    d.setMonth(d.getMonth()-1);
	}

	date_to_field(d, field);
    }
}

function day_forward(field) {
    var d;

    if ((d = date_from_field(field)) != null) {
	d.setTime(d.getTime() + 24*60*60*1000);
	date_to_field(d, field);
    }
}

function day_backward(field) {
    var d;

    if ((d = date_from_field(field)) != null) {
	d.setTime(d.getTime() - 24*60*60*1000);
	date_to_field(d, field);
    }
}

function hour_forward(field) {
    var d;

    if ((d = date_from_field(field)) != null) {
	d.setTime(d.getTime() + 60*60*1000);
	date_to_field(d, field);
    }
}

function hour_backward(field) {
    var d;

    if ((d = date_from_field(field)) != null) {
	d.setTime(d.getTime() - 60*60*1000);
	date_to_field(d, field);
    }
}

function minute_forward(field) {
    var d;

    if ((d = date_from_field(field)) != null) {
	d.setTime(d.getTime() + 60*1000);
	date_to_field(d, field);
    }
}

function minute_backward(field) {
    var d;

    if ((d = date_from_field(field)) != null) {
	d.setTime(d.getTime() - 60*1000);
	date_to_field(d, field);
    }
}

function add_date_button(click, value) {
    document.write('<input class=button type=button onClick="'+click+'" VALUE="'+value+'">');
}

function add_date_separator(n) {
    var i;
    if (n == null) n = 1;
    while (--n >= 0)
	document.write('&nbsp;');
}

function add_date_buttons(field, other_field) {
    var extra ='';
    if (other_field != null) {
	extra = '; synchronise_field(this.form.'+field+', this.form.'+other_field+')';
    }

    add_date_button('year_forward(this.form.'+field+')'+extra, 'Y+');
    add_date_button('year_backward(this.form.'+field+')'+extra, 'Y-');
    add_date_separator();
    add_date_button('month_forward(this.form.'+field+')'+extra, 'M+');
    add_date_button('month_backward(this.form.'+field+')'+extra, 'M-');
    add_date_separator();
    add_date_button('day_forward(this.form.'+field+')'+extra, 'D+');
    add_date_button('day_backward(this.form.'+field+')'+extra, 'D-');
}

function add_time_buttons(field, other_field) {
    var extra ='';
    if (other_field != null) {
	extra = '; synchronise_field(this.form.'+field+', this.form.'+other_field+')';
    }

    add_date_button('hour_forward(this.form.'+field+')'+extra, 'h+');
    add_date_button('hour_backward(this.form.'+field+')'+extra, 'h-');
    add_date_separator();
    add_date_button('minute_forward(this.form.'+field+')'+extra, 'm+');
    add_date_button('minute_backward(this.form.'+field+')'+extra, 'm-');
}

function add_date_now(field, value) {
    add_date_button("var d = new Date; d.withTime = 1; date_to_field(d, "+field+");", value);
}
