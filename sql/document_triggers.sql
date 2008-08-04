delimiter $$

drop trigger post_document_delete $$
create trigger post_document_delete after delete on documents
for each row
begin
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

drop trigger post_document_insert $$
create trigger post_document_insert after insert on documents
for each row call insert_docid_path(new.id) $$


drop procedure if exists update_move_internal $$
create procedure update_move_internal() 
begin
        declare path varchar(1024);
        declare a int unsigned default 0;
        declare done int default 0;
        declare curs cursor for (select * from recursive_subdocs_table);
        declare continue handler for not found set done=1;


        open curs;
        fetch curs into a;

        while not done do
              call find_path_by_docid(a, path);
              replace into docid_path (docid, path) values (a, path);
              fetch curs into a;
        end while;
        
        close curs;
end $$

drop procedure if exists update_move $$
create procedure update_move (docid integer unsigned) 
begin
	call backup_recursive_subdocs();
        call recursive_subdocs(docid);

 	call update_move_internal();
 	call restore_recursive_subdocs();
	drop temporary table recursive_subdocs_table;
end $$      

drop   trigger post_document_update $$
create trigger post_document_update after update on documents
for each row begin
    if (new.parent != old.parent) or (new.name != old.name) then
       call update_move(new.id);
    end if;
end $$

delimiter ;
