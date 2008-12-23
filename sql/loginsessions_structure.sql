DROP TABLE IF EXISTS login_sessions;

CREATE TABLE login_secrets (
  login varchar(31) NOT NULL,
  secret varchar(32) NOT NULL,
  time int unsigned NOT NULL,
  index (login)
) type = InnoDB;
     
CREATE TABLE login_sessions (
  login varchar(31)  NOT NULL,
  session_id char(32)  NOT NULL,
  last_access int(12)  NOT NULL,
  PRIMARY KEY (session_id),
  index (login)
) type=InnoDB;

