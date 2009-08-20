delimiter $$

create table if not exists user_surveillance_docs (
       id integer unsigned auto_increment not null,
       user_id integer unsigned not null,
       docid integer unsigned not null,
       primary key (id),
       index (docid),
       index (user_id),
       unique (user_id, docid)
) engine = INNODB $$

create table if not exists user_surveillance_sites (
       id integer unsigned auto_increment not null,
       user_id integer unsigned not null,
       docid integer unsigned not null,
       primary key (id),
       index (user_id),
       index (docid),
       unique (user_id, docid)
) engine = INNODB $$

       
drop trigger post_user_delete $$
create trigger post_user_delete after delete on users
for each row
begin
	call delete_user_surveillance(old.id);
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

drop procedure if exists delete_user_surveillance $$
create procedure delete_user_surveillance(user_id integer unsigned)
begin
	delete from user_surveillance_docs where user_surveillance_docs.user_id = user_id;
        delete from user_surveillance_sites where user_surveillance_sites.user_id = user_id;
end $$

drop trigger post_user_insert $$
create trigger post_user_insert after insert on users 
for each row
begin 
      call delete_user_surveillance(new.id);
      if new.surveillance is not null and new.surveillance != '' then
          call create_user_surveillance(new.id, new.surveillance);
      end if;	  
end $$

drop trigger post_user_update $$
create trigger post_user_update after update on users 
for each row
begin 
      call delete_user_surveillance(new.id);
      if new.surveillance is not null and new.surveillance != '' then
            call create_user_surveillance(new.id, new.surveillance);
      end if;
end $$

drop procedure if exists create_user_surveillance $$
create procedure create_user_surveillance (user_id integer unsigned, surveillance_data text) 
begin
	declare len integer unsigned;
	declare pos integer unsigned default 0;
	declare cur_data text;
	declare did text;
	declare site_or_page text;
	declare sd text;

	create temporary table if not exists surv_temp (docid integer unsigned, site text);
	delete from surv_temp;
	set sd = concat(surveillance_data, ';');
	set len = length(sd) - length(replace(sd, ';', ''));
	while pos < len do
	      set cur_data = substring_index(substring_index(sd, ';', pos + 1), ';', -1);
	      set did = substring_index(cur_data, ':', -1);
	      set site_or_page = substring_index(cur_data, ':', 1);
	      set pos = pos + 1;
	      insert into surv_temp (docid, site) values (did, site_or_page);
	end while;
	
	replace into user_surveillance_sites (docid, user_id)
	       select surv_temp.docid, user_id from 
	       surv_temp where site = 'omrade';
	replace into user_surveillance_docs  (docid, user_id)
	       select surv_temp.docid, user_id from 
	       surv_temp where site = 'webside';
end $$	
delimiter ;
