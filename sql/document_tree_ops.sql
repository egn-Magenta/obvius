delimiter $$

drop procedure if exists move_document $$
create procedure move_document (docid integer unsigned, new_parent integer unsigned, new_name varchar(1024))
begin
        update documents set parent=new_parent,name=coalesce(new_name,name)  where id=docid;
end $$

drop procedure if exists copy_id $$
create procedure copy_id(did integer unsigned, 
                         new_parent integer unsigned, 
                         new_name varchar(1024), 
                         out new_docid integer unsigned)
begin
        insert into documents (parent, name, type, owner, grp, accessrules) 
	        select coalesce(new_parent, d.parent), coalesce(new_name, d.name), d.type, d.owner, d.grp, d.accessrules 
        	from documents d where d.id=did;
	set new_docid = last_insert_id();
		     
        insert into versions (docid, version,type,public,valid,lang, user)
        select new_docid, version, type, public,valid,lang, user from versions where docid=did;
        
        insert into vfields (docid, version,name,text_value,int_value, double_value,date_value)
        select new_docid,version,name,text_value,int_value,double_value,date_value from vfields where docid=did; 
end $$

drop procedure if exists copy_tree $$
create procedure copy_tree(docid integer unsigned, new_parent integer unsigned, new_name varchar(1024))
begin 
      declare done integer default 0;
      declare new_did integer unsigned;
      
      create temporary table if not exists tree_copier_helper (old_docid integer unsigned, new_docid integer unsigned, index (old_docid), index (new_docid)) engine=heap;
      delete t from tree_copier_helper t;
      call backup_recursive_subdocs();
      call recursive_subdocs(docid);
      
      call copy_id(docid, new_parent, new_name, new_did);
      insert into tree_copier_helper (old_docid, new_docid) values (docid, new_did);
      
      while not done do call copy_batch(done); end while;
      call restore_recursive_subdocs();
end $$

drop procedure if exists copy_batch $$
create procedure copy_batch(out finally integer)
begin 
      declare done integer default 0;
      declare cur_id integer unsigned;
      declare cur_parent integer unsigned;
      declare new_docid integer unsigned;

      declare curs cursor for 
              (select r.id, t.new_docid from 
                      documents d join recursive_subdocs_table r on (r.id = d.id)
                      join tree_copier_helper t on (d.parent = t.old_docid) 
                      where not exists (select * from batch_copier_helper b where b.id = r.id));
     declare continue handler for not found set done=1;

     create temporary table if not exists batch_copier_helper (id integer unsigned primary key) engine=heap;
     delete b from batch_copier_helper b;
     insert into batch_copier_helper (id) select old_docid from tree_copier_helper t;

     select not count(*) into finally from 
             recursive_subdocs_table r left join tree_copier_helper t on (t.old_docid = r.id) 
             where t.old_docid is null;

     if not finally then
         open curs;
         fetch curs into cur_id, cur_parent;

         while not done do
               call copy_id(cur_id, cur_parent, NULL, new_docid);
               insert into tree_copier_helper (old_docid, new_docid) values (cur_id, new_docid);
               fetch curs into cur_id, cur_parent;
         end while;

         close curs;
       end if;  
end $$

drop procedure if exists delete_document $$
create procedure delete_document(did integer unsigned)
begin
	delete d from documents d where id=did;
	delete vf from vfields vf where docid=did;
	delete ver from versions ver where docid=did;
end $$

drop procedure if exists really_delete_tree $$
create procedure really_delete_tree()
begin 
	declare done integer default 0;
	declare a integer unsigned;
     	declare c cursor for (select * from recursive_subdocs_table r);
        declare continue handler for not found set done=1;
		
	open c;
	fetch c into a;
	while not done do call delete_document(a); fetch c into a; end while;
	delete r from recursive_subdocs_table r;

	close c;
end $$

drop procedure if exists delete_tree $$
create procedure delete_tree(docid integer unsigned)
begin
       call backup_recursive_subdocs();
       call recursive_subdocs(docid);
       call really_delete_tree();

       call restore_recursive_subdocs();
end $$

drop procedure if exists copy_docparams $$
create procedure copy_docparams (fromid integer unsigned, toid integer unsigned)
begin
	replace into docparms (docid, name, value, type) select toid, name, value, type from docparms where docid=fromid;
end $$

delimiter ;
