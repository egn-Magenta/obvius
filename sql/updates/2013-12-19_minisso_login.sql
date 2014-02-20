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

CREATE TABLE IF NOT EXISTS `sso_tickets` (
  `sso_ticket_id` INT UNSIGNED NOT NULL AUTO_INCREMENT ,
  `sso_session_id` INT UNSIGNED NULL ,
  `ticketcode` CHAR(32) NOT NULL ,
  `origin` TEXT NOT NULL ,
  `expires` DATETIME NOT NULL ,
  PRIMARY KEY (`sso_ticket_id`) ,
  KEY `sso_tickets_sso_session_ref` (`sso_session_id`),
  CONSTRAINT `sso_tickets_sso_session_ref` FOREIGN KEY (`sso_session_id`)
    REFERENCES `sso_sessions` (`sso_session_id`)
    ON DELETE CASCADE ON UPDATE CASCADE,
  INDEX `sso_tickets_code_idx` (`ticketcode` ASC)
) ENGINE = InnoDB;

ALTER TABLE `login_sessions`
    ADD COLUMN `ip_match` VARCHAR(11) NOT NULL,
    ADD COLUMN `sso_session_id` INT UNSIGNED NULL,
    ADD CONSTRAINT `login_sessions_sso_ref` FOREIGN KEY (`sso_session_id`)
        REFERENCES `sso_sessions` (`sso_session_id`)
        ON DELETE SET NULL ON UPDATE CASCADE
;
