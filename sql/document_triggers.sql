delimiter $$

-- @user must be set ahead of deleting the document to place it in the right bin.
-- Otherwise default to admin being the deleter.
drop trigger if exists post_document_delete $$
create trigger post_document_delete after delete on documents
for each row
begin
        declare p text default NULL;
        select path from docid_path where docid=old.id into p;  
        insert into documents_backup (id, parent, name, type, owner,grp, accessrules, 
                                      path,date_deleted, delete_user) values 
                                   (old.id, old.parent, old.name, old.type, old.owner, 
                                    old.grp, old.accessrules, p, now(), ifnull(@user, 1));
	delete d from docid_path d where d.docid = old.id;
	call clean_internal_proxies(old.id);
end $$

drop procedure if exists insert_docid_path $$
create procedure insert_docid_path (did integer unsigned)
begin
        declare path varchar(1024);
        call find_path_by_docid(did, path);
        delete docid_path from docid_path where docid=did;
        insert into docid_path (docid, path) values (did, path);
end $$

drop trigger if exists post_document_insert $$
create trigger post_document_insert after insert on documents
for each row call insert_docid_path(new.id) $$

drop procedure if exists recursive_subdocs_trigger $$
create procedure recursive_subdocs_trigger (docid integer unsigned) 
begin
        declare old_len integer unsigned default 0;
        declare new_len integer unsigned default 1;
	
	create temporary table if not exists recursive_subdocs_table2 
	       (id integer unsigned primary key) engine=heap;
	
	delete from recursive_subdocs_trigger_table;
        insert into recursive_subdocs_trigger_table set id=docid;
	
        subdocs:while old_len != new_len do
                      set old_len = new_len;
		      delete r2 from recursive_subdocs_table2 r2;
		      insert ignore into recursive_subdocs_table2 (id)
		      	     select id from recursive_subdocs_trigger_table;
                      insert ignore into recursive_subdocs_trigger_table (id) select
                             d.id from recursive_subdocs_table2 r2 join 
                             documents d on (r2.id = d.parent); 
                      select count(*) into new_len from recursive_subdocs_trigger_table;
         end while;
	 drop temporary table recursive_subdocs_table2;
end $$

drop procedure if exists update_move_internal $$
create procedure update_move_internal() 
begin
        declare path varchar(1024);
        declare a int unsigned default 0;
        declare done int default 0;
        declare curs cursor for (select * from recursive_subdocs_trigger_table);
        declare continue handler for not found set done=1;

        open curs;
        fetch curs into a;

        while not done do
              call find_path_by_docid(a, path);
	      delete docid_path from docid_path where docid=a;
              replace into docid_path (docid, path) values (a, path);
              fetch curs into a;
        end while;
        
        close curs;
end $$

drop procedure if exists update_move $$
create procedure update_move (docid integer unsigned) 
begin
	create temporary table recursive_subdocs_trigger_table (id integer unsigned primary key);
        call recursive_subdocs_trigger(docid);

 	call update_move_internal();
	drop temporary table recursive_subdocs_trigger_table;
end $$      

drop trigger if exists post_document_update $$
create trigger post_document_update after update on documents
for each row begin
    if (new.parent != old.parent) or (new.name != old.name) then
       call update_move(new.id);
    end if;
end $$

drop trigger if exists post_vfield_insert $$
create trigger post_vfield_insert after insert on vfields 
for each row begin
    if new.name = 'tags' then
       insert ignore into all_tags values (new.text_value);
    end if;
end $$

delimiter ;
