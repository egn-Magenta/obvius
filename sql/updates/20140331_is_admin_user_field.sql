delimiter $$

drop procedure if exists __tmp_add_is_admin_field $$
create procedure __tmp_add_is_admin_field()
begin
    declare a integer unsigned;

    SET a = 0;

    SELECT COUNT(*)
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE
        table_schema = database()
        AND
        table_name = 'users'
        AND
        column_name = 'is_admin'
    INTO a;

    if (a < 1) then
        ALTER TABLE users
        ADD COLUMN (is_admin int(1) unsigned default 0);
    end if;
end $$
call __tmp_add_is_admin_field();
drop procedure if exists __tmp_add_is_admin_field $$

delimiter ;
