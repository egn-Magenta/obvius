-- MySQL dump 8.21
--
-- Host: localhost    Database: ${dbname}
---------------------------------------------------------
-- Server version	3.23.49-log

--
-- Table structure for table 'categories'
--

DROP TABLE IF EXISTS categories;
CREATE TABLE categories (
  id char(9) NOT NULL default '',
  name char(127) NOT NULL default '',
  PRIMARY KEY  (id)
) TYPE=MyISAM;

--
-- Dumping data for table 'categories'
--



--
-- Table structure for table 'comments'
--

DROP TABLE IF EXISTS comments;
CREATE TABLE comments (
  docid int(8) unsigned NOT NULL default '0',
  date datetime NOT NULL default '0000-00-00 00:00:00',
  name varchar(127) NOT NULL default '',
  email varchar(63) NOT NULL default '',
  text text NOT NULL,
  PRIMARY KEY  (docid,date),
  KEY date (date)
) TYPE=MyISAM;

--
-- Dumping data for table 'comments'
--



--
-- Table structure for table 'config'
--

DROP TABLE IF EXISTS config;
CREATE TABLE config (
  name varchar(127) NOT NULL default '',
  value varchar(127) NOT NULL default '',
  descriptions text,
  PRIMARY KEY  (name)
) TYPE=MyISAM;

--
-- Dumping data for table 'config'
--



--
-- Table structure for table 'docparms'
--

DROP TABLE IF EXISTS docparms;
CREATE TABLE docparms (
  docid int(8) unsigned NOT NULL default '0',
  name varchar(127) NOT NULL default '',
  value longtext,
  type int(8) unsigned NOT NULL default '0'
) TYPE=MyISAM;

--
-- Dumping data for table 'docparms'
--



--
-- Table structure for table 'doctypes'
--

DROP TABLE IF EXISTS doctypes;
CREATE TABLE doctypes (
  id int(8) unsigned NOT NULL auto_increment,
  name varchar(127) NOT NULL default '',
  parent int(8) unsigned NOT NULL default '0',
  basis int(1) unsigned NOT NULL default '0',
  searchable int(1) NOT NULL default '1',
  sortorder_field_is varchar(127) default NULL,
  PRIMARY KEY  (id),
  UNIQUE KEY name (name)
) TYPE=MyISAM;

--
-- Dumping data for table 'doctypes'
--


INSERT INTO doctypes VALUES (1,'Base',0,1,1,'sortorder');
INSERT INTO doctypes VALUES (2,'Standard',1,1,1,NULL);
INSERT INTO doctypes VALUES (3,'Search',2,1,1,NULL);
INSERT INTO doctypes VALUES (4,'ComboSearch',3,1,1,NULL);
INSERT INTO doctypes VALUES (5,'KeywordSearch',3,1,1,NULL);
INSERT INTO doctypes VALUES (6,'HTML',1,1,1,NULL);
INSERT INTO doctypes VALUES (7,'Upload',1,1,1,NULL);
INSERT INTO doctypes VALUES (8,'Quiz',2,1,1,NULL);
INSERT INTO doctypes VALUES (9,'QuizQuestion',1,1,1,NULL);
INSERT INTO doctypes VALUES (10,'MultiChoice',2,1,1,NULL);
INSERT INTO doctypes VALUES (11,'OrderForm',6,1,1,NULL);
INSERT INTO doctypes VALUES (12,'CreateDocument',1,1,1,NULL);
INSERT INTO doctypes VALUES (13,'Sitemap',2,1,1,NULL);
INSERT INTO doctypes VALUES (14,'Subscribe',2,1,1,NULL);
INSERT INTO doctypes VALUES (15,'Image',0,1,1,NULL);
INSERT INTO doctypes VALUES (16,'Link',1,1,1,NULL);
INSERT INTO doctypes VALUES (17,'DBSearch',1,1,1,NULL);
INSERT INTO doctypes VALUES (18,'MailData',2,1,1,NULL);
INSERT INTO doctypes VALUES (19,'TableList',0,1,1,NULL);
INSERT INTO doctypes VALUES (20,'CalendarEvent',1,1,1,NULL);
INSERT INTO doctypes VALUES (21,'Calendar',1,1,1,NULL);
INSERT INTO doctypes VALUES (22,'SubDocuments',1,1,1,NULL);

--
-- Table structure for table 'documents'
--

DROP TABLE IF EXISTS documents;
CREATE TABLE documents (
  id int(8) unsigned NOT NULL auto_increment,
  parent int(8) unsigned NOT NULL default '0',
  name varchar(127) NOT NULL default '',
  type int(8) unsigned NOT NULL default '0',
  owner smallint(5) unsigned NOT NULL default '0',
  grp smallint(5) unsigned NOT NULL default '0',
  accessrules text,
  PRIMARY KEY  (id),
  UNIQUE KEY parent (parent,name),
  KEY parent_2 (parent)
) TYPE=MyISAM;

--
-- Dumping data for table 'documents'
--


INSERT INTO documents VALUES (1,0,'dummy',2,1,1,'admin=create,edit,delete,publish,modes,admin\nOWNER=create,edit,delete,publish,modes\nGROUP+create,edit,delete,publish\nALL+view\n@Admin+admin');
INSERT INTO documents VALUES (2,1,'soeg',17,1,1,NULL);
INSERT INTO documents VALUES (3,1,'admin',6,1,1,NULL);
INSERT INTO documents VALUES (4,3,'users',19,1,1,NULL);
INSERT INTO documents VALUES (5,3,'groups',19,1,1,NULL);
INSERT INTO documents VALUES (6,3,'subscribers',19,1,1,NULL);
INSERT INTO documents VALUES (7,1,'sitemap',13,1,1,NULL);

--
-- Table structure for table 'editpages'
--

DROP TABLE IF EXISTS editpages;
CREATE TABLE editpages (
  doctypeid int(8) unsigned NOT NULL default '0',
  page varchar(5) NOT NULL default '',
  title varchar(127) NOT NULL default '',
  description text NOT NULL,
  fieldlist text NOT NULL,
  PRIMARY KEY  (doctypeid,page)
) TYPE=MyISAM;

--
-- Dumping data for table 'editpages'
--


