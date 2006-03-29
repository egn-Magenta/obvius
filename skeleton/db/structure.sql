# Obvius database structure for ${dbname}

DROP TABLE IF EXISTS documents;
CREATE TABLE documents (
  id int(8) unsigned NOT NULL auto_increment,
  parent int(8) unsigned DEFAULT '0' NOT NULL,
  name char(127) DEFAULT '' NOT NULL,
  type int(8) unsigned NOT NULL,
  owner smallint(5) unsigned DEFAULT '0' NOT NULL,
  grp smallint(5) unsigned DEFAULT '0' NOT NULL,
  accessrules text DEFAULT "",
  PRIMARY KEY (id),
  UNIQUE parent (parent,name),
	INDEX (parent)
) type=MyISAM;

DROP TABLE IF EXISTS docparms;
CREATE TABLE docparms (
  docid int(8) unsigned NOT NULL,
  name varchar(127) DEFAULT '' NOT NULL,
  value longtext DEFAULT '',
  type int(8) unsigned NOT NULL # What is this for?
  # No indexes/primary key?
) type=MyISAM;

DROP TABLE IF EXISTS versions;
CREATE TABLE versions (
  docid int(8) unsigned NOT NULL,
  version datetime DEFAULT '0000-00-00 00:00:00' NOT NULL,
	type int(8) unsigned NOT NULL,
  public tinyint(8) DEFAULT '0' NOT NULL,
  valid tinyint(8) DEFAULT '0' NOT NULL,
  lang char(2) DEFAULT 'da' NOT NULL,
  user smallint(5) unsigned, # References users.id
  PRIMARY KEY (docid, version),
  INDEX (type),
  INDEX (public, type) # Check JUs home-machine
) type=MyISAM;

DROP TABLE IF EXISTS vfields;
CREATE TABLE vfields (
  docid int(8) unsigned NOT NULL,
  version datetime NOT NULL,
  name varchar(127) DEFAULT '' NOT NULL,
  text_value longtext,
  int_value int(8),
  double_value double,
	date_value datetime,
  KEY (docid, version, name),
	INDEX (name, text_value(16)),
	INDEX (name, int_value),
	INDEX (name, double_value),
	INDEX (name, date_value)
) type=MyISAM;

### CYCLE
DROP TABLE IF EXISTS doctypes;
CREATE TABLE doctypes (
  id int(8) unsigned NOT NULL auto_increment,
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
  id int(8) unsigned NOT NULL auto_increment,
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
### CYCLE

DROP TABLE IF EXISTS categories;
CREATE TABLE categories (
  id char(9) DEFAULT '' NOT NULL,
  name char(127) DEFAULT '' NOT NULL,
  PRIMARY KEY (id)
) type=MyISAM;

DROP TABLE IF EXISTS keywords;
CREATE TABLE keywords (
  id smallint(5) unsigned NOT NULL auto_increment,
  name char(63) DEFAULT '' NOT NULL,
  PRIMARY KEY (id),
  UNIQUE keyword (name)
) type=MyISAM;

DROP TABLE IF EXISTS users;
CREATE TABLE users (
  id smallint(5) unsigned NOT NULL auto_increment,
  login varchar(31) DEFAULT '' NOT NULL,
  passwd varchar(63) DEFAULT '' NOT NULL,
  name varchar(127) DEFAULT '' NOT NULL,
  email varchar(127) DEFAULT '' NOT NULL,
  notes text NOT NULL,
  PRIMARY KEY (id),
  UNIQUE login (login)
) type=MyISAM;

DROP TABLE IF EXISTS groups;
CREATE TABLE groups (
  id smallint(5) unsigned NOT NULL auto_increment,
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
  id int(10) unsigned NOT NULL auto_increment,
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

DROP TABLE IF EXISTS comments;
CREATE TABLE comments (
	docid int(8) unsigned NOT NULL,
	date datetime NOT NULL,
	name varchar(127) NOT NULL,
	email varchar(63) NOT NULL,
  show_email BOOL NOT NULL DEFAULT 0,
	text text NOT NULL,
	PRIMARY KEY (docid,date),
	INDEX (date)
) TYPE=MyISAM;

DROP TABLE IF EXISTS synonyms;
CREATE TABLE synonyms (
  id int(8) unsigned NOT NULL auto_increment,
	synonyms text NOT NULL,
  PRIMARY KEY (id)
) TYPE=MyISAM PACK_KEYS=1;

DROP TABLE IF EXISTS queue;
CREATE TABLE queue (
  id int(8) unsigned NOT NULL auto_increment,
  date datetime NOT NULL,               # When
  docid int(8) unsigned NOT NULL,       # Where,   references documents.id
  user smallint(5) unsigned NOT NULL,   # By whom, references users.id
  command varchar(127) NOT NULL,        # What
  args text,
  status varchar(63),
  message text,
  PRIMARY KEY (id),
  INDEX (date)
) TYPE=MyISAM;

DROP TABLE IF EXISTS annotations;
CREATE TABLE annotations (
  id int(8) unsigned NOT NULL auto_increment,
  docid int(8) unsigned NOT NULL,                          # References versions
  version datetime DEFAULT '0000-00-00 00:00:00' NOT NULL, #    -"-       -"-
  date timestamp NOT NULL,
  user smallint(5) unsigned NOT NULL, # References users.id
  text text,
  PRIMARY KEY (id),
  INDEX (docid, version)
) TYPE=MyISAM;

DROP TABLE IF EXISTS newsboxes;
CREATE TABLE newsboxes (
  docid int(8) unsigned NOT NULL, # References documents.id
	type enum('chronological', 'reverse_chronological', 'manual_placement') DEFAULT 'chronological' NOT NULL,
  PRIMARY KEY (docid)
) TYPE=MyISAM;

DROP TABLE IF EXISTS news;
CREATE TABLE news (
  newsboxid int(8) unsigned NOT NULL, # References newsboxes.docid
  seq int(8) unsigned NOT NULL,       # Notice that higher seq means should be first here!
  docid int(8) unsigned NOT NULL,     # References documents.id,
  start datetime NOT NULL,
  end datetime NOT NULL,
  PRIMARY KEY (newsboxid, seq),
  INDEX (start),
  INDEX (end)
) TYPE=MyISAM;


# Default data:

#  Users:

INSERT INTO users VALUES ( '1',  'admin', '$1$safdasdf$hjqFW5Yb3JysogKILEjBd.', 'Admin', 'webmaster@${domain}', '');
INSERT INTO users VALUES ( '2', 'nobody', '$1$safdasdf$1nrCPtQuzQdXcU74o11Tk/', 'Nobody', 'nobody@${domain}', '');

# Groups:

INSERT INTO groups VALUES ( '1', 'Admin');
INSERT INTO groups VALUES ( '2', 'No-one');

# grp_user:

INSERT INTO grp_user VALUES ( '1', '1');
INSERT INTO grp_user VALUES ( '2', '2');

# Local Variables: ***
# mode:sql ***
# tab-width:2 ***
# End: ***
