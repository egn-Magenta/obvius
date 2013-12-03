delimiter $$

drop procedure if exists __tmp_add_password_reset_request $$
create procedure __tmp_add_password_reset_request()
begin
    declare a integer unsigned;

    SET a = 0;

    SELECT COUNT(*)
    FROM INFORMATION_SCHEMA.TABLES
    WHERE
        table_schema = DATABASE()
        AND
        table_name = 'password_reset_requests'
    INTO a;

    if (a < 1) then
        CREATE TABLE password_reset_requests (
            `id` INT unsigned NOT NULL AUTO_INCREMENT,
            `user_id` smallint(5) unsigned NOT NULL,
            `code` varchar(255) NOT NULL,
            `created` datetime NOT NULL,
            PRIMARY KEY (`id`),
            CONSTRAINT `password_reset_request_user_ref`
            FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
            ON DELETE CASCADE ON UPDATE CASCADE
        ) ENGINE=InnoDB;
    end if;

end $$
call __tmp_add_password_reset_request();
drop procedure if exists __tmp_add_password_reset_request $$

delimiter ;