INSERT INTO editpages VALUES (2,'1','Text and pictures','','title Title\nshort_title Short title\nteaser Teaser;rows=4\ncontent Text\npicture URL to picture;doctype=Image\nurl Web address reference (if any)\nauthor Author;distinct=1\ndocdate Date (yyyy-mm-dd)\nexpires Expiring');
INSERT INTO editpages VALUES (2,'2','Classification and keywords','Choose the appropriate classification and keywords for this document:','category Select classification codes\nkeyword Choose keywords');
INSERT INTO editpages VALUES (2,'3','Related knowledge','Choose the classification and keywords to be used to find\nlinks to related documents.','rel_category Related classification\nrel_keyword Related keywords;new=0');
INSERT INTO editpages VALUES (2,'4','Meta','The fields below are important if you want your web pages to\nbe easily found by search machines and users of the Internet','docref Reference\ncontributors Contributors\nsource Source');
INSERT INTO editpages VALUES (2,'5','Display','','seq Order of succession\nsortorder Sort order of sub documents - sort according to\npagesize Number of subdocuments on one page\nvotebox URL to votebox;doctype=MultiChoice\nsection_news Show section news;label_0=No, label_1=Yes, reverse_options=1\nsubscribeable Subscription possibility?;label_none=No, label_automatic=Automatic, label_manual=Manual');
INSERT INTO editpages VALUES (2,'P','Publish document','','front_prio Priority;label_0=Not_on_list, label_1=Always_last, label_2=Low_priority, label_3=High_priority, subtitle=Forside nyt, nopagenav=1\nfront_dura Frontpage news duration \nsec_prio Priority;label_0=Not_on_list, label_1=Always_last, label_2=Low_priority, label_3=High_priority, subtitle=Afsnit nyt, nopagenav=1\nsec_dura Section news duration \nin_subscription Include in subscription?;label_0=No, label_1=Yes, reverse_options=1');
INSERT INTO editpages VALUES (5,'1','Search information','In the fields below you can specify your local search','title Title\nshort_title Short title\nteaser Teaser;rows=4\nbase Base of search\nsearch_type Type of search\nsearch_expression Search for;rows=1,no_msie_editor=1\ndocdate Date (YYYY-MM-DD)\nexpires Expiring');
INSERT INTO editpages VALUES (5,'2','Classification and keywords','Choose the appropriate classification and keywords for this document:','category Select classification codes\nkeyword Choose keywords');
INSERT INTO editpages VALUES (5,'3','Related knowledge','Choose the classification and keywords to be used to find\nlinks to related documents.','rel_category Related classification\nrel_keyword Related keywords;new=0');
INSERT INTO editpages VALUES (5,'4','Display','','new_window Open results in new window?;label_0=No, label_1=Yes, reverse_options=1\nshow_urls Show both URL and title?;label_0=No, label_1=Yes, reverse_options=1\nshow_teasers Also show teaser?;label_0=No, label_1=Yes, reverse_options=1\nshow_new_titles Show new titles;label_0=No, label_1=Yes, reverse_options=1\nseq Order of succession\npagesize Number of subdocuments on one page\nsortorder Sort order of sub documents - sort according to\nsubscribeable Subscription possibility?;label_none=No, label_automatic=Automatic, label_manual=Manual');
INSERT INTO editpages VALUES (5,'P','Publish document','','front_prio Priority;label_0=Not_on_list, label_1=Always_last, label_2=Low_priority, label_3=High_priority, subtitle=Forside nyt, nopagenav=1\nfront_dura Frontpage news duration \nsec_prio Priority;label_0=Not_on_list, label_1=Always_last, label_2=Low_priority, label_3=High_priority, subtitle=Afsnit nyt, nopagenav=1\nsec_dura Section news duration \nin_subscription Include in subscription?;label_0=No, label_1=Yes, reverse_options=1');
INSERT INTO editpages VALUES (4,'1','Search information','','title Title\nshort_title Short title\nteaser Teaser;rows=4\nsearch_expression Search expression;no_msie_editor=1\ndocdate Date (YYYY-MM-DD)\nexpires Expiring');
INSERT INTO editpages VALUES (4,'2','Classification and keywords','Choose the appropriate classification and keywords for this document:','category Select classification codes\nkeyword Choose keywords');
INSERT INTO editpages VALUES (4,'3','Related knowledge','Choose the classification and keywords to be used to find\nlinks to related documents.','rel_category Related classification\nrel_keyword Related keywords;new=0');
INSERT INTO editpages VALUES (4,'4','Display','','new_window Open results in new window?;label_0=No, label_1=Yes, reverse_options=1\nshow_urls Show both URL and title?;label_0=No, label_1=Yes, reverse_options=1\nshow_teasers Also show teaser?;label_0=No, label_1=Yes, reverse_options=1\nseq Order of succession\npagesize Number of subdocuments on one page\nsortorder Sort order of sub documents - sort according to\nsubscribeable Subscription possibility?;label_none=No, label_automatic=Automatic, label_manual=Manual');
INSERT INTO editpages VALUES (4,'P','Publish document','','front_prio Priority;label_0=Not_on_list, label_1=Always_last, label_2=Low_priority, label_3=High_priority, subtitle=Forside nyt, nopagenav=1\nfront_dura Frontpage news duration \nsec_prio Priority;label_0=Not_on_list, label_1=Always_last, label_2=Low_priority, label_3=High_priority, subtitle=Afsnit nyt, nopagenav=1\nsec_dura Section news duration \nin_subscription Include in subscription?;label_0=No, label_1=Yes, reverse_options=1');
INSERT INTO editpages VALUES (6,'1','Text and pictures','HTML-documents can contain HTML in the Text-fields. Using the \"Browse\"-button\nbelow each field a local HTML-file can be uploaded.','title Title\nshort_title Short title\nteaser Teaser;rows=4\nhtml_content Text\nbare Show title and teaser?;label_0=Yes, label_1=No\ndocdate Date (YYYY-MM-DD)\nexpires Expiring');
INSERT INTO editpages VALUES (6,'2','Classification and keywords','Choose the appropriate classification and keywords for this document:','category Select classification codes\nkeyword Choose keywords');
INSERT INTO editpages VALUES (6,'3','Related knowledge','Choose the classification and keywords to be used to find\nlinks to related documents.','rel_category Related classification\nrel_keyword Related keywords;new=0');
INSERT INTO editpages VALUES (6,'4','Display','','seq Order of succession\npagesize Number of subdocuments on one page\nsortorder Sort order of sub documents - sort according to\nvotebox URL to votebox;doctype=MultiChoice\nsubscribeable Subscription possibility?;label_none=No, label_automatic=Automatic, label_manual=Manual');
INSERT INTO editpages VALUES (6,'P','Publish document','','front_prio Priority;label_0=Not_on_list, label_1=Always_last, label_2=Low_priority, label_3=High_priority, subtitle=Forside nyt, nopagenav=1\nfront_dura Frontpage news duration \nsec_prio Priority;label_0=Not_on_list, label_1=Always_last, label_2=Low_priority, label_3=High_priority, subtitle=Afsnit nyt, nopagenav=1\nsec_dura Section news duration \nin_subscription Include in subscription?;label_0=No, label_1=Yes, reverse_options=1');
INSERT INTO editpages VALUES (15,'1','Image','Image-documents are a little special; they do not contain text\nbut instead image-data.','title Title\nshort_title Short title\ndata Image-file\ndocdate Date (yyyy-mm-dd)\nexpires Expiring');
INSERT INTO editpages VALUES (15,'2','Classification and keywords','Choose the appropriate classification and keywords for this document:','category Select classification codes\nkeyword Choose keywords');
INSERT INTO editpages VALUES (15,'P','Publish','Publishing the picture will make it visible on the public part\nof the website.','');
INSERT INTO editpages VALUES (13,'1','Text','Documents of this type automatically generates a (dynamic) sitemap.','title Title\nshort_title Short title\ncontent Text;rows=4\nteaser Teaser;rows=4, no_msie_editor=1\nlevels Levels\ndocdate Date (YYYY-MM-DD)\nseq Order of succession');
INSERT INTO editpages VALUES (13,'P','Publish document','Publish now?','');
INSERT INTO editpages VALUES (7,'1','Upload','The Upload-document if for all types of binary files besides\nimages (for instance PDF-files, Word-documents, Excel-files etc.)','title Title\nshort_title Short title\nteaser Teaser;rows=4\nuploaddata Upload data\nmimetype MIME-type;distinct=1\nurl Web address\nauthor Author;distinct=1\ndocdate Date (YYYY-MM-DD)\nexpires Expiring');
INSERT INTO editpages VALUES (7,'2','Classification and keywords','Choose the appropriate classification and keywords for this document:','category Select classification codes\nkeyword Choose keywords');
INSERT INTO editpages VALUES (7,'3','Related knowledge','Choose the classification and keywords to be used to find\nlinks to related documents.','rel_category Related classification\nrel_keyword Related keywords;new=0');
INSERT INTO editpages VALUES (7,'4','Meta','The fields below are important if you want your web pages to be easily found by search machines and users of the Internet','docref Reference\ncontributors Contributors\nsource Source');
INSERT INTO editpages VALUES (7,'5','Display','','seq Order of succession\npagesize Number of subdocuments on one page\nsortorder Sort order of sub documents - sort according to\nsubscribeable Subscription possibility?;label_none=No, label_automatic=Automatic, label_manual=Manual');
INSERT INTO editpages VALUES (7,'P','Publish document','','front_prio Priority;label_0=Not_on_list, label_1=Always_last, label_2=Low_priority, label_3=High_priority, subtitle=Forside nyt, nopagenav=1\nfront_dura Frontpage news duration \nsec_prio Priority;label_0=Not_on_list, label_1=Always_last, label_2=Low_priority, label_3=High_priority, subtitle=Afsnit nyt, nopagenav=1\nsec_dura Section news duration \nin_subscription Include in subscription?;label_0=No, label_1=Yes, reverse_options=1');
INSERT INTO editpages VALUES (10,'1','Text','','title Sp�rgsm�l\nshort_title Short title\nteaser Uddybende information;rows=4\nauthor Author;distinct=1\ndocdate Date (yyyy-mm-dd)\nexpires Expiring\nseq Order of succession');
INSERT INTO editpages VALUES (10,'2','Choices','','vote_option Answers in the poll (format: [letter] text)');
INSERT INTO editpages VALUES (10,'P','Publish document','','front_prio Priority;label_0=Not_on_list, label_1=Always_last, label_2=Low_priority, label_3=High_priority, subtitle=Forside nyt, nopagenav=1\nfront_dura Frontpage news duration \nsec_prio Priority;label_0=Not_on_list, label_1=Always_last, label_2=Low_priority, label_3=High_priority, subtitle=Afsnit nyt, nopagenav=1\nsec_dura Section news duration \nin_subscription Include in subscription?;label_0=No, label_1=Yes, reverse_options=1');
INSERT INTO editpages VALUES (3,'1','Text','A Search-document makes it possible to create a free-text search of the\nentire website.','title Title\nshort_title Short title\nteaser Teaser;rows=4\nform Alternative search-form (leave empty for default)\ndocdate Date (YYYY-MM-DD)\nexpires Expiring');
INSERT INTO editpages VALUES (3,'2','Display','','seq Order of succession\npagesize Number of subdocuments on one page');
INSERT INTO editpages VALUES (3,'P','Publish document','Publish now?','');
INSERT INTO editpages VALUES (16,'1','Link data','Link-documents are special because they redirect the user to\nthe web address when clicked. In effect they are placeholders,\nthat enable keeping classification and meta-data for external links.','title Title\nshort_title Short title\nteaser Teaser;rows=4\nurl Web address\nauthor Author;distinct=1\ndocdate Date (YYYY-MM-DD)\nexpires Expiring');
INSERT INTO editpages VALUES (16,'2','Classification and keywords','','category Select classification codes\nkeyword Choose keywords');
INSERT INTO editpages VALUES (16,'3','Meta','The fields below are important if you want your web pages to be easily found by search machines and users of the Internet','docref Reference\ncontributors Contributors\nsource Source');
INSERT INTO editpages VALUES (16,'4','Display','Make the link subscribeable. This is only usefull in special cases like when you want to make a forum subscribeable','seq Order of succession\nsubscribeable Subscription possibility?;label_none=No, label_automatic=Automatic, label_manual=Manual');
INSERT INTO editpages VALUES (16,'P','Publish document','','front_prio Priority;label_0=Not_on_list, label_1=Always_last, label_2=Low_priority, label_3=High_priority, subtitle=Forside nyt, nopagenav=1\nfront_dura Frontpage news duration \nsec_prio Priority;label_0=Not_on_list, label_1=Always_last, label_2=Low_priority, label_3=High_priority, subtitle=Afsnit nyt, nopagenav=1\nsec_dura Section news duration \nin_subscription Include in subscription?;label_0=No, label_1=Yes, reverse_options=1');
INSERT INTO editpages VALUES (14,'1','Document data','','title Title\nshort_title Short title\nteaser Teaser;rows=4\ncontent Tekst\ndocdate Date (YYYY-MM-DD)\nexpires Expiring');
INSERT INTO editpages VALUES (14,'2','Subscription data','','mailfrom Sender in subscription emails\npasswdmsg The template used send subscription passwords');
INSERT INTO editpages VALUES (14,'3','Display-only','','seq Order of succession');
INSERT INTO editpages VALUES (14,'P','Publish document','Publish the document?','');
INSERT INTO editpages VALUES (11,'1','Text','','title Title\nshort_title Short title\nteaser Teaser;rows=4\nhtml_content Form (HTML)\nmailto Send email to\nmailmsg Use email-template\nbare Show title and teaser?;label_0=No, label_1=Yes, reverse_options=1\ndocdate Date (YYYY-MM-DD)\nexpires Expiring');
INSERT INTO editpages VALUES (11,'2','Classification and keywords','','category Select classification codes\nkeyword Choose keywords');
INSERT INTO editpages VALUES (11,'3','Related knowledge','Choose the classification and keywords to be used to find\nlinks to related documents.','rel_category Related classification\nrel_keyword Related keywords;new=0');
INSERT INTO editpages VALUES (11,'4','Display','','seq Order of succession\npagesize Number of subdocuments on one page\nsortorder Sort order of sub documents - sort according to\nsubscribeable Subscription possibility?;label_none=No, label_automatic=Automatic, label_manual=Manual');
INSERT INTO editpages VALUES (11,'P','Publish document','','front_prio Priority;label_0=Not_on_list, label_1=Always_last, label_2=Low_priority, label_3=High_priority, subtitle=Forside nyt, nopagenav=1\nfront_dura Frontpage news duration \nsec_prio Priority;label_0=Not_on_list, label_1=Always_last, label_2=Low_priority, label_3=High_priority, subtitle=Afsnit nyt, nopagenav=1\nsec_dura Section news duration \nin_subscription Include in subscription?;label_0=No, label_1=Yes, reverse_options=1');
INSERT INTO editpages VALUES (17,'1','Text','','title Title\nshort_title Short title\nteaser Teaser;rows=4\nform Alternative search-form (leave empty for default)\ndocdate Date (YYYY-MM-DD)\nexpires Expiring');
INSERT INTO editpages VALUES (17,'2','Display-only','','seq Order of succession\npagesize Number of subdocuments on one page\nsortorder Sort order of sub documents - sort according to');
INSERT INTO editpages VALUES (17,'P','Publish document','Publish now?','');
INSERT INTO editpages VALUES (19,'1','Table information','This is an administrative documenttype only.','title Title\nshort_title Short title\nteaser Teaser\ntable Table\nfields Fields in list (one per line)\neditcomp Edit row component\nnewcomp New row component\ndocdate Date (yyyy-mm-dd)');
INSERT INTO editpages VALUES (19,'2','Display','How the table-rows are displayed','seq Order of succession\npagesize Number of subdocuments on one page\nsortorder Sort order of sub documents - sort according to');
INSERT INTO editpages VALUES (19,'P','Publish document','Publish now?','');
INSERT INTO editpages VALUES (20,'1','Event Info','','title Title\nshort_title Short title\neventtype Event Type\ndocdate Date\neventtime Time (optional)\neventplace Place where the event occurs\ncontactinfo Contact info\neventinfo Other info');
INSERT INTO editpages VALUES (20,'2','Display-only','','seq Order of succession');
INSERT INTO editpages VALUES (20,'P','Publish document','','front_prio Priority;label_0=Not_on_list, label_1=Always_last, label_2=Low_priority, label_3=High_priority, subtitle=Forside nyt, nopagenav=1\nfront_dura Frontpage news duration \nsec_prio Priority;label_0=Not_on_list, label_1=Always_last, label_2=Low_priority, label_3=High_priority, subtitle=Afsnit nyt, nopagenav=1\nsec_dura Section news duration \nin_subscription Include in subscription?;label_0=No, label_1=Yes, reverse_options=1');
INSERT INTO editpages VALUES (21,'1','Document data','','title Title\ndocdate Date');
INSERT INTO editpages VALUES (21,'2','Search information','The fields below will be used to find relevant calendar events','startdate Events after this date\nenddate Events before this date\ns_event_path Only documents under (set to / for global search)\ns_event_type Event type is\ns_event_title Event title field contains\ns_event_contact Event contact info field contains\ns_event_place Event place field contains\ns_event_info Event info field contains\ns_event_order_by Order events by');
INSERT INTO editpages VALUES (21,'3','Display-only','','show_as How to show calendar\nseq Order of succession\npagesize Number of subdocuments on one page');
INSERT INTO editpages VALUES (21,'P','Publish document','','front_prio Priority;label_0=Not_on_list, label_1=Always_last, label_2=Low_priority, label_3=High_priority, subtitle=Forside nyt, nopagenav=1\nfront_dura Frontpage news duration \nsec_prio Priority;label_0=Not_on_list, label_1=Always_last, label_2=Low_priority, label_3=High_priority, subtitle=Afsnit nyt, nopagenav=1\nsec_dura Section news duration \nin_subscription Include in subscription?;label_0=No, label_1=Yes, reverse_options=1');
INSERT INTO editpages VALUES (22,'1','Text and pictures','','title Title\nshort_title Short title\nteaser Teaser;rows=4\nlogo URL to logo;doctype=Image\npicture URL to picture;doctype=Image\nurl Web address reference (if any)\nauthor Author;distinct=1\ndocdate Date (YYYY-MM-DD)\nexpires Expiring');
INSERT INTO editpages VALUES (22,'2','Classification and keywords','','category Select classification codes\nkeyword Choose keywords');
INSERT INTO editpages VALUES (22,'3','Related knowledge','Choose the classification and keywords to be used to find\nlinks to related documents.','rel_category Related classification\nrel_keyword Related keywords;new=0');
INSERT INTO editpages VALUES (22,'4','Meta','The fields below are important if you want your web pages to\nbe easily found by search machines and users of the Internet','docref Reference\ncontributors Contributors\nsource Source');
INSERT INTO editpages VALUES (22,'5','Display','','seq Order of succession\nsortorder Sort order of sub documents - sort according to\npagesize Number of subdocuments on one page\nvotebox URL to votebox;doctype=MultiChoice\nshow_teasers Show teasers?;label_0=No, label_1=Yes, reverse_options=1\nsubscribeable Subscription possibility?;label_none=No, label_automatic=Automatic, label_manual=Manual');
INSERT INTO editpages VALUES (22,'P','Publish document','','front_prio Priority;label_0=Not_on_list, label_1=Always_last, label_2=Low_priority, label_3=High_priority, subtitle=Forside nyt, nopagenav=1\nfront_dura Frontpage news duration \nsec_prio Priority;label_0=Not_on_list, label_1=Always_last, label_2=Low_priority, label_3=High_priority, subtitle=Afsnit nyt, nopagenav=1\nsec_dura Section news duration \nin_subscription Include in subscription?;label_0=No, label_1=Yes, reverse_options=1');
INSERT INTO editpages VALUES (12,'1','Basic information','','title Title\ndocdate Date\nform Create form (HTML)');
INSERT INTO editpages VALUES (12,'2','Document creation information','','doctype What doctype the created documents should have\nlanguage What language the created documents should have;size=2\nwhere Where the documents should be created\nname_prefix Prefix for names of the created documents\npublish_mode How to publish create documents;label_immediate=Immediate, label_moderator=Using a moderator\nsubscribe_include Include created documents in subscription when publishing;label_0=No, label_1=Yes, reverse_options=1\nemail Moderator email');
INSERT INTO editpages VALUES (12,'P','Publishing','Publish now?','');

