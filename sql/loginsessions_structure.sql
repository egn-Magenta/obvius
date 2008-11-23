DROP TABLE IF EXISTS login_sessions;
CREATE TABLE login_sessions (
  id smallint(5) unsigned NOT NULL auto_increment,
  login varchar(31) DEFAULT '' NOT NULL,
  session_id char(32) DEFAULT '' NOT NULL,
  last_access int(12) unsigned DEFAULT 0 NOT NULL,
  secret char(32) DEFAULT '' NOT NULL,
  validated int(1) unsigned DEFAULT 0 NOT NULL,
  PRIMARY KEY (id),
  UNIQUE session_id (session_id)
) type=InnoDB;

