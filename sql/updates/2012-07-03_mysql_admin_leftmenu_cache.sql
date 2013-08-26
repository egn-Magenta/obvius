delimiter $$

drop procedure if exists __tmp_add_mysql_admin_leftmenu_cache $$
create procedure __tmp_add_mysql_admin_leftmenu_cache()
begin
    declare a integer unsigned;

    SET a = 0;

    SELECT COUNT(*)
    FROM INFORMATION_SCHEMA.TABLES
    WHERE
        table_schema = DATABASE()
        AND
        table_name = 'admin_leftmenu_cache'
    INTO a;

    if (a < 1) then
        CREATE TABLE admin_leftmenu_cache (
            id varchar(255) NOT NULL PRIMARY KEY,
            cache_data BLOB,
            `timestamp` TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8;
    end if;

end $$
call __tmp_add_mysql_admin_leftmenu_cache();
drop procedure if exists __tmp_add_mysql_admin_leftmenu_cache $$

delimiter ;
