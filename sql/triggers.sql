delimiter $$

create table if not exists docid_path (
       id integer unsigned primary key auto_increment, 
       path varchar(1024), 
       docid integer unsigned,
       index (path),
       index (docid)) engine=innodb $$

drop procedure if exists find_doc_by_path $$
create procedure find_doc_by_path (path varchar(1024), out docid integer unsigned)
begin
     declare len integer unsigned;
     declare pos integer unsigned default 1;
     declare tid integer unsigned;
     declare cid integer unsigned default 1;
     declare pp varchar(255);

     if not path regexp "/$" then
     	set path = concat(path, "/");
     end if;

     if trim(path) = '/' then
     	set docid = 1;
     else         
     	set len = length(path) - length(replace(path, '/', ''));
     	scanner:while pos < len do 
           set pp = substring_index(substring_index(path, '/', pos + 1), '/', -1);
           set pos = pos + 1;
           if pp = '' then iterate scanner; end if;
           set tid = 0;
	   
           select d.id into tid from documents d
                  where d.name = pp AND d.parent = cid;
           if tid = 0 then leave scanner; end if;
	   set cid = tid;
     end while ;
     set docid = tid;
   end if;
end $$

drop procedure if exists find_path_by_docid $$

create procedure find_path_by_docid (docid integer, out outpath varchar(1024))
begin 
      declare res text default '';
      declare docid2 integer unsigned;
      while docid != 1 do
            set docid2 = null;
            select concat(d.name,'/', res), d.parent into res, docid2 from documents d where d.id = docid;
            set docid = docid2;
      end while;
      
      select case when docid = 1 then concat('/', res) end path into outpath;
end $$

drop procedure if exists recursive_subdocs $$
create procedure recursive_subdocs (docid integer unsigned) 
begin
        declare old_len integer unsigned default 0;
        declare new_len integer unsigned default 1;
	
	create temporary table if not exists recursive_subdocs_table2 
	       (id integer unsigned primary key) engine=innodb;
	create temporary table if not exists recursive_subdocs_table 
	       (id integer unsigned primary key) engine=innodb;
	
	delete r from recursive_subdocs_table r;
        insert into recursive_subdocs_table set id=docid;
	
        subdocs:while old_len != new_len do
                      set old_len = new_len;
		      delete r2 from recursive_subdocs_table2 r2;
		      insert into recursive_subdocs_table2 (id)
		      	     select id from recursive_subdocs_table r;
                      insert ignore into recursive_subdocs_table (id) select                 
                             d.id from recursive_subdocs_table2 r2 join 
                             documents d on (r2.id = d.parent); 
                       select count(*) into new_len from recursive_subdocs_table r;
         end while;
end $$


-- Beware. we are in a trigger. Therefore backup recursive_subdocs_table.

drop procedure if exists update_move $$
create procedure update_move (docid integer unsigned) 
begin
        declare path varchar(1024);
        declare a int unsigned default 0;
        declare done int default 0;
        declare curs cursor for (select * from recursive_subdocs_table);
        declare continue handler for not found set done=1;

	create temporary table if not exists recursive_subdocs_table;
	create temporary table if not exists recursive_subdocs_backup (id integer unsigned) engine=innodb; 
	delete b from recursive_subdocs_backup b; -- This function must not call itself.
	insert into recursive_subdocs_backup select * from recursive_subdocs_table;
        call recursive_subdocs(docid);
	
        open curs;
        fetch curs into a;

        while not done do
              call find_path_by_docid(a, path);
              delete docid_path from docid_path where docid = a;
              insert into docid_path (docid, path) values (a, path);
              fetch curs into a;
        end while;
        
        close curs;
        delete r from recursive_subdocs_table r;
	insert into recursive_subdocs_table select * from recursive_subdocs_backup;
	delete b from recursive_subdocs_backup b;
end $$      

drop procedure if exists document_update $$

create procedure document_update()
begin
     declare done integer default 0;
     declare a integer unsigned;
     declare c cursor for (select * from moved_documents);
     declare continue handler for not found set done=1;
     start transaction;

     open c;
     fetch c into a;
     while not done do
           call update_move(a);
           fetch c into a;
     end while;
     close c;

     delete moved_documents from moved_documents;
     commit;
end $$



drop   trigger post_document_update $$
create trigger post_document_update after update on documents
for each row begin
    if (new.parent != old.parent) or (new.name != old.name) then
       call update_move(new.id);
    end if;
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
        select (max(id)+1) into new_docid from documents;
        insert into documents (id, parent, name, type, owner, grp, accessrules) 
        select new_docid, coalesce(new_parent, d.parent), coalesce(new_name, d.name), d.type, d.owner, d.grp, d.accessrules 
        from documents d where d.id=did;

        insert into versions (docid, version,type,public,valid,lang, user)
        select new_docid, version, type, public,valid,lang, user from versions where docid=did;
        
        insert into vfields (docid, version,name,text_value,int_value, double_value,date_value)
        select new_docid,version,name,text_value,int_value,double_value,date_value from vfields where docid=did; 
