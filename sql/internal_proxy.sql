delimiter $$

create table if not exists internal_proxy_documents
       (id integer unsigned auto_increment primary key, 
        docid integer unsigned, 
	version datetime,
	dependent_on integer unsigned, 
	index (docid, version),
	unique (docid, version),
	index (dependent_on)
       ) engine=InnoDB $$

create table if not exists internal_proxy_fields (
       id integer unsigned auto_increment primary key,
       relation_id integer unsigned,
       name varchar(128), 
       index (name),
       index (relation_id),
       unique (name, relation_id)) engine=InnoDB $$

drop procedure if exists new_internal_proxy_entry $$
create procedure new_internal_proxy_entry(docid integer unsigned, version datetime, depends_on integer unsigned, fields varchar(16384))
begin
	call insert_internal_proxy_entry(docid, version, depends_on, fields);
	call update_internal_proxy_document(docid, version);
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
create procedure insert_internal_proxy_entry(docid integer unsigned, version datetime, dependent_on integer unsigned, fields varchar(16384))
begin
	declare cur varchar(128) default '';
	declare good integer default 0;
	declare len integer unsigned default 0;
	declare pos integer unsigned default 0;
	declare id integer unsigned;
	
	insert into internal_proxy_documents (docid, version, dependent_on) values (docid, version, dependent_on);
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
	create temporary table if not exists internal_proxy_status_table (docid integer unsigned, version datetime, primary key (docid, version) ) engine = heap;
	create temporary table if not exists internal_proxy_status_table2 (docid integer unsigned, version datetime, primary key (docid, version) ) engine = heap;

	delete ip from internal_proxy_status_table ip;
	delete ip2 from internal_proxy_status_table ip2;

	insert ignore into internal_proxy_status_table (docid) 
	       select docid from internal_proxy_documents i2;
	
	while times > 0 and not good do
	      set times = times - 1;
	      delete ip2 from internal_proxy_status_table2 ip2;

	      insert ignore into internal_proxy_status_table2 
	      	     select i.docid, i.version from internal_proxy_documents i 
		     join internal_proxy_status_table ip on
		     (i.dependent_on = ip.docid);

	      delete ip from internal_proxy_status_table ip;

	      insert ignore into internal_proxy_status_table 
	      	     select * from internal_proxy_status_table2 ip2;
              call cleanup_internal_proxy_status_table();
	      select not count(*) into good from internal_proxy_status_table ip;
	end while;

	delete ip from internal_proxy_status_table ip;
	delete ip2 from internal_proxy_status_table ip2;
end $$	

drop procedure if exists cleanup_internal_proxy_status_table $$
create procedure cleanup_internal_proxy_status_table ()
begin
	declare done integer unsigned default 0;
	declare v2 datetime default null;
	declare d integer unsigned default null;
	declare v datetime default null;
	declare c cursor for (select d.docid, d.version from internal_proxy_status_table ip);
	declare continue handler for not found set done=1;
	
	create temporary table if not exists to_be_deleted (docid integer unsigned, version datetime, primary key( docid, version));
	delete t from to_be_deleted t;

	open c;
	fetch c into d,v;

	while not done do
	      call public_or_latest_version(d, v2);
	      if v2 != v then
	      	 insert into to_be_deleted values (d,v);
	      end if;     
	      fetch c into d,v;
       end while;
       
       close c;

       delete ip from internal_proxy_status_table ip natural join to_be_deleted;
end $$
	
drop procedure if exists internal_proxy_when_document_updated $$
create procedure internal_proxy_when_document_updated(docid integer unsigned)
begin
        declare done integer default 0;
        declare a integer unsigned;
	declare v datetime;
        declare c cursor for (select d.docid, d.version from internal_proxy_documents d where d.dependent_on = docid);
        declare continue handler for not found set done=1;
        
        open c;
        fetch c into a,v;
        while not done do
              call update_internal_proxies(a, v);
              fetch c into a,v;
        end while;
        close c;
end $$

drop procedure if exists update_internal_proxies $$
create procedure update_internal_proxies(docid integer unsigned, version datetime)
begin 
      call create_internal_proxy_docid_update_table(docid, version);
      call update_internal_proxies_do();
      delete d from internal_proxy_docid_update_table d;
end $$

