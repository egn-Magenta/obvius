delimiter $$

create table if not exists internal_proxy_documents
       (id integer unsigned auto_increment primary key, 
        docid integer unsigned, 
	dependent_on integer unsigned, 
	unique (docid),
	index (docid), 
	index (dependent_on)
       ) engine=Innodb $$

create table if not exists internal_proxy_fields (
       id integer unsigned primary key,
       relation_id integer unsigned,
       name varchar(128), 
       index (name),
       index (relation_id),
       unique (name, relation_id)) engine=innodb $$

drop procedure if exists new_internal_proxy_entry $$
create procedure new_internal_proxy_entry(docid integer unsigned, depends_on integer unsigned, fields varchar(16384))
begin
	call insert_internal_proxy_entry(docid, depends_on, fields);
	call update_internal_proxies(docid);
end $$

drop procedure if exists update_internal_proxy_docids $$
create procedure update_internal_proxy_docids(docids varchar(16384)) 
begin
      declare len integer unsigned;
      declare cur varchar(128) default '';
      declare pos integer unsigned default 0;
      
      start transaction;
      set len = length(docids) - length(replace(docids, ',', ''));
      while pos < len + 1 do
            set cur = substring_index(substring_index(docids, ',', pos + 1), ',', -1);
	    call internal_proxy_when_document_updated(convert(cur, unsigned));
	    set pos = pos + 1;
      end while;
      commit;
end $$

drop procedure if exists insert_internal_proxy_entry $$
create procedure insert_internal_proxy_entry(docid integer unsigned, dependent_on integer unsigned, fields varchar(16384))
begin
	declare cur varchar(128) default '';
	declare good integer default 0;
	declare len integer unsigned default 0;
	declare pos integer unsigned default 0;
	declare id integer unsigned;
	
	replace into internal_proxy_documents (docid, dependent_on) values (docid, dependent_on);
	set id = last_insert_id();
	
	call check_internal_proxy_status(good);
	
	if not good then
	   call ERROR_YOU_HAVE_CREATED_A_CYCLE();
	end if;

	delete i from internal_proxy_fields i where relation_id = id;
	set len = length(fields) - length(replace(fields, ',', ''));
	while pos < len + 1 do
	      set cur = substring_index(substring_index(fields, ',', pos + 1), ',', -1);
	      insert into internal_proxy_fields (relation_id, name) values (id, cur);
	      set pos = pos + 1;
	end while;
end $$


drop procedure if exists check_internal_proxy_status $$
create procedure check_internal_proxy_status(out good integer unsigned)
begin
	declare times integer unsigned default 10;
	create temporary table if not exists internal_proxy_status_table (docid integer unsigned auto_increment primary key ) engine = heap;
	create temporary table if not exists internal_proxy_status_table2 (docid integer unsigned auto_increment primary key ) engine = heap;

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

drop procedure if exists internal_proxy_when_document_updated $$
create procedure internal_proxy_when_document_updated(docid integer unsigned)
begin
        declare done integer default 0;
        declare a integer unsigned;
        declare c cursor for (select d.docid from internal_proxy_documents d where d.dependent_on = docid);
        declare continue handler for not found set done=1;
        
        open c;
        fetch c into a;
        while not done do
              call update_internal_proxies(a);
              fetch c into a;
        end while;
        close c;

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

drop procedure if exists create_internal_proxy_docid_update_table $$
create procedure create_internal_proxy_docid_update_table(docid integer unsigned)
begin
	declare old_len integer unsigned default 0;
	declare new_len integer unsigned default 1;

	create temporary table if not exists internal_proxy_docid_update_table(id integer unsigned auto_increment primary key, 
	       		       					               docid integer unsigned, 
								               unique(docid)) engine=heap;
	create temporary table if not exists internal_proxy_docid_update_table2(id integer unsigned auto_increment primary key, 
	       		       					                docid integer unsigned, 
								                unique (docid)) engine=heap;
	delete d from internal_proxy_docid_update_table d;
	delete d2 from internal_proxy_docid_update_table2 d2;
	
	insert into internal_proxy_docid_update_table (docid) values (docid);
	
	while old_len != new_len do
	      set old_len = new_len;
	      insert ignore into internal_proxy_docid_update_table2 select * from 
	      	     internal_proxy_docid_update_table d;
	      insert ignore into internal_proxy_docid_update_table (docid) select i.docid from 
	      	     internal_proxy_documents i join internal_proxy_docid_update_table2 d2 
		     on (i.dependent_on = d2.docid);
	      select count(*) into new_len from internal_proxy_docid_update_table d;
	end while;
end $$


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
	select count(*) as is_ from internal_proxy_documents i where i.docid = docid;
end $$

drop procedure if exists clean_internal_proxies $$
create procedure clean_internal_proxies(docid integer unsigned)
begin
	declare a integer unsigned default null;
	select id into a from internal_proxy_documents i where i.docid = docid;
	
	if not (a is null) then
	   update internal_proxy_documents i join internal_proxy_documents i2 on 
	   	      (i.docid = i2.dependent_on) set i2.dependent_on = i.dependent_on 
	       	      where i.id = a;
	   delete r from internal_proxy_fields r where r.id = a;
	   delete i from internal_proxy_documents i where i.id = a;
	end if;
end $$

delimiter ;