--
-- Table structure for table 'fieldspecs'
--

DROP TABLE IF EXISTS fieldspecs;
CREATE TABLE fieldspecs (
  doctypeid int(8) unsigned NOT NULL default '0',
  name varchar(127) NOT NULL default '',
  type int(8) unsigned NOT NULL default '0',
  repeatable tinyint(1) unsigned NOT NULL default '0',
  optional tinyint(1) unsigned NOT NULL default '0',
  searchable tinyint(1) unsigned NOT NULL default '0',
  sortable tinyint(1) unsigned NOT NULL default '0',
  publish tinyint(1) unsigned NOT NULL default '0',
  threshold tinyint(1) unsigned NOT NULL default '128',
  default_value text,
  extra text,
  PRIMARY KEY  (doctypeid,name)
) TYPE=MyISAM;

--
-- Dumping data for table 'fieldspecs'
--


INSERT INTO fieldspecs VALUES (1,'title',8,0,0,1,1,0,0,NULL,NULL);
INSERT INTO fieldspecs VALUES (1,'short_title',9,0,0,1,1,0,0,NULL,NULL);
INSERT INTO fieldspecs VALUES (1,'category',2,1,1,1,1,0,128,NULL,NULL);
INSERT INTO fieldspecs VALUES (1,'keyword',3,1,1,1,1,0,128,NULL,NULL);
INSERT INTO fieldspecs VALUES (1,'docdate',5,0,0,1,1,0,0,NULL,NULL);
INSERT INTO fieldspecs VALUES (1,'seq',12,0,0,0,1,0,0,'10.00',NULL);
INSERT INTO fieldspecs VALUES (1,'pagesize',31,0,1,0,0,0,128,NULL,NULL);
INSERT INTO fieldspecs VALUES (1,'sortorder',20,0,0,0,0,0,128,'+seq,+title',NULL);
INSERT INTO fieldspecs VALUES (1,'subscribeable',26,0,0,1,0,0,128,'none',NULL);
INSERT INTO fieldspecs VALUES (1,'expires',6,0,0,1,1,0,0,'9999-01-01 00:00:00',NULL);
INSERT INTO fieldspecs VALUES (1,'published',6,0,0,1,1,1,128,NULL,NULL);
INSERT INTO fieldspecs VALUES (1,'publish_on',29,0,0,1,1,1,128,'0000-00-00 00:00:00',NULL);
INSERT INTO fieldspecs VALUES (1,'in_subscription',15,0,0,1,1,1,128,'0',NULL);
INSERT INTO fieldspecs VALUES (1,'mimetype',9,0,0,1,1,0,0,NULL,NULL);
INSERT INTO fieldspecs VALUES (1,'rel_category',2,1,1,1,1,0,128,NULL,NULL);
INSERT INTO fieldspecs VALUES (1,'rel_keyword',3,1,1,1,1,0,128,NULL,NULL);
INSERT INTO fieldspecs VALUES (1,'front_prio',25,0,0,1,1,1,128,'0',NULL);
INSERT INTO fieldspecs VALUES (1,'front_dura',17,0,0,1,1,1,128,'0',NULL);
INSERT INTO fieldspecs VALUES (1,'sec_prio',25,0,0,1,1,1,128,'0',NULL);
INSERT INTO fieldspecs VALUES (1,'sec_dura',17,0,0,1,1,1,128,'0',NULL);
INSERT INTO fieldspecs VALUES (1,'sec',18,0,1,1,1,1,128,'0',NULL);
INSERT INTO fieldspecs VALUES (2,'author',9,0,0,1,1,0,64,NULL,NULL);
INSERT INTO fieldspecs VALUES (2,'teaser',10,0,0,1,0,0,64,NULL,NULL);
INSERT INTO fieldspecs VALUES (2,'content',10,0,0,1,1,0,128,NULL,NULL);
INSERT INTO fieldspecs VALUES (2,'url',9,0,0,1,1,0,64,NULL,NULL);
INSERT INTO fieldspecs VALUES (2,'docref',9,0,0,1,1,0,64,NULL,NULL);
INSERT INTO fieldspecs VALUES (2,'contributors',9,0,0,1,1,0,64,NULL,NULL);
INSERT INTO fieldspecs VALUES (2,'source',9,0,0,1,1,0,64,NULL,NULL);
INSERT INTO fieldspecs VALUES (2,'picture',22,0,1,1,1,0,128,NULL,NULL);
INSERT INTO fieldspecs VALUES (2,'votebox',22,0,1,1,1,0,128,NULL,NULL);
INSERT INTO fieldspecs VALUES (2,'section_news',15,0,0,0,0,0,128,'0',NULL);
INSERT INTO fieldspecs VALUES (3,'form',11,0,0,1,1,0,128,NULL,NULL);
INSERT INTO fieldspecs VALUES (3,'search_expression',10,0,0,0,0,0,128,NULL,NULL);
INSERT INTO fieldspecs VALUES (3,'new_window',15,0,0,0,0,0,128,'0',NULL);
INSERT INTO fieldspecs VALUES (3,'show_urls',15,0,0,0,0,0,128,'0',NULL);
INSERT INTO fieldspecs VALUES (3,'show_teasers',15,0,0,0,0,0,128,'0',NULL);
INSERT INTO fieldspecs VALUES (3,'show_new_titles',15,0,0,0,0,0,128,'0',NULL);
INSERT INTO fieldspecs VALUES (5,'base',22,0,0,0,0,0,128,NULL,NULL);
INSERT INTO fieldspecs VALUES (5,'search_type',23,0,0,0,0,0,128,NULL,NULL);
INSERT INTO fieldspecs VALUES (6,'author',9,0,0,1,1,0,64,NULL,NULL);
INSERT INTO fieldspecs VALUES (6,'teaser',10,0,0,1,0,0,64,NULL,NULL);
INSERT INTO fieldspecs VALUES (6,'url',9,0,0,1,1,0,64,NULL,NULL);
INSERT INTO fieldspecs VALUES (6,'docref',9,0,0,1,1,0,64,NULL,NULL);
INSERT INTO fieldspecs VALUES (6,'contributors',9,0,0,1,1,0,64,NULL,NULL);
INSERT INTO fieldspecs VALUES (6,'source',9,0,0,1,1,0,64,NULL,NULL);
INSERT INTO fieldspecs VALUES (6,'html_content',11,0,0,1,1,0,128,NULL,NULL);
INSERT INTO fieldspecs VALUES (6,'bare',15,0,0,0,0,0,128,'0',NULL);
INSERT INTO fieldspecs VALUES (6,'votebox',22,0,1,1,1,0,128,NULL,NULL);
INSERT INTO fieldspecs VALUES (7,'author',9,0,0,1,1,0,64,NULL,NULL);
INSERT INTO fieldspecs VALUES (7,'teaser',10,0,0,1,0,0,64,NULL,NULL);
INSERT INTO fieldspecs VALUES (7,'url',9,0,0,1,1,0,64,NULL,NULL);
INSERT INTO fieldspecs VALUES (7,'docref',9,0,0,1,1,0,64,NULL,NULL);
INSERT INTO fieldspecs VALUES (7,'contributors',9,0,0,1,1,0,64,NULL,NULL);
INSERT INTO fieldspecs VALUES (7,'source',9,0,0,1,1,0,64,NULL,NULL);
INSERT INTO fieldspecs VALUES (7,'uploaddata',19,0,0,0,0,0,192,NULL,NULL);
INSERT INTO fieldspecs VALUES (7,'size',17,0,0,0,0,0,192,NULL,NULL);
INSERT INTO fieldspecs VALUES (8,'mailto',24,0,0,0,0,0,128,NULL,NULL);
INSERT INTO fieldspecs VALUES (8,'mailmsg',9,0,0,0,0,0,128,NULL,NULL);
INSERT INTO fieldspecs VALUES (8,'requireallanswers',15,0,0,0,0,0,128,NULL,NULL);
INSERT INTO fieldspecs VALUES (9,'question',10,0,0,0,0,0,128,NULL,NULL);
INSERT INTO fieldspecs VALUES (9,'answer',10,1,0,0,0,0,128,NULL,NULL);
INSERT INTO fieldspecs VALUES (9,'correctanswer',10,0,0,0,0,0,128,NULL,NULL);
INSERT INTO fieldspecs VALUES (9,'url',9,0,0,0,0,0,128,NULL,NULL);
INSERT INTO fieldspecs VALUES (10,'vote_option',9,1,0,0,0,0,128,NULL,NULL);
INSERT INTO fieldspecs VALUES (10,'bar_width',16,0,0,0,0,0,128,'65',NULL);
INSERT INTO fieldspecs VALUES (11,'mailto',24,0,0,0,0,0,128,NULL,NULL);
INSERT INTO fieldspecs VALUES (11,'mailmsg',9,0,0,0,0,0,128,NULL,NULL);
INSERT INTO fieldspecs VALUES (12,'doctype',9,0,0,1,1,0,128,NULL,NULL);
INSERT INTO fieldspecs VALUES (12,'language',13,0,0,1,1,0,128,'da',NULL);
INSERT INTO fieldspecs VALUES (12,'where',22,0,0,1,1,0,128,NULL,NULL);
INSERT INTO fieldspecs VALUES (12,'name_prefix',9,0,0,1,1,0,128,NULL,NULL);
INSERT INTO fieldspecs VALUES (12,'form',11,0,0,1,0,0,128,NULL,NULL);
INSERT INTO fieldspecs VALUES (12,'publish_mode',28,0,0,1,1,0,128,'moderator',NULL);
INSERT INTO fieldspecs VALUES (12,'subscribe_include',15,0,0,1,1,0,128,'0',NULL);
INSERT INTO fieldspecs VALUES (12,'email',24,0,1,1,1,0,128,NULL,NULL);
INSERT INTO fieldspecs VALUES (13,'levels',16,0,0,0,0,0,128,'2',NULL);
INSERT INTO fieldspecs VALUES (14,'mailfrom',24,0,0,0,0,0,128,NULL,NULL);
INSERT INTO fieldspecs VALUES (14,'passwdmsg',9,0,0,0,0,0,128,NULL,NULL);
INSERT INTO fieldspecs VALUES (15,'title',8,0,0,1,1,0,0,NULL,NULL);
INSERT INTO fieldspecs VALUES (15,'short_title',9,0,0,1,1,0,0,NULL,NULL);
INSERT INTO fieldspecs VALUES (15,'docdate',5,0,0,1,1,0,0,NULL,NULL);
INSERT INTO fieldspecs VALUES (15,'expires',6,0,0,1,1,0,0,'9999-01-01 00:00:00',NULL);
INSERT INTO fieldspecs VALUES (15,'published',6,0,0,1,1,1,0,NULL,NULL);
INSERT INTO fieldspecs VALUES (15,'width',17,0,0,0,0,0,0,NULL,NULL);
INSERT INTO fieldspecs VALUES (15,'height',17,0,0,0,0,0,0,NULL,NULL);
INSERT INTO fieldspecs VALUES (15,'align',1,0,0,0,0,0,0,'center',NULL);
INSERT INTO fieldspecs VALUES (15,'data',4,0,0,0,0,0,192,NULL,NULL);
INSERT INTO fieldspecs VALUES (15,'size',17,0,0,0,0,0,0,NULL,NULL);
INSERT INTO fieldspecs VALUES (15,'mimetype',9,0,0,1,1,0,0,NULL,NULL);
INSERT INTO fieldspecs VALUES (15,'seq',12,0,0,0,1,0,0,'-10.00',NULL);
INSERT INTO fieldspecs VALUES (15,'category',2,1,1,1,1,0,128,NULL,NULL);
INSERT INTO fieldspecs VALUES (15,'keyword',3,1,1,1,1,0,128,NULL,NULL);
INSERT INTO fieldspecs VALUES (16,'author',9,0,0,1,1,0,64,NULL,NULL);
INSERT INTO fieldspecs VALUES (16,'teaser',10,0,0,1,0,0,64,NULL,NULL);
INSERT INTO fieldspecs VALUES (16,'url',9,0,0,1,1,0,64,NULL,NULL);
INSERT INTO fieldspecs VALUES (16,'docref',9,0,0,1,1,0,64,NULL,NULL);
INSERT INTO fieldspecs VALUES (16,'source',9,0,0,1,1,0,64,NULL,NULL);
INSERT INTO fieldspecs VALUES (16,'contributors',9,0,0,1,1,0,64,NULL,NULL);
INSERT INTO fieldspecs VALUES (17,'teaser',10,0,0,1,1,0,128,NULL,NULL);
INSERT INTO fieldspecs VALUES (17,'form',11,0,0,1,1,0,128,NULL,NULL);
INSERT INTO fieldspecs VALUES (18,'mailfrom',24,0,0,0,0,0,128,NULL,NULL);
INSERT INTO fieldspecs VALUES (19,'title',8,0,0,1,1,0,0,NULL,NULL);
INSERT INTO fieldspecs VALUES (19,'short_title',9,0,0,1,1,0,0,NULL,NULL);
INSERT INTO fieldspecs VALUES (19,'teaser',10,0,0,1,0,0,64,NULL,NULL);
INSERT INTO fieldspecs VALUES (19,'docdate',5,0,0,1,1,0,0,NULL,NULL);
INSERT INTO fieldspecs VALUES (19,'seq',12,0,0,0,1,0,0,'10.00',NULL);
INSERT INTO fieldspecs VALUES (19,'pagesize',31,0,1,0,0,0,128,NULL,NULL);
INSERT INTO fieldspecs VALUES (19,'sortorder',20,0,0,0,0,0,128,'+id',NULL);
INSERT INTO fieldspecs VALUES (19,'expires',6,0,0,1,1,0,0,'9999-01-01 00:00:00',NULL);
INSERT INTO fieldspecs VALUES (19,'published',6,0,0,1,1,1,128,NULL,NULL);
INSERT INTO fieldspecs VALUES (19,'table',9,0,0,0,0,0,64,NULL,NULL);
INSERT INTO fieldspecs VALUES (19,'fields',10,0,0,0,0,0,64,NULL,NULL);
INSERT INTO fieldspecs VALUES (19,'editcomp',9,0,0,0,0,0,64,NULL,NULL);
INSERT INTO fieldspecs VALUES (19,'newcomp',9,0,0,0,0,0,64,NULL,NULL);
INSERT INTO fieldspecs VALUES (20,'eventtype',9,0,0,1,1,0,64,NULL,NULL);
INSERT INTO fieldspecs VALUES (20,'contactinfo',9,0,0,1,1,0,64,NULL,NULL);
INSERT INTO fieldspecs VALUES (20,'eventtime',9,0,0,1,1,0,64,NULL,NULL);
INSERT INTO fieldspecs VALUES (20,'eventplace',9,0,0,1,1,0,64,NULL,NULL);
INSERT INTO fieldspecs VALUES (20,'eventinfo',10,0,0,1,1,0,128,NULL,NULL);
INSERT INTO fieldspecs VALUES (21,'startdate',5,0,0,0,0,0,128,NULL,NULL);
INSERT INTO fieldspecs VALUES (21,'enddate',5,0,0,0,0,0,128,NULL,NULL);
INSERT INTO fieldspecs VALUES (21,'s_event_type',9,0,0,0,0,0,128,NULL,NULL);
INSERT INTO fieldspecs VALUES (21,'s_event_title',9,0,0,0,0,0,128,NULL,NULL);
INSERT INTO fieldspecs VALUES (21,'s_event_contact',9,0,0,0,0,0,128,NULL,NULL);
INSERT INTO fieldspecs VALUES (21,'s_event_place',9,0,0,0,0,0,128,NULL,NULL);
INSERT INTO fieldspecs VALUES (21,'s_event_info',9,0,0,0,0,0,128,NULL,NULL);
INSERT INTO fieldspecs VALUES (21,'s_event_order_by',30,0,0,0,0,0,128,'-docdate',NULL);
INSERT INTO fieldspecs VALUES (21,'s_event_path',22,0,0,0,0,0,128,NULL,NULL);
INSERT INTO fieldspecs VALUES (21,'show_as',27,0,0,1,0,0,128,'2D',NULL);
INSERT INTO fieldspecs VALUES (22,'author',9,0,0,1,1,0,64,NULL,NULL);
INSERT INTO fieldspecs VALUES (22,'teaser',10,0,0,1,0,0,64,NULL,NULL);
INSERT INTO fieldspecs VALUES (22,'url',9,0,0,1,1,0,64,NULL,NULL);
INSERT INTO fieldspecs VALUES (22,'docref',9,0,0,1,1,0,64,NULL,NULL);
INSERT INTO fieldspecs VALUES (22,'contributors',9,0,0,1,1,0,64,NULL,NULL);
INSERT INTO fieldspecs VALUES (22,'source',9,0,0,1,1,0,64,NULL,NULL);
INSERT INTO fieldspecs VALUES (22,'logo',22,0,1,1,1,0,128,NULL,NULL);
INSERT INTO fieldspecs VALUES (22,'picture',22,0,1,1,1,0,128,NULL,NULL);
INSERT INTO fieldspecs VALUES (22,'votebox',22,0,1,1,1,0,128,NULL,NULL);
INSERT INTO fieldspecs VALUES (22,'show_teasers',15,0,0,1,1,0,128,'0',NULL);

