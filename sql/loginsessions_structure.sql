DROP TABLE IF EXISTS login_sessions;
DROP TABLE IF EXISTS login_secrets;

CREATE TABLE login_secrets (
  login varchar(31) NOT NULL,
  secret varchar(32) NOT NULL,
  time int unsigned NOT NULL,
  index (login, secret)
) engine = InnoDB;
     
CREATE TABLE login_sessions (
  login varchar(31)  NOT NULL,
  session_id char(32)  NOT NULL,
  last_access int(12)  NOT NULL,
  permanent boolean not null,
  PRIMARY KEY (session_id),
  index (login)
) engine = InnoDB;

