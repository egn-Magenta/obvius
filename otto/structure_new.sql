#
# Obvius database test structure
#
# $Id$
#

DROP TABLE IF EXISTS documents;
CREATE TABLE documents (
  id int(8) unsigned DEFAULT '0' NOT NULL auto_increment,
  parent int(8) unsigned DEFAULT '0' NOT NULL,
  name char(127) DEFAULT '' NOT NULL,
  type int(8) unsigned NOT NULL,
  owner smallint(5) unsigned DEFAULT '0' NOT NULL,
  grp smallint(5) unsigned DEFAULT '0' NOT NULL,
#	accessrules text,
  operms set('create','delete','edit','modes','publish') DEFAULT 'create,delete,edit,modes,publish' NOT NULL,
  gperms set('create','delete','edit','modes','publish') DEFAULT 'create,delete,edit' NOT NULL,
  PRIMARY KEY (id),
  UNIQUE parent (parent,name) # parent?
) type=MyISAM;

DROP TABLE IF EXISTS docparms;
CREATE TABLE docparms (
  docid int(8) unsigned NOT NULL,
  name varchar(127) DEFAULT '' NOT NULL,
  value longtext DEFAULT '',
  type int(8) unsigned NOT NULL
) type=MyISAM;

DROP TABLE IF EXISTS versions;
CREATE TABLE versions (
  docid int(8) unsigned NOT NULL,
  version datetime DEFAULT '0000-00-00 00:00:00' NOT NULL,
#  published datetime DEFAULT '0000-00-00 00:00:00' NOT NULL,
	type int(8) unsigned NOT NULL,
  public tinyint(8) DEFAULT '0' NOT NULL,
  valid tinyint(8) DEFAULT '0' NOT NULL,
  lang char(2) DEFAULT 'da' NOT NULL,
  PRIMARY KEY (docid, version)
) type=MyISAM;

DROP TABLE IF EXISTS vfields;
CREATE TABLE vfields (
  docid int(8) unsigned NOT NULL,
  version datetime NOT NULL,
  name varchar(127) DEFAULT '' NOT NULL,
  text_value longtext,			# Text value (corresponds with fieldtypes.value_field)
  int_value int(8),					# Numerical value
  double_value double,			# Real number value
	date_value datetime,			# date and time value
  KEY (docid, version, name)
) type=MyISAM;

DROP TABLE IF EXISTS doctypes;
CREATE TABLE doctypes (
  id int(8) unsigned DEFAULT '0' NOT NULL auto_increment,
  name varchar(127) DEFAULT '' NOT NULL,
  parent int(8) unsigned NOT NULL,
  basis int(1) unsigned DEFAULT '0' NOT NULL,
  searchable int(1) DEFAULT '1' NOT NULL,
  sortorder_field_is varchar(127),
  UNIQUE KEY name (name),
  PRIMARY KEY (id)
) type=MyISAM;

DROP TABLE IF EXISTS fieldspecs;
CREATE TABLE fieldspecs (
  doctypeid int(8) unsigned NOT NULL,
  name varchar(127) DEFAULT '' NOT NULL,
  type int(8) unsigned NOT NULL,
  repeatable tinyint(1) unsigned NOT NULL,
  optional tinyint(1) unsigned NOT NULL,
  searchable tinyint(1) unsigned NOT NULL,
  sortable tinyint(1) unsigned NOT NULL,
  publish tinyint(1) unsigned NOT NULL,
  threshold tinyint(1) unsigned DEFAULT 128 NOT NULL,
  default_value text,
	extra text,
  PRIMARY KEY (doctypeid, name)
) type=MyISAM;

DROP TABLE IF EXISTS fieldtypes;
CREATE TABLE fieldtypes (
  id int(8) unsigned DEFAULT '0' NOT NULL auto_increment,
  name varchar(127) DEFAULT '' NOT NULL,
  edit varchar(127) DEFAULT 'line' NOT NULL,
	edit_args text DEFAULT '' NOT NULL,
  validate varchar(127) DEFAULT 'none' NOT NULL,
	validate_args text DEFAULT '' NOT NULL,
  search varchar(127) DEFAULT 'none' NOT NULL,
	search_args text DEFAULT '' NOT NULL,
	bin tinyint(1) DEFAULT 0 NOT NULL,
	value_field enum('text','int','double','date') DEFAULT 'text' NOT NULL,
  PRIMARY KEY (id),
	UNIQUE (name)
) type=MyISAM;

