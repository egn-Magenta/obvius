// ** I18N
Calendar._DN = new Array
("S�ndag",
 "Mandag",
 "Tirsdag",
 "Onsdag",
 "Torsdag",
 "Fredag",
 "L�rdag",
 "S�ndag");

// short day names
Calendar._SDN = new Array
("S�n",
 "Man",
 "Tir",
 "Ons",
 "Tor",
 "Fre",
 "L�r",
 "S�n");

// full month names
Calendar._MN = new Array
("January",
 "Februar",
 "Marts",
 "April",
 "Maj",
 "Juni",
 "Juli",
 "August",
 "September",
 "Oktober",
 "November",
 "December");

// short month names
Calendar._SMN = new Array
("Jan",
 "Feb",
 "Mar",
 "Apr",
 "Maj",
 "Jun",
 "Jul",
 "Aug",
 "Sep",
 "Okt",
 "Nov",
 "Dec");

// tooltips
Calendar._TT = {};
Calendar._TT["INFO"] = "Om Kalenderen";

Calendar._TT["ABOUT"] =
/*
"DHTML Date/Time Selector\n" +
"(c) dynarch.com 2002-2003\n" + // don't translate this this ;-)
"For den seneste version bes�g: http://dynarch.com/mishoo/calendar.epl\n" +
"Distribueret under GNU LGPL.  Se http://gnu.org/licenses/lgpl.html for detajler." +
"\n\n" +
*/
"Valg af dato:\n" +
"- Brug \xab, \xbb knapperne for at v�lge �r\n" +
"- Brug " + String.fromCharCode(0x2039) + ", " + String.fromCharCode(0x203a) + " knapperne for at v�lge m�ned\n" +
"- Hold knappen p� musen nede p� knapperne ovenfor for hurtigere valg.";
Calendar._TT["ABOUT_TIME"] = "\n\n" +
"Valg af tid:\n" +
"- Klik p� en vilk�rlig del for st�rre v�rdi\n" +
"- eller Shift-klik for for mindre v�rdi\n" +
"- eller klik og tr�k for hurtigere valg.";

Calendar._TT["PREV_YEAR"] = "�t �r tilbage (hold for menu)";
Calendar._TT["PREV_MONTH"] = "�n m�ned tilbage (hold for menu)";
Calendar._TT["GO_TODAY"] = "G� til i dag";
Calendar._TT["NEXT_MONTH"] = "�n m�ned frem (hold for menu)";
Calendar._TT["NEXT_YEAR"] = "�t �r frem (hold for menu)";
Calendar._TT["SEL_DATE"] = "V�lg dag";
Calendar._TT["DRAG_TO_MOVE"] = "Tr�k vinduet";
Calendar._TT["PART_TODAY"] = " (i dag)";

Calendar._TT["DAY_FIRST"] = "Vis %s f�rst";

Calendar._TT["WEEKEND"] = "0,6";

Calendar._TT["CLOSE"] = "Luk vinduet";
Calendar._TT["TODAY"] = "I dag";
Calendar._TT["TIME_PART"] = "(Shift-)klik eller tr�k for at �ndre v�rdien";

// date formats
Calendar._TT["DEF_DATE_FORMAT"] = "%d-%m-%Y";
Calendar._TT["TT_DATE_FORMAT"] = "%d. %b, %Y";

Calendar._TT["WK"] = "uge";
Calendar._TT["TIME"] = "Kl.:";
