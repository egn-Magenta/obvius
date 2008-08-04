-- This series of functions is used for getting all (recursive) subdocuments to a given document.
-- They must always be called in order:
-- call backup_recursive_subdocs();
-- call recursive_subdocs(docid) 
-- and last: call restore_recursive_subdocs.
-- This of course is to ensure that the global table recursive_subdocs_table never gets overwritten
-- by some function called further down in the hierarchy.

delimiter $$

drop procedure if exists backup_recursive_subdocs $$
create procedure backup_recursive_subdocs()
begin 
	declare id integer unsigned default 0;

	create temporary table if not exists 
	       recursive_subdocs_table (id integer unsigned primary key auto_increment) engine=heap;
	create temporary table if not exists 
	       recursive_subdocs_backup_list (id integer unsigned primary key auto_increment) engine=heap;
	create temporary table if not exists
	       recursive_subdocs_backup (backup_id integer unsigned, recursive_id integer unsigned) engine=heap;
	
	insert into recursive_subdocs_backup_list values ();
	set id = last_insert_id();
	
	insert into recursive_subdocs_backup (backup_id, recursive_id) 
	       select id,recursive_subdocs_table.id from recursive_subdocs_table;
	
	delete from recursive_subdocs_table;
end $$


drop procedure if exists recursive_subdocs $$
create procedure recursive_subdocs (docid integer unsigned) 
begin
        declare old_len integer unsigned default 0;
        declare new_len integer unsigned default 1;
	
	create temporary table if not exists recursive_subdocs_table2 
	       (id integer unsigned primary key) engine=heap;
	
	delete from recursive_subdocs_table;
        insert into recursive_subdocs_table set id=docid;
	
        subdocs:while old_len != new_len do
                      set old_len = new_len;
		      delete r2 from recursive_subdocs_table2 r2;
		      insert ignore into recursive_subdocs_table2 (id)
		      	     select id from recursive_subdocs_table;
                      insert ignore into recursive_subdocs_table (id) select                 
                             d.id from recursive_subdocs_table2 r2 join 
                             documents d on (r2.id = d.parent); 
                       select count(*) into new_len from recursive_subdocs_table;
         end while;
end $$

drop procedure if exists restore_recursive_subdocs $$
create procedure restore_recursive_subdocs() 
begin
	declare id integer unsigned;

	delete from recursive_subdocs_table;

	select max(id) into id from recursive_subdocs_backup_list rl;
	insert into recursive_subdocs_table
	       select recursive_id from recursive_subdocs_backup rsb where rsb.backup_id = id;
	
	delete rl from recursive_subdocs_backup_list rl where rl.id = id;
	delete rsb from recursive_subdocs_backup rsb where rsb.backup_id = id;
end $$

delimiter ;