DROP TABLE IF EXISTS editpages;
CREATE TABLE editpages (
  doctypeid int(8) unsigned NOT NULL,
  page char(5) NOT NULL,
	title varchar(127) DEFAULT '' NOT NULL,
	description text DEFAULT '' NOT NULL,
	fieldlist text DEFAULT '' NOT NULL,
  PRIMARY KEY (doctypeid, page)
) type=MyISAM;

# Same, same:

DROP TABLE IF EXISTS categories;
CREATE TABLE categories (
  id char(9) DEFAULT '' NOT NULL,
  name char(127) DEFAULT '' NOT NULL,
  PRIMARY KEY (id)
) type=MyISAM;

DROP TABLE IF EXISTS keywords;
CREATE TABLE keywords (
  id smallint(5) unsigned DEFAULT '0' NOT NULL auto_increment,
  name char(63) DEFAULT '' NOT NULL,
  PRIMARY KEY (id),
  UNIQUE keyword (name)
) type=MyISAM;

DROP TABLE IF EXISTS users;
CREATE TABLE users (
  id smallint(5) unsigned DEFAULT '0' NOT NULL auto_increment,
  login varchar(31) DEFAULT '' NOT NULL,
  passwd varchar(63) DEFAULT '' NOT NULL,
  name varchar(127) DEFAULT '' NOT NULL,
  email varchar(127) DEFAULT '' NOT NULL,
  db_login varchar(31) DEFAULT '' NOT NULL,
  db_passw varchar(127) DEFAULT '' NOT NULL,
  notes text NOT NULL,
  perms set('create','delete','edit','modes','publish') DEFAULT '' NOT NULL,
  PRIMARY KEY (id),
  UNIQUE login (login)
) type=MyISAM;

DROP TABLE IF EXISTS groups;
CREATE TABLE groups (
  id smallint(5) unsigned DEFAULT '0' NOT NULL auto_increment,
  name char(31) DEFAULT '' NOT NULL,
  PRIMARY KEY (id),
  UNIQUE name (name)
) type=MyISAM;

DROP TABLE IF EXISTS grp_user;
CREATE TABLE grp_user (
  grp smallint(5) unsigned DEFAULT '0' NOT NULL,
  user smallint(5) unsigned DEFAULT '0' NOT NULL,
  PRIMARY KEY (grp,user)
) type=MyISAM;

DROP TABLE IF EXISTS subscribers;
CREATE TABLE subscribers (
  id int(10) unsigned DEFAULT '0' NOT NULL auto_increment,
  name varchar(127) DEFAULT '' NOT NULL,
  company varchar(127) DEFAULT '' NOT NULL,
  passwd varchar(63) DEFAULT '' NOT NULL,
  email varchar(63) DEFAULT '' NOT NULL,
  suspended tinyint(3) DEFAULT '0' NOT NULL,
  cookie char(64) NOT NULL default '',
  PRIMARY KEY (id),
  UNIQUE email (email)
) type=MyISAM;

DROP TABLE IF EXISTS subscriptions;
CREATE TABLE subscriptions (
  docid int(8) unsigned DEFAULT '0' NOT NULL,
  subscriber int(10) unsigned DEFAULT '0' NOT NULL,
  last_update datetime DEFAULT '0000-00-00 00:00:00' NOT NULL,
  PRIMARY KEY (docid,subscriber)
) type=MyISAM;

DROP TABLE IF EXISTS templates;
CREATE TABLE templates (
  id smallint(5) unsigned DEFAULT '0' NOT NULL auto_increment,
  name varchar(63) DEFAULT '' NOT NULL,
  file varchar(127) DEFAULT '' NOT NULL,
  PRIMARY KEY (id),
  UNIQUE name (name)
);

DROP TABLE IF EXISTS config;
CREATE TABLE config (
  name varchar(127) NOT NULL,
  value varchar(127) NOT NULL,
  descriptions text,
  PRIMARY KEY (name)
) type=MyISAM;

DROP TABLE IF EXISTS voters;
CREATE TABLE voters (
  docid int(8) unsigned NOT NULL default '0',
  cookie char(64) NOT NULL default '',
  PRIMARY KEY  (docid,cookie)
) TYPE=MyISAM PACK_KEYS=1;

DROP TABLE IF EXISTS votes;
CREATE TABLE votes (
  docid int(8) unsigned NOT NULL default '0',
  answer char(32) NOT NULL default '',
  total int(10) unsigned NOT NULL default '0',
  PRIMARY KEY  (docid,answer)
) TYPE=MyISAM PACK_KEYS=1;


#
# Default data:
#