end $$

drop procedure if exists copy_tree $$
create procedure copy_tree(docid integer unsigned, new_parent integer unsigned)
begin 
      declare done integer default 0;
      declare new_did integer unsigned;

      
      create temporary table if not exists tree_copier_helper (old_docid integer unsigned, new_docid integer unsigned, index (old_docid), index (new_docid)) engine= innodb;
      delete t from tree_copier_helper t;
      call recursive_subdocs(docid);
      
      call copy_id(docid, new_parent, NULL, new_did);
      insert into tree_copier_helper (old_docid, new_docid) values (docid, new_did);
      
      while not done do call copy_batch(done); end while;
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

     create temporary table if not exists batch_copier_helper (id integer unsigned primary key) engine=innodb;
     delete b from batch_copier_helper b;
     insert into batch_copier_helper (id) select old_docid from tree_copier_helper t;

     select not count(*) into finally from 
             recursive_subdocs_table r left join tree_copier_helper t on (t.old_docid = r.id) 
             where t.old_docid is null;

      if (not finally) then
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

drop trigger post_document_delete $$

create trigger post_document_delete after delete on documents
for each row
begin
	delete d from docid_path d where d.docid = old.id;
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
     	declare c cursor for (select * from recursive_subdocs_table);
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
       call recursive_subdocs(docid);
       call really_delete_tree();
end $$

drop procedure if exists delete_tree_path;
create procedure delete_tree_path(path varchar(1024))
begin
	declare docid integer unsigned;
	call find_doc_by_path(path, docid);
	if docid != 0 then
		call delete_tree(docid);
	end if;
end $$

drop procedure if exists write_subdocs_path_table;
create procedure write_subdocs_path_table()
begin
	declare path varchar(1024);
	declare done integer default 0;
	declare a integer unsigned;
     	declare c cursor for (select * from recursive_subdocs_table);
        declare continue handler for not found set done=1;
	
	delete r from recursive_subdocs_table r;
	delete dp from docid_path dp;
	call recursive_subdocs(1);
	
	open c;
	fetch c into a;

	while not done do 
	      call find_path_by_docid(a, path);
	      insert into docid_path (docid, path) values (a, path);
	      fetch c into a; 
	end while;
	
	close c;
	delete r from recursive_subdocs_table r;
end $$

drop procedure if exists publish_version;
create procedure publish_version(docid integer unsigned, version datetime, lang varchar(100))
begin
	update versions v set public = 0 where (lang is null or (v.lang = lang));
	update versions v set public = 1 where (v.docid = docid and v.version = version);
end $$

drop procedure if exists unpublish_doc;
create procedure unpublish_doc(docid integer unsigned, lang varchar(100))
begin
	update versions v set public = 0 where v.docid = docid and (lang is null or (v.lang = lang));
end $$

drop trigger post_user_delete $$
create trigger post_user_delete after delete on users
for each row
begin
	update documents set owner = 1 where owner = old.id;
	update versions set user = 1 where user = old.id;
	delete from grp_user where user=old.id;
end $$

drop trigger post_groups_delete $$
create trigger post_groups_delete after delete on groups
for each row
begin
	update documents set grp=1 where grp=old.id;
	delete g from grp_user g where g.grp=old.id; 
end $$

drop procedure if exists do_search $$
create procedure do_search(in_path varchar(1024), 
       		 	   in_pattern varchar(1024), 
			   owner integer unsigned, 
			   grp integer unsigned, 
			   newer_than datetime, 
			   older_than datetime
			   )
begin
	declare pattern varchar(1024);
	declare path varchar(1026);

	set path = concat(in_path, "%");
	set pattern = concat('%', replace(in_pattern, '*', '%'), '%');

	select distinct(d.id) from
	       documents d join docid_path dp on (d.id = dp.docid and dp.path like path)
	       left join versions v on (d.id = v.docid)
	       left join vfields vf1 on 
	       	    (v.docid = vf1.docid and vf1.version = v.version and 
		    vf1.name in ('content', 'title', 'short_title'))
	where    
         	(pattern is null or vf1.text_value like pattern or d.name like pattern) and
		(owner is null or d.owner = owner) and
		(grp is null or d.grp = grp) and
		(older_than is null or v.version < older_than) and
		(newer_than is null or v.version > newer_than) limit 50;
end $$				     

drop procedure if exists public_or_latest_version;
create procedure public_or_latest_version (docid integer unsigned, out version datetime) 
begin
	select v.version into version from versions v 
	       where v.docid = docid  and 
	       	     (v.public =1 or 
		     (not exists 
		     	  (select * from versions v2 where 
			  	  v2.docid = docid and 
				  v2.public = 1) 
		      and version = (select max(version) 
		      	  from versions v3 where v3.docid = docid))) limit 1;
