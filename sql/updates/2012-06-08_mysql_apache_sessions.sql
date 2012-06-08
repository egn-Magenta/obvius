delimiter $$

drop procedure if exists __tmp_add_mysql_apache_sessions $$
create procedure __tmp_add_mysql_apache_sessions()
begin
    declare a integer unsigned;

    SET a = 0;

    SELECT COUNT(*)
    FROM INFORMATION_SCHEMA.TABLES
    WHERE
        table_schema = DATABASE()
        AND
        table_name = 'apache_user_sessions'
    INTO a;

    if (a < 1) then
        CREATE TABLE apache_user_sessions (
            id CHAR(32) NOT NULL PRIMARY KEY,
            a_session BLOB,
            `timestamp` TIMESTAMP
        ) ENGINE=InnoDB;
    end if;

    SELECT COUNT(*)
    FROM INFORMATION_SCHEMA.TABLES
    WHERE
        table_schema = DATABASE()
        AND
        table_name = 'apache_edit_sessions'
    INTO a;

    if (a < 1) then
        CREATE TABLE apache_edit_sessions (
            id CHAR(32) NOT NULL PRIMARY KEY,
            a_session BLOB,
            `timestamp` TIMESTAMP
        ) ENGINE=InnoDB;
    end if;

end $$
call __tmp_add_mysql_apache_sessions();
drop procedure if exists __tmp_add_mysql_apache_sessions $$

delimiter ;
