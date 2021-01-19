function multiselect_add() {
    var value = document.getElementById('multiselect_finder').value;
    if(! value) {
        alert('Du skal skrive noget i inputfeltet');
        return;
    }

    var select = document.getElementById('documents_select');

    var index = select.length;

    select[index] = new Option(value, index + ":" + value);

    document.getElementById('multiselect_finder').value = '';

}

function multiselect_up() {
    var select = document.getElementById('documents_select');

    var elem1_index = select.selectedIndex;

    // Return without doing anything if element is already highest in list
    if(elem1_index == 0) {
        return;
    }

    var elem1 = select[elem1_index];
    if(! elem1) {
        alert('Vælg noget i boksen først');
    }

    var elem2_index = elem1_index - 1;
    var elem2 = select[elem2_index];

    var tmp_value = elem2.text;

    select[elem2_index] = new Option(elem1.text, elem2_index + ":" + elem1.text);
    select[elem1_index] = new Option(tmp_value, elem1_index + ":" + tmp_value);

    select.selectedIndex = elem2_index;
}

function multiselect_down() {
    var select = document.getElementById('documents_select');

    var elem1_index = select.selectedIndex;

    // Return without doing anything if element is already lowest in list
    if(elem1_index == select.length - 1) {
        return;
    }

    var elem1 = select[elem1_index];
    if(! elem1) {
        alert('Vælg noget i boksen først');
    }

    var elem2_index = elem1_index + 1;
    var elem2 = select[elem2_index];

    var tmp_value = elem2.text;

    select[elem2_index] = new Option(elem1.text, elem2_index + ":" + elem1.text);
    select[elem1_index] = new Option(tmp_value, elem1_index + ":" + tmp_value);

    select.selectedIndex = elem2_index;
}

function multiselect_delete() {
    var select = document.getElementById('documents_select');

    var index = select.selectedIndex;

    if(! select[index]) {
        alert('Vælg noget i listen først');

        return;
    }

    select[index] = null;

    // Fixup numbers:

    for(var i=index; i<select.length;i++) {
        var elem = select[i];
        elem.value = i + ":" + elem.text;
    }
}

function multiselect_select_all() {
    var select = document.getElementById('documents_select');
    for(var i=0; i<select.length; i++) {
        select[i].selected=1;
    }
    return true;
}


function multiselect_all() {
    var select = document.getElementById('documents_select');
    for(var i=0; i<select.length; i++) {
        alert(select[i].value);
    }
}

function multiselect_create_new() {
}