end $$

create table if not exists internal_proxy_documents
       (id integer unsigned auto_increment primary key, 
        docid integer unsigned, 
	dependent_on integer unsigned, 
	unique (docid),
	index (docid), 
	index (dependent_on)
       ) engine=Innodb $$


drop procedure if exists order_internal_proxy $$
create procedure order_internal_proxy ()
begin
	declare new_len integer unsigned;
	declare old_len integer unsigned default 0;

	create temporary table if not exists dependency_list_helper
	       (id integer unsigned primary key auto_increment, 
	        internal_proxy_id integer unsigned, 
		unique (internal_proxy_id),
		index (internal_proxy_id));
	create temporary table if not exists dependency_list_helper2
	       (id integer unsigned primary key auto_increment, 
	        internal_proxy_id integer unsigned, 
		unique (internal_proxy_id),
		index (internal_proxy_id));

	create temporary table if not exists new_dependency_list
	       (id integer unsigned auto_increment primary key, 
	        docid integer unsigned, 
		dependent_on integer unsigned,
		index (docid), 
		index (dependent_on)) engine=Innodb;
	
	delete d2 from dependency_list_helper d2;
	delete d from dependency_list_helper d;
	delete n from new_dependency_list n;
	
	insert into dependency_list_helper (internal_proxy_id) 
	       select id from internal_proxy_documents i2 where
	       	      not exists (select * from internal_proxy_documents i where i.docid = i2.dependent_on);

	select count(*) into new_len from dependency_list_helper;
	while old_len != new_len do
	      set old_len = new_len;
	      insert ignore into dependency_list_helper2 select * from dependency_list_helper;
	      insert ignore into dependency_list_helper (internal_proxy_id) select 
	      	     i2.id from dependency_list_helper2 d2 
		     join internal_proxy_documents i1 on (d2.internal_proxy_id = i1.id)
		     join internal_proxy_documents i2 on (i1.docid = i2.dependent_on);
	      select count(*) into new_len from dependency_list_helper;
	end while;

	insert into new_dependency_list select d.id, i.docid, i.dependent_on from
	       dependency_list_helper d join internal_proxy_documents i on (i.id = d.internal_proxy_id);
	delete i from internal_proxy_documents i;
	insert into internal_proxy_documents select * from new_dependency_list n;

	delete d2 from dependency_list_helper d2;
	delete d from dependency_list_helper d;
	delete n from new_dependency_list n;
end $$

drop procedure if exists check_internal_proxy_status $$
create procedure check_internal_proxy_status(out good integer unsigned)
begin
	declare times integer unsigned default 10;
	create temporary table if not exists internal_proxy_status_table (docid integer unsigned primary key) engine = innodb;
	create temporary table if not exists internal_proxy_status_table2 (docid integer unsigned primary key) engine = innodb;

	delete ip from internal_proxy_status_table ip;
	delete ip2 from internal_proxy_status_table ip2;

	insert ignore into internal_proxy_status_table (docid) 
	       select docid from internal_proxy_documents i2;
	
	while times > 0 do
	      set times = times - 1;
	      delete ip2 from internal_proxy_status_table2 ip2;
	      insert ignore into internal_proxy_status_table2 
	      	     select i.docid from internal_proxy_documents i 
		     join internal_proxy_status_table ip on
		     (i.dependent_on = ip.docid);
	      delete ip from internal_proxy_status_table ip;
	      insert ignore into internal_proxy_status_table 
	      	     select * from internal_proxy_status_table2 ip2;
	end while;
	select not count(*) into good from internal_proxy_status_table;

	delete ip from internal_proxy_status_table ip;
	delete ip2 from internal_proxy_status_table ip2;
end $$	

create procedure update_internal_proxy_docids(docids varchar(16384)) 
begin
      declare len integer unsigned;
      declare cur varchar(128) default '';
      declare pos integer unsigned default 0;
      
      start transaction;
      set len = length(docids) - length(replace(docids, ',', ''));
      while pos < len do
            set cur = substring_index(substring_index(path, ',', pos + 1), '/', -1);
	    call update_proxies(cur);
	    set pos = pos + 1;
      end while;
      commit;
end $$
	
drop procedure if exists new_internal_proxy_entry $$
create procedure new_internal_proxy_entry(docid integer unsigned, depends_on integer unsigned, fields varchar(16384))
begin
	start transaction;
	call insert_internal_proxy_entry(docid, depends_on, fields);
	call update_internal_proxies(docid);
	commit;
end $$