--
-- Table structure for table 'fieldtypes'
--

DROP TABLE IF EXISTS fieldtypes;
CREATE TABLE fieldtypes (
  id int(8) unsigned NOT NULL auto_increment,
  name varchar(127) NOT NULL default '',
  edit varchar(127) NOT NULL default 'line',
  edit_args text NOT NULL,
  validate varchar(127) NOT NULL default 'none',
  validate_args text NOT NULL,
  search varchar(127) NOT NULL default 'none',
  search_args text NOT NULL,
  bin tinyint(1) NOT NULL default '0',
  value_field enum('text','int','double','date') NOT NULL default 'text',
  PRIMARY KEY  (id),
  UNIQUE KEY name (name)
) TYPE=MyISAM;

--
-- Dumping data for table 'fieldtypes'
--


INSERT INTO fieldtypes VALUES (1,'halign','radio','right|left|center','regexp','^(right|left|center)$','none','',0,'text');
INSERT INTO fieldtypes VALUES (2,'category','category','categories.id','xref','categories.id','none','',0,'text');
INSERT INTO fieldtypes VALUES (3,'keyword','keyword','keywords.id','xref','keywords.id','matchColumn','name',0,'int');
INSERT INTO fieldtypes VALUES (4,'imagedata','imageupload','','none','','none','',1,'text');
INSERT INTO fieldtypes VALUES (5,'date','date','','regexp','^\\d\\d\\d\\d-\\d\\d-\\d\\d( 00:00:00)?$','none','',0,'date');
INSERT INTO fieldtypes VALUES (6,'datetime','datetime','','regexp','^\\d\\d\\d\\d-\\d\\d-\\d\\d \\d\\d:\\d\\d:\\d\\d$','none','',0,'date');
INSERT INTO fieldtypes VALUES (7,'time','time','','regexp','^\\d\\d:\\d\\d:\\d\\d$','none','',0,'date');
INSERT INTO fieldtypes VALUES (8,'title','line','','regexp','.','none','',0,'text');
INSERT INTO fieldtypes VALUES (9,'line','line','','none','','none','',0,'text');
INSERT INTO fieldtypes VALUES (10,'text','texteditor','','none','','none','',0,'text');
INSERT INTO fieldtypes VALUES (11,'textwupload','textwupload','','none','','none','',0,'text');
INSERT INTO fieldtypes VALUES (12,'double','line','','regexp','^-?\\d+(\\.\\d+)?','none','',0,'double');
INSERT INTO fieldtypes VALUES (13,'lang','line','','regexp','^\\w\\w$','none','',0,'text');
INSERT INTO fieldtypes VALUES (14,'require','radio','normal|teaser|fullinfo','regexp','^(teaser|fullinfo|normal)$','none','',0,'text');
INSERT INTO fieldtypes VALUES (15,'bool','radio','0|1','regexp','^[01]$','none','',0,'int');
INSERT INTO fieldtypes VALUES (16,'int>0','line','','regexp','^[1-9]\\d*$','none','',0,'int');
INSERT INTO fieldtypes VALUES (17,'int>=0','line','','regexp','^\\d+$','none','',0,'int');
INSERT INTO fieldtypes VALUES (18,'int','line','','regexp','^-?\\d+$','none','',0,'int');
INSERT INTO fieldtypes VALUES (19,'appdata','fileupload','','none','','none','',1,'text');
INSERT INTO fieldtypes VALUES (20,'sortorder','sortorder','','regexp','.','none','',0,'text');
INSERT INTO fieldtypes VALUES (21,'template','xref','templates.id','xref','templates.id','none','',0,'int');
INSERT INTO fieldtypes VALUES (22,'path','path','','special','DocumentPathCheck','none','',0,'int');
INSERT INTO fieldtypes VALUES (23,'searchtype','radio','keyword|category|month|weeks','regexp','^(keyword|category|month|weeks)$','none','',0,'text');
INSERT INTO fieldtypes VALUES (24,'email','line','','regexp','^[^@]+@[^@]+\\.\\w+$','none','',0,'text');
INSERT INTO fieldtypes VALUES (25,'priority','radio','0|1|2|3','regexp','^[0123]$','none','',0,'int');
INSERT INTO fieldtypes VALUES (26,'subscribeable','radio','none|automatic|manual','regexp','^(none|automatic|manual)$','none','',0,'text');
INSERT INTO fieldtypes VALUES (27,'showcal','radio','2D|list','regexp','^(2D|list)$','none','',0,'text');
INSERT INTO fieldtypes VALUES (28,'publishmode','radio','immediate|moderator','regexp','^(immediate|moderator)$','none','',0,'text');
INSERT INTO fieldtypes VALUES (29,'publish_on','publishon','','regexp','^\\d\\d\\d\\d-\\d\\d-\\d\\d \\d\\d:\\d\\d:\\d\\d$','none','',0,'date');
INSERT INTO fieldtypes VALUES (30,'orderevents','radio','+title|-docdate|+docdate|+eventtype|+contactinfo','regexp','^(+title|-docdate|+docdate|+eventtype|+contactinfo)$','none','',0,'text');
INSERT INTO fieldtypes VALUES (31,'pagesize','pagesize','','regexp','^\\d+$','none','',0,'int');

