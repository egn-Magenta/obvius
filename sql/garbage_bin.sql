delimiter $$

create table if not exists documents_backup (
  id int(8) unsigned not null auto_increment,
  parent int(8) unsigned default '0' not null,
  name char(127) default '' not null,
  type int(8) unsigned not null,
  owner smallint(5) unsigned default '0' not null,
  grp smallint(5) unsigned default '0' not null,
  accessrules text default "",
  path varchar(1024) not null,
  date_deleted datetime not null,
  delete_user integer unsigned not null,
  primary key (id),
  index (path),
  index (parent)
) $$

create table if not exists versions_backup like versions $$
create table if not exists vfields_backup like vfields $$
create table if not exists formdata_backup like formdata $$

create table if not exists docparams_backup (
       id int(8) unsigned not null auto_increment,
       deletion_time datetime not null,
       docid int(8) unsigned not null,
       name  varchar(127)  not null,
       value longtext,
       type  int(8) unsigned,
       primary key (id)
       ) $$

drop trigger post_docparams_delete $$
create trigger post_docparams_delete after delete on docparms
for each row
begin
        insert into docparams_backup (docid, name, value, type, deletion_time) values
                                     (old.docid, old.name, old.value, old.type, now());
end $$

drop trigger post_formdata_delete  $$
create trigger post_formdata_delete after delete on formdata
for each row
begin 
      insert into formdata_backup (id, docid, entry) values
                                  (old.id, old.docid, old.entry);
end $$

drop trigger post_version_delete $$
create trigger post_version_delete after delete on versions 
for each row
begin
      insert into versions_backup (docid, version, type, public, 
                                   valid, lang, user) values 
                                  (old.docid, old.version, old.type, old.public, 
                                   old.valid, old.lang, old.user);
end $$

drop trigger post_vfield_delete $$
create trigger post_vfield_delete after delete on vfields
for each row
begin 
      insert into vfields_backup (docid, version, name, text_value, int_value, 
                                  date_value, double_value) values
                                 (old.docid, old.version, old.name, old.text_value, old.int_value, 
                                  old.date_value, old.double_value);
end $$

delimiter ;