# Config:
INSERT INTO config VALUES ('normal_db_user',       'dcmr', '');
INSERT INTO config VALUES ('normal_db_passwd',     'cabcc10b06e91ca2', '');
INSERT INTO config VALUES ('privileged_db_login',  'dcmr_admin', '');
INSERT INTO config VALUES ('privileged_db_passwd', 'a691cb2c323e07c2', '');
INSERT INTO config VALUES ('administrator',        'admin', '');

## DocTypes: brug add_doctypes.pl i stedet            par  basi  sear edi publish_page_seq
#INSERT INTO doctypes VALUES ( '1', 'Base',           '0' , '1', '1', '', '' );
#INSERT INTO doctypes VALUES ( '2', 'Standard',       '1' , '1', '1', '', '' );
#INSERT INTO doctypes VALUES ( '3', 'Search',         '1' , '1', '1', '', '' );
#INSERT INTO doctypes VALUES ( '4', 'ComboSearch',    '3' , '1', '1', '', '' );
#INSERT INTO doctypes VALUES ( '5', 'KeywordSearch',  '3' , '1', '1', '', '' );
#INSERT INTO doctypes VALUES ( '6', 'DBSearch',       '3' , '1', '1', '', '' );
#INSERT INTO doctypes VALUES ( '7', 'Subscribe',      '1' , '1', '1', '', '' );
#INSERT INTO doctypes VALUES ( '8', 'CreateDocument', '1' , '1', '1', '', '' );
#INSERT INTO doctypes VALUES ( '9', 'Sitemap',        '1' , '1', '1', '', '' );
#INSERT INTO doctypes VALUES ('10', 'MultiChoice',    '1' , '1', '1', '', '' );
#INSERT INTO doctypes VALUES ('11', 'Quiz',           '1' , '1', '1', '', '' );
#INSERT INTO doctypes VALUES ('12', 'Event',          '1' , '1', '1', '', '' );
#INSERT INTO doctypes VALUES ('13', 'HTML',           '1' , '1', '1', '', '' );
#INSERT INTO doctypes VALUES ('14', 'Link',           '1' , '1', '1', '', '' );
#INSERT INTO doctypes VALUES ('15', 'Upload',         '1' , '1', '1', '', '' );
## INSERT INTO doctypes VALUES ('16', 'Image',          '15', '1', '1', '', '' ); #?

# DocParms                     docid name           val type
INSERT INTO docparms VALUES ( '1', 'subname',       '', '1');
INSERT INTO docparms VALUES ( '1', 'mini_icon',     '', '6');

## base                         dtyid name             type rep sear sort publ page seq  default
#INSERT INTO fieldspecs VALUES ( '1', 'title',         '1', '0', '1', '1', '0', '1', '0', '');
#INSERT INTO fieldspecs VALUES ( '1', 'teaser',        '1', '0', '1', '0', '0', '1', '0', '');
#INSERT INTO fieldspecs VALUES ( '1', 'category',      '2', '1', '1', '1', '0', '1', '0', '');
#INSERT INTO fieldspecs VALUES ( '1', 'keyword',       '2', '1', '1', '1', '0', '1', '0', '');
#INSERT INTO fieldspecs VALUES ( '1', 'docdate',       '1', '0', '1', '1', '0', '1', '0', '');
#INSERT INTO fieldspecs VALUES ( '1', 'seq',           '3', '0', '0', '1', '0', '1', '0', '0.00');
#INSERT INTO fieldspecs VALUES ( '1', 'pagesize',      '2', '0', '0', '0', '0', '1', '0', '');
#INSERT INTO fieldspecs VALUES ( '1', 'sortorder',     '1', '0', '0', '0', '0', '1', '0', 'sequence');
#INSERT INTO fieldspecs VALUES ( '1', 'subscribeable', '2', '0', '0', '0', '0', '1', '0', '');
#INSERT INTO fieldspecs VALUES ( '1', 'expires',       '5', '0', '1', '1', '1', '1', '0', '9999-01-01 00:00:00');
#INSERT INTO fieldspecs VALUES ( '1', 'published',     '5', '0', '1', '1', '1', '1', '0', '');
#INSERT INTO fieldspecs VALUES ( '1', 'gprio',         '2', '0', '1', '1', '1', '1', '0', '');
#INSERT INTO fieldspecs VALUES ( '1', 'gduration',     '2', '0', '1', '1', '1', '1', '0', '');
#INSERT INTO fieldspecs VALUES ( '1', 'lprio',         '2', '0', '1', '1', '1', '1', '0', '');
#INSERT INTO fieldspecs VALUES ( '1', 'lduration',     '2', '0', '1', '1', '1', '1', '0', '');
#INSERT INTO fieldspecs VALUES ( '1', 'lsection',      '2', '0', '1', '1', '1', '1', '0', '');