--
-- Table structure for table 'groups'
--

DROP TABLE IF EXISTS groups;
CREATE TABLE groups (
  id smallint(5) unsigned NOT NULL auto_increment,
  name char(31) NOT NULL default '',
  PRIMARY KEY  (id),
  UNIQUE KEY name (name)
) TYPE=MyISAM;

--
-- Dumping data for table 'groups'
--


INSERT INTO groups VALUES (1,'Admin');
INSERT INTO groups VALUES (2,'No-one');

--
-- Table structure for table 'grp_user'
--

DROP TABLE IF EXISTS grp_user;
CREATE TABLE grp_user (
  grp smallint(5) unsigned NOT NULL default '0',
  user smallint(5) unsigned NOT NULL default '0',
  PRIMARY KEY  (grp,user)
) TYPE=MyISAM;

--
-- Dumping data for table 'grp_user'
--


INSERT INTO grp_user VALUES (1,1);
INSERT INTO grp_user VALUES (2,2);

--
-- Table structure for table 'keywords'
--

DROP TABLE IF EXISTS keywords;
CREATE TABLE keywords (
  id smallint(5) unsigned NOT NULL auto_increment,
  name char(63) NOT NULL default '',
  PRIMARY KEY  (id),
  UNIQUE KEY keyword (name)
) TYPE=MyISAM;