drop procedure if exists update_internal_proxies_do $$
create procedure update_internal_proxies_do()
begin
	declare done integer default 0;
	declare a integer unsigned;
	declare v datetime;
	declare c cursor for (select d.docid, d.version from internal_proxy_docid_update_table d order by id asc);
        declare continue handler for not found set done=1;
	
	open c;
	fetch c into a, v;

	while not done do
	      call update_internal_proxy_document(a, v);
	      fetch c into a, v;
	end while;

	close c;
end $$

drop procedure if exists create_internal_proxy_docid_update_table $$
create procedure create_internal_proxy_docid_update_table(docid integer unsigned, v datetime)
begin
	declare old_len integer unsigned default 0;
	declare new_len integer unsigned default 1;

	create temporary table if not exists internal_proxy_docid_update_table(id integer unsigned auto_increment primary key, 
	       		       					               docid integer unsigned, 
									       version datetime,
								               unique(docid, version)) engine=heap;
	create temporary table if not exists internal_proxy_docid_update_table2(id integer unsigned auto_increment primary key, 
	       		       					                docid integer unsigned, 
										version datetime,
								                unique (docid,version)) engine=heap;
	delete d from internal_proxy_docid_update_table d;
	delete d2 from internal_proxy_docid_update_table2 d2;
	
	insert into internal_proxy_docid_update_table (docid, version) values (docid, v);
	
	while old_len != new_len do
	      set old_len = new_len;
	      insert ignore into internal_proxy_docid_update_table2 select * from 
	      	     internal_proxy_docid_update_table d;
	      insert ignore into internal_proxy_docid_update_table (docid, version) 
	      	     select i.docid, i.version from 
	      	     internal_proxy_documents i join internal_proxy_docid_update_table2 d2 
		     on (i.dependent_on = d2.docid);
	      select count(*) into new_len from internal_proxy_docid_update_table d;
	end while;
end $$


drop procedure if exists update_internal_proxy_document $$
create procedure update_internal_proxy_document(docid integer unsigned, version datetime)
begin
	declare dep_docid integer unsigned default 0;
	declare dep_version datetime default null;
	
	if version is null then
	   call ERROR_NO_PUBLIC_OR_LATEST_VERSION();
	end if;

	select dependent_on into dep_docid from internal_proxy_documents i
	       where i.docid = docid and i.version = version;
	call public_or_latest_version(dep_docid, dep_version);
	       	
	if dep_version is null then
	   call ERROR_NO_PUBLIC_OR_LATEST_VERSION();
	end if;

	delete vf from vfields vf where
	       vf.docid = docid and vf.version = version and
	       vf.name not in (select ipf.name from internal_proxy_documents ipd join internal_proxy_fields ipf on 
	       	   	  (ipf.relation_id = ipd.id) where ipd.version = version and ipd.docid = docid);
	insert ignore into vfields (docid, version, name, text_value, double_value, date_value, int_value)
	       select docid, version, vf.name, vf.text_value, vf.double_value, vf.date_value, vf.int_value
	       from vfields vf where 
	       vf.docid = dep_docid and vf.version = dep_version and vf.name not in 
	       (select ipf.name from internal_proxy_documents ipd join internal_proxy_fields ipf on 
	       	   	  (ipf.relation_id = ipd.id) where ipd.docid = docid and ipd.version = version);
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
	declare done integer unsigned default 0;
	declare c cursor for (select i.id from internal_proxy_documents i where i.docid = docid);
	declare c2 cursor for (select i.id from internal_proxy_documents i where i.dependent_on = docid);
        declare continue handler for not found set done=1;
	
	open c;
	fetch c into a;
	
	while not done do
	   update internal_proxy_documents i join internal_proxy_documents i2 on 
	   	      (i.docid = i2.dependent_on) set i2.dependent_on = i.dependent_on 
		      where i.id = a;
	   delete i from internal_proxy_fields i  where i.relation_id = a;
	   delete i from internal_proxy_documents i where i.id = a;
	   fetch c into a;
	end while;
	close c;

	set done = 0;
	open c2;
	fetch c2 into a;
	
	while not done do
	   delete from internal_proxy_fields  where i.relation_id = a;
	   delete i from internal_proxy_documents i where i.id = a;
	   fetch c2 into a;
	end while;
	close c2;
end $$


delimiter ;
