delimiter $$

create table if not exists docid_path (
       path varchar(1024), 
       docid integer unsigned primary key,
       index (path)) engine=innodb $$

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

drop procedure if exists publish_version $$
create procedure publish_version(docid integer unsigned, version datetime, lang varchar(100))
begin
        update versions v set public = 0 where (lang is null or (v.lang = lang));
        update versions v set public = 1 where (v.docid = docid and v.version = version);
end $$

drop procedure if exists unpublish_document $$
create procedure unpublish_document(docid integer unsigned, lang varchar(100))
begin
        update versions v set public = 0 where v.docid = docid and (lang is null or (v.lang = lang));
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
               join versions v on (d.id = v.docid)
               left join vfields vf1 on 
                    (v.docid = vf1.docid and vf1.version = v.version and 
                    vf1.name in ('content', 'title', 'short_title'))
        where    
		(v.public = 1 or v.version = (select max(v2.version) from versions v2 where v2.docid  = d.id)) and
                (pattern is null or vf1.text_value like pattern or d.name like pattern) and
                (owner is null or d.owner = owner) and
                (grp is null or d.grp = grp) and
                (older_than is null or v.version < older_than) and
                (newer_than is null or v.version > newer_than);
end $$                               

drop procedure if exists public_or_latest_version $$
create procedure public_or_latest_version (did integer unsigned, out version datetime) 
begin
        select v.version into version from versions v 
               where v.docid = did and 
                     (v.public = 1 or 
                     ((not exists 
                          (select * from versions v2 where 
                                  v2.docid = did and 
                                  v2.public = 1))
                      and (v.version in (select max(v3.version) 
                          from versions v3 where v3.docid = did)))) limit 1;
end $$

drop procedure if exists add_vfield $$
create procedure add_vfield(docid integer unsigned, version datetime, name varchar(1024), text_value varchar(16384), int_value integer, double_value double, date_value datetime)
begin
	insert into vfields 
	       (docid, version, name, text_value, int_value, double_value, date_value) values
	       (docid, version, ucase(name), text_value, int_value, double_value, date_value);
end $$

drop procedure if exists read_vfields $$
create procedure read_vfields(docid integer unsigned, version datetime, names varchar(16384))
begin
	declare pos integer unsigned default 0;
	declare len integer unsigned default 0;
	
	create temporary table if not exists read_vfields_helper (name varchar(1024) primary key) engine = heap;
	delete r from read_vfields_helper r;

	set len = length(names) - length(replace(names, ",", ""));
	while pos < len or (pos = 0 and len = 0) do
	      insert into read_vfields_helper values (substring_index(substring_index(names, ",", pos + 1), ",", -1));
	end while;
	
	select vf.* from vfields vf join read_vfields_helper r on (vf.docid = docid and vf.version = version and vf.name = r.name);
end $$

drop procedure if exists read_vfields_from_pol $$
create procedure read_vfields_from_pol(docid integer unsigned, names varchar(16384))
begin
	declare version datetime default null;
	
	call public_or_latest_version(docid, version);
	if version is null then
	   call ERROR_NO_PUBLIC_OR_LATEST_VERSION();
	end if;	
	
	call read_vfields(docid, version, names);
end $$

delimiter ;
