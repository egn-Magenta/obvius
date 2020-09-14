delimiter $$

drop procedure if exists __tmp_database_change $$
create procedure __tmp_database_change()
begin
    declare a integer unsigned;

    SET a = 0;

    SELECT COUNT(*)
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE
        table_schema = database()
        AND
        table_name = 'fieldspecs'
        AND
        column_name = 'encrypt'
    INTO a;

    if (a > 0) then
        ALTER TABLE fieldspecs DROP COLUMN `encrypt`;
    end if;
end $$
call __tmp_database_change();
drop procedure if exists __tmp_database_change $$

delimiter ;
