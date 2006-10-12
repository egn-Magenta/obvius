// ** I18N

var ae_DA = unescape('%E6');
var oe_DA = unescape('%F8');
var aa_DA = unescape('%E5');

var AE_DA = unescape('%C6');
var OE_DA = unescape('%D8');
var AA_DA = unescape('%C5');

Calendar._DN = new Array
("S"+oe_DA+"ndag",
 "Mandag",
 "Tirsdag",
 "Onsdag",
 "Torsdag",
 "Fredag",
 "L"+oe_DA+"rdag",
 "S"+oe_DA+"ndag");

// short day names
Calendar._SDN = new Array
("S"+oe_DA+"n",
 "Man",
 "Tir",
 "Ons",
 "Tor",
 "Fre",
 "L"+oe_DA+"r",
 "S"+oe_DA+"n");

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
"For den seneste version bes"+oe_DA+"g: http://dynarch.com/mishoo/calendar.epl\n" +
"Distribueret under GNU LGPL.  Se http://gnu.org/licenses/lgpl.html for detajler." +
"\n\n" +
*/
"Valg af dato:\n" +
"- Brug \xab, \xbb knapperne for at v"+ae_DA+"lge "+aa_DA+"r\n" +
"- Brug " + String.fromCharCode(0x2039) + ", " + String.fromCharCode(0x203a) + " knapperne for at v"+ae_DA+"lge m"+aa_DA+"ned\n" +
"- Hold knappen p"+aa_DA+" musen nede p"+aa_DA+" knapperne ovenfor for hurtigere valg.";
Calendar._TT["ABOUT_TIME"] = "\n\n" +
"Valg af tid:\n" +
"- Klik p"+aa_DA+" en vilk"+aa_DA+"rlig del for st"+oe_DA+"rre v"+ae_DA+"rdi\n" +
"- eller Shift-klik for for mindre v"+ae_DA+"rdi\n" +
"- eller klik og tr"+ae_DA+"k for hurtigere valg.";

Calendar._TT["PREV_YEAR"] = "Ét "+aa_DA+"r tilbage (hold for menu)";
Calendar._TT["PREV_MONTH"] = "Én m"+aa_DA+"ned tilbage (hold for menu)";
Calendar._TT["GO_TODAY"] = "G"+aa_DA+" til i dag";
Calendar._TT["NEXT_MONTH"] = "Én m"+aa_DA+"ned frem (hold for menu)";
Calendar._TT["NEXT_YEAR"] = "Ét "+aa_DA+"r frem (hold for menu)";
Calendar._TT["SEL_DATE"] = "V"+ae_DA+"lg dag";
Calendar._TT["DRAG_TO_MOVE"] = "Tr"+ae_DA+"k vinduet";
Calendar._TT["PART_TODAY"] = " (i dag)";

Calendar._TT["DAY_FIRST"] = "Vis %s f"+oe_DA+"rst";

Calendar._TT["WEEKEND"] = "0,6";

Calendar._TT["CLOSE"] = "Luk vinduet";
Calendar._TT["TODAY"] = "I dag";
Calendar._TT["TIME_PART"] = "(Shift-)klik eller tr"+ae_DA+"k for at "+ae_DA+"ndre v"+ae_DA+"rdien";

// date formats
Calendar._TT["DEF_DATE_FORMAT"] = "%d-%m-%Y";
Calendar._TT["TT_DATE_FORMAT"] = "%d. %b, %Y";

Calendar._TT["WK"] = "uge";
Calendar._TT["TIME"] = "Kl.:";
