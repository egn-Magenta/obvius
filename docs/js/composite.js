function create_obviused_starter_button(callbackFunction, replaceElem) {
    var editButton = document.createElement("a");
    editButton.innerHTML = '<span style="font-size: 10px;">Rediger med Obvius Ed</span>';
    editButton.href="javascript:void(0)";
    editButton.title = "Rediger med Obvius ed";
    editButton.addEventListener("click", callbackFunction, false);
    return editButton;
}

function downloadObviusEd() {
    var message =  "Obvius Ed editoren gør det muligt at redigere HTML tekstfelter via\n";
    message     += "Mozilla/Netscape7's indbyggede composer. Vil du hente editoren nu?"
    if(confirm(message)) {
        window.open('http://test22.magenta-aps.dk/obvius_ed/');
    }
}

function checkObviusEdVersion(version) {
    var v1 = 0;
    var v2 = 0;
    var v3 = 2;
    var vArray = version.split(".");
    if(vArray[0] < v1 || vArray[1] < v2 || vArray[2] < v3) {
        var test = confirm("Der findes en nyere version af Obvius Ed editoren end den du har installeret på din maskine\nTryk OK for at hente den nye version");
        if(test) {
            window.open('http://test22.magenta-aps.dk/obvius_ed/obviusEd.xpi');
            return 0;
        }
    }
    return 1;
}