drop procedure if exists insert_internal_proxy_entry $$
create procedure insert_internal_proxy_entry(docid integer unsigned, depends_on integer unsigned, fields varchar(16384))
begin
	declare cur varchar(128) default '';
	declare good integer default 0;
	declare len integer unsigned default 0;
	declare pos integer unsigned default 0;
	declare id integer unsigned;
	set len = length(fields) - replace(fields, ",", "");
	
	replace into internal_proxy_docids (docid, depends_on) values (docid, depends_on);
	set id = last_insert_id();
	
	call check_internal_proxy_status(good);
	
	if not good then
	   call ERROR_YOU_HAVE_TO_CREATE_A_CYCLE();
	end if;

	delete i from internal_proxy_fields i where relation_id = id;
	while pos < len do 
	      set cur = substring_index(substring_index(path, ',', pos + 1), '/', -1);
	      insert into internal_proxy_fields (relation_id, name) values (id, cur);
	      set pos = pos + 1;
	end while;
end $$

drop procedure if exists create_internal_proxy_docid_update_table $$
create procedure create_internal_proxy_docid_update_table(docid integer unsigned)
begin
	declare old_len integer unsigned default 0;
	declare new_len integer unsigned default 1;

	create temporary table if not exists internal_proxy_docid_update_table(id integer unsigned auto_increment primary key, 
	       		       					 docid integer unsigned, 
								 unique(docid)) engine=innodb;
	create temporary table if not exists internal_proxy_docid_update_table2(id integer unsigned auto_increment primary key, 
	       		       					  docid integer unsigned, 
								  unique (docid)) engine=innodb;
	delete d from internal_proxy_docid_update_table d;
	delete d2 from internal_proxy_docid_update_table2 d2;
	
	insert into internal_proxy_docid_update_table (docid) values (docid);
	
	while old_len != new_len do
	      set old_len = new_len;
	      insert ignore into internal_proxy_docid_update_table2 select * from 
	      	     internal_proxy_docid_update_table d;
	      insert ignore into internal_proxy_docid_update_table (docid) select docid from 
	      	     internal_proxy_documents i join internal_proxy_docid_update_table2 d2 
		     on (i.dependent_on = d2.docid);
	      select count(*) into new_len from internal_proxy_docid_update_table d;
	end while;

	delete d2 from internal_proxy_docid_update_table2 d2;
end $$

drop procedure if exists update_internal_proxies $$
create procedure update_internal_proxies(docid integer unsigned)
begin 
      call create_internal_proxy_docid_update_table(docid);
      call update_internal_proxies_do();
      delete d from internal_proxy_docid_update_table d;
end $$

drop procedure if exists update_internal_proxies_do $$
create procedure update_internal_proxies_do()
begin
	declare done integer default 0;
	declare a integer unsigned;
	declare c cursor for (select d.docid from internal_proxy_docid_update_table d order by id asc);
        declare continue handler for not found set done=1;
	
	open c;
	fetch c into a;

	while not done do
	      call update_internal_proxy_document(a);
	      fetch c into a;
	end while;

	close c;
end $$

create table if not exists internal_proxy_fields (
       id integer unsigned primary key, 
       relation_id integer unsigned,
       name varchar(128), 
       index (name),
       index (relation_id),
       unique (name, relation_id)) engine=innodb;

drop procedure if exists update_internal_proxy_document $$
create procedure update_internal_proxy_document(docid integer unsigned)
begin
	declare version datetime default null;
	declare dep_docid integer unsigned default 0;
	declare dep_version datetime default null;
	call public_or_latest_version(docid, version);
	
	if version is null then
	   call ERROR_NO_PUBLIC_OR_LATEST_VERSION();
	end if;

	select dependent_on into dep_docid from internal_proxy_documents i
	       where i.docid = docid;
	call public_or_latest_version(dep_docid, dep_version);
	       	
	if dep_version is null then
	   call ERROR_NO_PUBLIC_OR_LATEST_VERSION();
	end if;

	delete vf from vfields vf where
	       vf.docid = docid and vf.version = version and
	       vf.name not in (select ipf.name from internal_proxy_documents ipd join internal_proxy_fields ipf on 
	       	   	  (ipf.relation_id = ipd.id));
	insert ignore into vfields (docid, version, name, text_value, double_value, date_value, int_value)
	       select docid, version, vf.name, vf.text_value, vf.double_value, vf.date_value, vf.int_value
	       from vfields vf where 
	       vf.docid = dep_docid and vf.version = dep_version and vf.name not in 
	       (select ipf.name from internal_proxy_documents ipd join internal_proxy_fields ipf on 
	       	   	  (ipf.relation_id = ipd.id));
end $$

drop procedure if exists is_internal_proxy_document $$
create procedure is_internal_proxy_document(docid integer unsigned)
begin
	select count(*) as is_ from internal_proxy_documents i where  i.docid = docid;
end $$

delimiter ;