--
-- Dumping data for table 'keywords'
--



--
-- Table structure for table 'subscribers'
--

DROP TABLE IF EXISTS subscribers;
CREATE TABLE subscribers (
  id int(10) unsigned NOT NULL auto_increment,
  name varchar(127) NOT NULL default '',
  company varchar(127) NOT NULL default '',
  passwd varchar(63) NOT NULL default '',
  email varchar(63) NOT NULL default '',
  suspended tinyint(3) NOT NULL default '0',
  cookie varchar(64) NOT NULL default '',
  PRIMARY KEY  (id),
  UNIQUE KEY email (email)
) TYPE=MyISAM;

--
-- Dumping data for table 'subscribers'
--



--
-- Table structure for table 'subscriptions'
--

DROP TABLE IF EXISTS subscriptions;
CREATE TABLE subscriptions (
  docid int(8) unsigned NOT NULL default '0',
  subscriber int(10) unsigned NOT NULL default '0',
  last_update datetime NOT NULL default '0000-00-00 00:00:00',
  PRIMARY KEY  (docid,subscriber)
) TYPE=MyISAM;

--
-- Dumping data for table 'subscriptions'
--



--
-- Table structure for table 'synonyms'
--

DROP TABLE IF EXISTS synonyms;
CREATE TABLE synonyms (
  id int(8) unsigned NOT NULL auto_increment,
  synonyms text NOT NULL,
  PRIMARY KEY  (id)
) TYPE=MyISAM PACK_KEYS=1;

