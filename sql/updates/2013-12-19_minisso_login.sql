CREATE TABLE IF NOT EXISTS `sso_tickets` (
  `sso_ticket_id` INT UNSIGNED NOT NULL AUTO_INCREMENT ,
  `ticketcode` CHAR(32) NOT NULL ,
  `login` VARCHAR(255) NOT NULL ,
  `origin` TEXT NOT NULL ,
  `ip_match` VARCHAR(11) NOT NULL ,
  `permanent_request` TINYINT(1) NOT NULL DEFAULT 0 ,
  `expires` DATETIME NOT NULL ,
  PRIMARY KEY (`sso_ticket_id`) ,
  INDEX `sso_tickets_code_idx` (`ticketcode` ASC)
) ENGINE = InnoDB;

CREATE TABLE IF NOT EXISTS `sso_sessions` (
  `sso_session_id` INT UNSIGNED NOT NULL AUTO_INCREMENT ,
  `session_id` CHAR(32) NOT NULL ,
  `login` VARCHAR(255) NOT NULL ,
  `ip_match` VARCHAR(11) NOT NULL ,
  `permanent` TINYINT(1) NOT NULL DEFAULT 0 ,
  `expires` DATETIME NOT NULL ,
  PRIMARY KEY (`sso_session_id`) ,
  INDEX `sso_sessions_sessionid_idx` (`session_id` ASC)
) ENGINE = InnoDB;

ALTER TABLE `login_sessions` ADD COLUMN `ip_match` VARCHAR(11) NOT NULL;
