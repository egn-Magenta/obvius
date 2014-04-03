# Obvius database structure for DBNAME
# $Id$

#include <conf/config.h>

#define HAS_STRUCTURE_SQL

#if "DBTYPE" eq "mysql"

#define COUNTER                      int(8) unsigned NOT NULL auto_increment
#define UNSIGNED                     int(8) unsigned
#define SMALLINT                     smallint(5) unsigned
#define TINYINT(x)                   tinyint(x)
#define INT(x)                       int(x)
#define PACK_KEYS                    PACK_KEYS=1
#define LONGTEXT                     longtext
#define DATETIME                     datetime
#define DOUBLE                       double
#define INDEX_FIELD_LIMIT(field,lim) field(lim)
#define FIELD(x)                     x

#perldef <<CREATE_TABLE(...)
my ( $table, $content) = ( $_[0], join(",\n",@_[1..$#_]));
<<CT
DROP TABLE IF EXISTS $table;
CREATE TABLE $table (
$content
) type=InnoDB
CT
CREATE_TABLE

#elif "DBTYPE" eq "pgsql"

#define COUNTER                      SERIAL 
#define UNSIGNED                     int
#define INT(x)                       int
#define SMALLINT                     smallint 
#define TINYINT(x)                   smallint 
#define PACK_KEYS
#define LONGTEXT                     text
#define DATETIME                     timestamp
#define DOUBLE                       float
#define INDEX_FIELD_LIMIT(field,lim) substr(field,0,lim)
#define FIELD(x)                     "x"

#perldef <<CREATE_TABLE(...)
my ( $table, $content) = ( $_[0], join(",\n", map {
	s/\b(end|user)\b/"$1"/;  # quote certain pgsql keywords
	$_;
} @_[1..$#_]));
<<CT
DROP TABLE $table;
CREATE TABLE $table (
$content
)
CT
CREATE_TABLE

CREATE LANGUAGE 'plpgsql';

#else
#error DBTYPE is invalid or not specified, must be one of: [mysql, pgsql]
#endif

# Obvius database structure for DBNAME

#ifndef CYCLE

CREATE_TABLE( documents,
  id           COUNTER,
  parent       UNSIGNED DEFAULT '0' NOT NULL,
  name         varchar(127) DEFAULT '' NOT NULL,
  type         UNSIGNED NOT NULL,
  owner        SMALLINT DEFAULT '0' NOT NULL,
  grp          SMALLINT DEFAULT '0' NOT NULL,
  accessrules  TEXT DEFAULT '',
  PRIMARY KEY  (id)
);
CREATE UNIQUE INDEX documents_parent_idx ON documents (parent,name);

CREATE_TABLE( docparms,
  docid        UNSIGNED NOT NULL,
  name         varchar(127) DEFAULT '' NOT NULL,
  value        LONGTEXT DEFAULT '',
  type         UNSIGNED NOT NULL      # What is this for?  
# No indexes/primary key?
);

CREATE_TABLE( versions,
  docid        UNSIGNED NOT NULL,
  version      DATETIME DEFAULT '0000-01-01 00:00:00' NOT NULL,
  type         UNSIGNED NOT NULL,
  public       TINYINT(8) DEFAULT '0' NOT NULL,
  valid        TINYINT(8) DEFAULT '0' NOT NULL,
  lang         varchar(2) DEFAULT 'da' NOT NULL,
  user         SMALLINT,              # References users.id  
  PRIMARY KEY  (docid, version)
);
CREATE INDEX versions_type_idx ON versions (type);
CREATE INDEX versions_public_type_idx ON versions (public,type); # Check JUs home-machine

CREATE_TABLE( vfields,
  docid        UNSIGNED NOT NULL,
  version      DATETIME NOT NULL,
  name         varchar(127) DEFAULT '' NOT NULL,
  text_value   LONGTEXT,
  int_value    INT(8),
  double_value DOUBLE,
  date_value   DATETIME
);

CREATE INDEX vfields_docid_version_name_int_value_idx ON vfields (docid,version,name,int_value);
CREATE INDEX vfields_docid_version_name_double_value_idx ON vfields (docid,version,name,double_value);
CREATE INDEX vfields_docid_version_name_date_value_idx ON vfields (docid,version,name,date_value);
CREATE INDEX vfields_docid_version_name_text_value_idx ON vfields (docid,version,name,INDEX_FIELD_LIMIT(text_value,16));

#endif -- CYCLE

CREATE_TABLE( doctypes,
  id           COUNTER,
  name         varchar(127) DEFAULT '' NOT NULL,
  parent       UNSIGNED NOT NULL,
  basis        TINYINT(1) DEFAULT '0' NOT NULL,
  searchable   TINYINT(1) DEFAULT '1' NOT NULL,
  sortorder_field_is varchar(127),
  PRIMARY KEY  (id)
);

CREATE UNIQUE INDEX doctypes_name_idx ON doctypes (name);

CREATE_TABLE( fieldspecs,
  doctypeid    UNSIGNED NOT NULL,
  name         varchar(127) DEFAULT '' NOT NULL,
  type         UNSIGNED NOT NULL,
  repeatable   TINYINT(1) NOT NULL DEFAULT 0,
  optional     TINYINT(1) NOT NULL DEFAULT 0,
  searchable   TINYINT(1) NOT NULL DEFAULT 0,
  sortable     TINYINT(1) NOT NULL DEFAULT 0,
  publish      TINYINT(1) NOT NULL DEFAULT 0,
  threshold    TINYINT(1) UNSIGNED DEFAULT 128 NOT NULL,
  default_value text,
  extra text,
  PRIMARY KEY  (doctypeid, name)
);

CREATE_TABLE( fieldtypes,
  id           COUNTER,
  name         varchar(127) DEFAULT '' NOT NULL,
  edit         varchar(127) DEFAULT 'line' NOT NULL,
  edit_args    text DEFAULT '' NOT NULL,
  validate     varchar(127) DEFAULT 'none' NOT NULL,
  validate_args text DEFAULT '' NOT NULL,
  search       varchar(127) DEFAULT 'none' NOT NULL,
  search_args  text DEFAULT '' NOT NULL,
  bin          TINYINT(1) DEFAULT 0 NOT NULL,
  value_field  varchar(6) DEFAULT 'text' NOT NULL, # enum(text,int,double,date)
  PRIMARY KEY  (id)
);
CREATE UNIQUE INDEX fieldtypes_name ON fieldtypes (name);

CREATE_TABLE( editpages,
  doctypeid    UNSIGNED NOT NULL,
  page         varchar(5) NOT NULL,
  title        varchar(127) DEFAULT '' NOT NULL,
  description  text DEFAULT '' NOT NULL,
  fieldlist    text DEFAULT '' NOT NULL,
  PRIMARY KEY  (doctypeid, page)
);

#ifndef CYCLE

CREATE_TABLE( categories,
  id           varchar(9) DEFAULT '' NOT NULL,
  name         varchar(127) DEFAULT '' NOT NULL,
  PRIMARY KEY  (id)
);

CREATE_TABLE( keywords,
  id           COUNTER,
  name         varchar(63) DEFAULT '' NOT NULL,
  PRIMARY KEY  (id)
);
CREATE UNIQUE INDEX keywords_name_idx ON keywords (name);

CREATE_TABLE( users,
  id           COUNTER,
  login        varchar(31) DEFAULT '' NOT NULL,
  passwd       varchar(63) DEFAULT '' NOT NULL,
  name         varchar(127) DEFAULT '' NOT NULL,
  email        varchar(127) DEFAULT '' NOT NULL,
  notes        text NOT NULL,
  admin        TINYINT(1) DEFAULT '0' NOT NULL,
  can_manage_users   TINYINT(1) DEFAULT '0' NOT NULL,
  can_manage_groups  TINYINT(1) DEFAULT '0' NOT NULL,
  surveillance text,
  PRIMARY KEY  (id)
); 
CREATE UNIQUE INDEX users_login_idx ON users (login);

CREATE_TABLE( groups,
  id           COUNTER,
  name         varchar(31) DEFAULT '' NOT NULL,
  PRIMARY KEY  (id)
);
CREATE UNIQUE INDEX groups_name_idx ON groups (name);

CREATE_TABLE( grp_user,
  grp          SMALLINT DEFAULT '0' NOT NULL,
  user         SMALLINT DEFAULT '0' NOT NULL,
  PRIMARY KEY  (grp, user)
);

CREATE_TABLE( subscribers,
  id           COUNTER,
  name         varchar(127) DEFAULT '' NOT NULL,
  company      varchar(127) DEFAULT '' NOT NULL,
  passwd       varchar(63)  DEFAULT '' NOT NULL,
  email        varchar(63)  DEFAULT '' NOT NULL,
  suspended    TINYINT(3) DEFAULT '0' NOT NULL,
  cookie       varchar(64) NOT NULL default '',
  PRIMARY KEY  (id)
);
CREATE UNIQUE INDEX subscribers_email_idx ON subscribers (email);

CREATE_TABLE( subscriptions,
  docid        UNSIGNED DEFAULT '0' NOT NULL,
  subscriber   INT(10) DEFAULT '0' NOT NULL,
  last_update  DATETIME DEFAULT '0000-01-01 00:00:00' NOT NULL,
  PRIMARY KEY  (docid,subscriber)
);

CREATE_TABLE( config,
  name         varchar(127) NOT NULL,
  value        varchar(127) NOT NULL,
  descriptions text,
  PRIMARY KEY  (name)
);

CREATE_TABLE( voters,
  docid        UNSIGNED NOT NULL default '0',
  cookie       varchar(64) NOT NULL default '',
  PRIMARY KEY  (docid,cookie)
) PACK_KEYS;

CREATE_TABLE( votes,
  docid        UNSIGNED NOT NULL default '0',
  answer       varchar(32) NOT NULL default '',
  total        INT(10) NOT NULL default '0',
  PRIMARY KEY  (docid,answer)
) PACK_KEYS;

CREATE_TABLE( comments,
  docid        UNSIGNED NOT NULL,
  date         DATETIME NOT NULL,
  name         varchar(127) NOT NULL,
  email        varchar(63) NOT NULL,
  show_email   BOOL NOT NULL DEFAULT false,
  text text    NOT NULL,
  PRIMARY KEY  (docid,date)
);
CREATE INDEX comments_date_idx ON comments (date);

CREATE_TABLE( synonyms,
  id           COUNTER,
  synonyms     text NOT NULL,
  PRIMARY KEY  (id)
);

CREATE_TABLE( queue,
  id           COUNTER,
  date         DATETIME NOT NULL,         # When
  docid        UNSIGNED NOT NULL,         # Where,   references documents.id
  user         SMALLINT NOT NULL,         # By whom, references users.id
  command      varchar(127) NOT NULL,     # What
  args         text,
  status       varchar(63),
  message      text,
  PRIMARY KEY  (id)
);
CREATE INDEX queue_date_idx ON queue (date);

CREATE_TABLE( annotations,
  id           COUNTER,
  docid        UNSIGNED NOT NULL,                               # References versions
  version      DATETIME DEFAULT '0000-01-01 00:00:00' NOT NULL, #    -"-       -"-
  date         timestamp NOT NULL,
  user         SMALLINT NOT NULL,                               # References users.id  
  text         text,
  PRIMARY KEY  (id)
);
CREATE INDEX annotations_docid_version_idx ON annotations (docid,version);

CREATE_TABLE( newsboxes,
  docid        UNSIGNED NOT NULL,                         # References documents.id
  type         varchar(22) DEFAULT 'chronological' NOT NULL, # enum('chronological', 'reverse_chronological', 'manual_placement')  
  PRIMARY KEY  (docid)
);

CREATE_TABLE( news,
  newsboxid    UNSIGNED NOT NULL, # References newsboxes.docid
  seq          UNSIGNED NOT NULL, # Notice that higher seq means should be first here!
  docid        UNSIGNED NOT NULL, # References documents.id,
  start        DATETIME NOT NULL,
  end          DATETIME NOT NULL,
  PRIMARY KEY  (newsboxid, seq)
);
CREATE INDEX news_start_idx ON news (start);
CREATE INDEX news_end_idx   ON news (FIELD(end));

CREATE_TABLE ( formdata,
  id 		COUNTER,
  docid		UNSIGNED,
  entry		LONGTEXT,
  PRIMARY KEY (id)
);
CREATE INDEX formdata_docid_idx ON formdata (docid);

# Default data:

#  Users:

#ifndef DOMAIN
#error DOMAIN must be defined
#endif
#define QUOTE(a) #a

#perldef CRYPT($passwd) "'" . crypt($passwd, '$1$safdasdf$') . "'"

INSERT INTO users VALUES ( '1',  'admin', CRYPT(admin),  'Admin', QUOTE(webmaster@DOMAIN), '', '1','2','1', NULL);
INSERT INTO users VALUES ( '2', 'nobody', '', 'Nobody', '', '', '0','0','0', NULL);

# Groups:

INSERT INTO groups VALUES ( '1', 'Admin');
INSERT INTO groups VALUES ( '2', 'No-one');

# grp_user:

INSERT INTO grp_user VALUES ( '1', '1');
INSERT INTO grp_user VALUES ( '2', '2');

#endif -- CYCLE