--
-- Dumping data for table 'synonyms'
--



--
-- Table structure for table 'users'
--

DROP TABLE IF EXISTS users;
CREATE TABLE users (
  id smallint(5) unsigned NOT NULL auto_increment,
  login varchar(31) NOT NULL default '',
  passwd varchar(63) NOT NULL default '',
  name varchar(127) NOT NULL default '',
  email varchar(127) NOT NULL default '',
  notes text NOT NULL,
  PRIMARY KEY  (id),
  UNIQUE KEY login (login)
) TYPE=MyISAM;

--
-- Dumping data for table 'users'
--


INSERT INTO users VALUES (1,'admin','$1$safdasdf$hjqFW5Yb3JysogKILEjBd.','Admin','webmaster@${domain}','');
INSERT INTO users VALUES (2,'nobody','$1$safdasdf$1nrCPtQuzQdXcU74o11Tk/','Nobody','nobody@${domain}','');

--
-- Table structure for table 'versions'
--

DROP TABLE IF EXISTS versions;
CREATE TABLE versions (
  docid int(8) unsigned NOT NULL default '0',
  version datetime NOT NULL default '0000-00-00 00:00:00',
  type int(8) unsigned NOT NULL default '0',
  public tinyint(8) NOT NULL default '0',
  valid tinyint(8) NOT NULL default '0',
  lang char(2) NOT NULL default 'da',
  PRIMARY KEY  (docid,version),
  KEY type (type)
) TYPE=MyISAM;

--
-- Dumping data for table 'versions'
--


INSERT INTO versions VALUES (1,'2003-03-28 10:50:51',2,1,0,'da');
INSERT INTO versions VALUES (2,'2003-03-31 13:20:22',17,0,0,'da');
INSERT INTO versions VALUES (2,'2003-03-31 13:20:33',17,0,0,'da');
INSERT INTO versions VALUES (3,'2003-03-31 13:21:54',6,0,0,'da');
INSERT INTO versions VALUES (3,'2003-03-31 13:23:10',6,0,0,'da');
INSERT INTO versions VALUES (4,'2003-03-31 13:25:14',19,0,0,'da');
INSERT INTO versions VALUES (5,'2003-03-31 13:27:33',19,0,0,'da');
INSERT INTO versions VALUES (6,'2003-03-31 13:29:32',19,0,0,'da');
INSERT INTO versions VALUES (7,'2003-03-31 13:31:22',13,1,0,'da');

--
-- Table structure for table 'vfields'
--

DROP TABLE IF EXISTS vfields;
CREATE TABLE vfields (
  docid int(8) unsigned NOT NULL default '0',
  version datetime NOT NULL default '0000-00-00 00:00:00',
  name varchar(127) NOT NULL default '',
  text_value longtext,
  int_value int(8) default NULL,
  double_value double default NULL,
  date_value datetime default NULL,
  KEY docid (docid,version,name),
  KEY name (name,text_value(16)),
  KEY name_2 (name,int_value),
  KEY name_3 (name,double_value),
  KEY name_4 (name,date_value)
) TYPE=MyISAM;

--
-- Dumping data for table 'vfields'
--