## standard                      dtyid name             type rep sear sort publ page seq default
#INSERT INTO fieldspecs VALUES ( '2', 'author',        '1', '0', '1', '1', '0', '1', '0', '');
#INSERT INTO fieldspecs VALUES ( '2', 'short_title',   '1', '0', '1', '1', '0', '1', '0', '');
#INSERT INTO fieldspecs VALUES ( '2', 'content',       '1', '0', '1', '1', '0', '1', '0', '');
#INSERT INTO fieldspecs VALUES ( '2', 'url',           '1', '0', '1', '1', '0', '1', '0', '');
#INSERT INTO fieldspecs VALUES ( '2', 'docref',        '1', '0', '1', '1', '0', '1', '0', '');
#INSERT INTO fieldspecs VALUES ( '2', 'contributors',  '1', '0', '1', '1', '0', '1', '0', '');
#INSERT INTO fieldspecs VALUES ( '2', 'source',        '1', '0', '1', '1', '0', '1', '0', '');
#INSERT INTO fieldspecs VALUES ( '2', 'image',         '6', '0', '0', '0', '0', '1', '0', '');
##  legacy
##INSERT INTO fieldspecs VALUES ( '2', 'helptext',      '1', '0', '0', '0', '1', '1', '0', '');
##INSERT INTO fieldspecs VALUES ( '2', 'default_op',    '1', '0', '0', '0', '1', '1', '0', '');
##INSERT INTO fieldspecs VALUES ( '2', 'template_filter', '1', '0', '0', '0', '1', '1', '0', '');
##INSERT INTO fieldspecs VALUES ( '2', 'template',      '1', '0', '0', '0', '1', '1', '0', '');

## search                       dtyid name                 type rep sear sort publ page seq default
#INSERT INTO fieldspecs VALUES ( '3', 'search_expression', '1', '0', '0', '0', '0', '1', '0', '');

## combo search                  dtyid name             type rep sear sort publ page seq default
#INSERT INTO fieldspecs VALUES ( '4', 'require',        '1', '1', '0', '0', '0', '1', '0', '');

## keyword search                dtyid name             type rep sear sort publ page seq default
#INSERT INTO fieldspecs VALUES ( '5', 'base',           '1', '0', '0', '0', '1', '1', '0', '');

## HTML                          dtyid name             type rep sear sort publ page seq default
#INSERT INTO fieldspecs VALUES ('13', 'bare',           '4', '0', '0', '0', '0', '0', '0', '1');

## Upload
#INSERT INTO fieldspecs VALUES ('15', 'mimetype',       '1', '0', '1', '0', '0', '1', '0', '');
#INSERT INTO fieldspecs VALUES ('15', 'data',           '6', '0', '0', '0', '0', '1', '0', '');


## Default users:
# INSERT INTO users VALUES ( '1', 'admin', 'admin', 'Adminstrator', 'webmaster@menneskeret.dk', '', '', '', 'create,delete,edit,modes,publish');
# INSERT INTO users VALUES ( '2', 'rene', 'Rene@Seindal', 'René Seindal', 'rene@magenta-aps.dk', '', '', '', 'create,delete,edit,modes,publish');

## Default groups:
# INSERT INTO groups VALUES ( '1', 'Admin');

## Types: brug add_fieldtypes.pl i stedet
#INSERT INTO fieldtypes VALUES ( '1', 'line', 'line', '', 'none', '');
#INSERT INTO fieldtypes VALUES ( '2', 'text', 'text', '', 'none', '');
#INSERT INTO fieldtypes VALUES ( '3', 'int', 'line', '', 'regexp', '^\\d+$');
#INSERT INTO fieldtypes VALUES ( '4', 'double', 'line', '', 'none', '');
#INSERT INTO fieldtypes VALUES ( '5', 'bool', 'radio', '', 'none', '');
#INSERT INTO fieldtypes VALUES ( '6', 'date', 'line', '', 'none', '');
#INSERT INTO fieldtypes VALUES ( '7', 'date_time', 'line', '', 'none', '');
#INSERT INTO fieldtypes VALUES ( '8', 'time', 'line', '', 'none', '');
#INSERT INTO fieldtypes VALUES ( '9', 'binary', 'none', '', 'none', '');
#INSERT INTO fieldtypes VALUES ('11', 'xref', 'xref', '', 'xref', '');

# Local Variables: ***
# mode:sql ***
# tab-width:2 ***
# End: ***