INSERT INTO vfields VALUES (1,'2003-03-28 10:50:51','SOURCE','Obvius',NULL,NULL,NULL);
INSERT INTO vfields VALUES (1,'2003-03-28 10:50:51','MIMETYPE','',NULL,NULL,NULL);
INSERT INTO vfields VALUES (1,'2003-03-28 10:50:51','DOCREF','',NULL,NULL,NULL);
INSERT INTO vfields VALUES (1,'2003-03-28 10:50:51','SORTORDER','+seq',NULL,NULL,NULL);
INSERT INTO vfields VALUES (1,'2003-03-28 10:50:51','EXPIRES',NULL,NULL,NULL,'9999-01-01 00:00:00');
INSERT INTO vfields VALUES (1,'2003-03-28 10:50:51','TITLE','Forside',NULL,NULL,NULL);
INSERT INTO vfields VALUES (1,'2003-03-28 10:50:51','CONTENT','This is the frontpage (root-document)',NULL,NULL,NULL);
INSERT INTO vfields VALUES (1,'2003-03-28 10:50:51','DOCDATE',NULL,NULL,NULL,'2003-03-28 00:00:00');
INSERT INTO vfields VALUES (1,'2003-03-28 10:50:51','AUTHOR','create_root',NULL,NULL,NULL);
INSERT INTO vfields VALUES (1,'2003-03-28 10:50:51','URL','',NULL,NULL,NULL);
INSERT INTO vfields VALUES (1,'2003-03-28 10:50:51','TEASER','Frontpage',NULL,NULL,NULL);
INSERT INTO vfields VALUES (1,'2003-03-28 10:50:51','SUBSCRIBEABLE','none',NULL,NULL,NULL);
INSERT INTO vfields VALUES (1,'2003-03-28 10:50:51','SHORT_TITLE','Forside',NULL,NULL,NULL);
INSERT INTO vfields VALUES (1,'2003-03-28 10:50:51','SEQ',NULL,NULL,0,NULL);
INSERT INTO vfields VALUES (1,'2003-03-28 10:50:51','CONTRIBUTORS','',NULL,NULL,NULL);
INSERT INTO vfields VALUES (1,'2003-03-28 10:50:51','SECTION_NEWS',NULL,NULL,NULL,NULL);
INSERT INTO vfields VALUES (1,'2003-03-28 10:50:51','PUBLISHED',NULL,NULL,NULL,'2003-03-28 15:39:44');
INSERT INTO vfields VALUES (1,'2003-03-28 10:50:51','SEC_PRIO',NULL,0,NULL,NULL);
INSERT INTO vfields VALUES (1,'2003-03-28 10:50:51','FRONT_PRIO',NULL,0,NULL,NULL);
INSERT INTO vfields VALUES (1,'2003-03-28 10:50:51','SEC',NULL,0,NULL,NULL);
INSERT INTO vfields VALUES (1,'2003-03-28 10:50:51','SEC_DURA',NULL,0,NULL,NULL);
INSERT INTO vfields VALUES (1,'2003-03-28 10:50:51','IN_SUBSCRIPTION',NULL,0,NULL,NULL);
INSERT INTO vfields VALUES (1,'2003-03-28 10:50:51','PUBLISH_ON',NULL,NULL,NULL,'0000-00-00 00:00:00');
INSERT INTO vfields VALUES (1,'2003-03-28 10:50:51','FRONT_DURA',NULL,0,NULL,NULL);
INSERT INTO vfields VALUES (2,'2003-03-31 13:20:22','DOCDATE',NULL,NULL,NULL,'2003-03-31 00:00:00');
INSERT INTO vfields VALUES (2,'2003-03-31 13:20:22','SUBSCRIBEABLE','none',NULL,NULL,NULL);
INSERT INTO vfields VALUES (2,'2003-03-31 13:20:22','SORTORDER','+seq,+title',NULL,NULL,NULL);
INSERT INTO vfields VALUES (2,'2003-03-31 13:20:22','SHORT_TITLE','Admins�g',NULL,NULL,NULL);
INSERT INTO vfields VALUES (2,'2003-03-31 13:20:22','EXPIRES',NULL,NULL,NULL,'9999-01-01 00:00:00');
INSERT INTO vfields VALUES (2,'2003-03-31 13:20:22','SEQ',NULL,NULL,10,NULL);
INSERT INTO vfields VALUES (2,'2003-03-31 13:20:22','TITLE','Admins�g',NULL,NULL,NULL);
INSERT INTO vfields VALUES (2,'2003-03-31 13:20:22','MIMETYPE',NULL,NULL,NULL,NULL);
INSERT INTO vfields VALUES (2,'2003-03-31 13:20:22','TEASER',NULL,NULL,NULL,NULL);
INSERT INTO vfields VALUES (2,'2003-03-31 13:20:22','FORM',NULL,NULL,NULL,NULL);
INSERT INTO vfields VALUES (2,'2003-03-31 13:20:33','DOCDATE',NULL,NULL,NULL,'2003-03-31 00:00:00');
INSERT INTO vfields VALUES (2,'2003-03-31 13:20:33','SUBSCRIBEABLE','none',NULL,NULL,NULL);
INSERT INTO vfields VALUES (2,'2003-03-31 13:20:33','SORTORDER','+seq,+title',NULL,NULL,NULL);
INSERT INTO vfields VALUES (2,'2003-03-31 13:20:33','SHORT_TITLE','Admins�g',NULL,NULL,NULL);
INSERT INTO vfields VALUES (2,'2003-03-31 13:20:33','EXPIRES',NULL,NULL,NULL,'9999-01-01 00:00:00');
INSERT INTO vfields VALUES (2,'2003-03-31 13:20:33','SEQ',NULL,NULL,-10,NULL);
INSERT INTO vfields VALUES (2,'2003-03-31 13:20:33','PAGESIZE',NULL,0,NULL,NULL);
INSERT INTO vfields VALUES (2,'2003-03-31 13:20:33','TITLE','Admins�g',NULL,NULL,NULL);
INSERT INTO vfields VALUES (2,'2003-03-31 13:20:33','MIMETYPE',NULL,NULL,NULL,NULL);
INSERT INTO vfields VALUES (2,'2003-03-31 13:20:33','TEASER',NULL,NULL,NULL,NULL);
INSERT INTO vfields VALUES (2,'2003-03-31 13:20:33','FORM',NULL,NULL,NULL,NULL);
INSERT INTO vfields VALUES (3,'2003-03-31 13:21:54','SORTORDER','+seq,+title',NULL,NULL,NULL);
INSERT INTO vfields VALUES (3,'2003-03-31 13:21:54','EXPIRES',NULL,NULL,NULL,'9999-01-01 00:00:00');
INSERT INTO vfields VALUES (3,'2003-03-31 13:21:54','TITLE','Administration',NULL,NULL,NULL);
INSERT INTO vfields VALUES (3,'2003-03-31 13:21:54','DOCDATE',NULL,NULL,NULL,'2003-03-31 00:00:00');
INSERT INTO vfields VALUES (3,'2003-03-31 13:21:54','SHORT_TITLE','Administration',NULL,NULL,NULL);
INSERT INTO vfields VALUES (3,'2003-03-31 13:21:54','SUBSCRIBEABLE','none',NULL,NULL,NULL);
INSERT INTO vfields VALUES (3,'2003-03-31 13:21:54','SEQ',NULL,NULL,-100,NULL);
INSERT INTO vfields VALUES (3,'2003-03-31 13:21:54','PAGESIZE',NULL,0,NULL,NULL);
INSERT INTO vfields VALUES (3,'2003-03-31 13:21:54','BARE',NULL,0,NULL,NULL);
INSERT INTO vfields VALUES (3,'2003-03-31 13:21:54','SOURCE',NULL,NULL,NULL,NULL);
INSERT INTO vfields VALUES (3,'2003-03-31 13:21:54','MIMETYPE',NULL,NULL,NULL,NULL);
INSERT INTO vfields VALUES (3,'2003-03-31 13:21:54','DOCREF',NULL,NULL,NULL,NULL);
INSERT INTO vfields VALUES (3,'2003-03-31 13:21:54','HTML_CONTENT',NULL,NULL,NULL,NULL);
INSERT INTO vfields VALUES (3,'2003-03-31 13:21:54','AUTHOR',NULL,NULL,NULL,NULL);
INSERT INTO vfields VALUES (3,'2003-03-31 13:21:54','URL',NULL,NULL,NULL,NULL);
INSERT INTO vfields VALUES (3,'2003-03-31 13:21:54','TEASER',NULL,NULL,NULL,NULL);
INSERT INTO vfields VALUES (3,'2003-03-31 13:21:54','CONTRIBUTORS',NULL,NULL,NULL,NULL);
INSERT INTO vfields VALUES (3,'2003-03-31 13:23:10','HTML_CONTENT','<p>\nAdministration af brugere, grupper, abonnenter og login-adgang:\n<ul>\n<li><a href=\"users/\">Brugere</a>\n<li><a href=\"groups/\">Grupper</a>\n<li><a href=\"subscribers/\">Abonnenter</a>\n</ul>\n</p>\n\n<p>\nServer-cache:\n<ul>\n<li><a href=\"./?mcms_op=clear_cache\">Ryd server-cache</a>.\n</ul>\n</p>\n\n<p>\nAdminJump:\n</p>\n\n<p>\nH�jreklik p� AdminJump-linket nedenfor og v�lg \"F�j til foretrukne...\".  Hvis v�rkt�jslinien \"Hyperlinks\" ikke er sl�et til, s� g�r det i menuen \"Vis/V�rkt�jslinier/Hyperlinks\" - og tr�k derefter linket fra foretrukne menuen ned i v�rkt�jslinien. Knappen \"AdminJump\" i v�rkt�jslinien kan nu bruges til at hoppe direkte fra en side p� det offentlige website og til administrationsdelens tilsvarende side (og tilbage igen).\n<ul>\n<li><a href=\"javascript:q=location.href;if(q&&q!=%22%22){q=String(q);r=new RegExp(%22http[s]?(://[^/]*/)(.*)%22);m=q.match(r);if(m){admin=%22admin/%22;ra=new RegExp(%22admin/(
