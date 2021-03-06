delimiter $$
create table if not exists forbidden_docs (
       docid integer unsigned not null primary key,
       foreign key (docid) references documents (id) on delete cascade
) $$    


create table if not exists forbidden_docs_users (
       docid integer unsigned not null,
       user smallint(5) unsigned not null,
       foreign key (docid) references forbidden_docs(docid) on delete cascade,
       foreign key (user) references users(id) on delete cascade
) $$

create table if not exists forbidden_docs_groups (
       docid integer unsigned not null,
       grp smallint(5) unsigned not null,
       foreign key (docid) references forbidden_docs(docid) on delete cascade,
       foreign key (grp) references groups(id) on delete cascade
);

create table if not exists forbidden_docs_ips (
       docid integer unsigned not null,
       ip varchar(128) not null,
       foreign key (docid) references forbidden_docs(docid) on delete cascade
);
       
       

drop procedure if exists is_forbidden_doc $$
create procedure is_forbidden_doc (docid integer unsigned)
begin
     declare tid integer unsigned;
     declare cid integer unsigned;
     declare is_forbidden boolean default false;
 
     set tid = docid;
     set cid = tid;
     scanner:while tid != 0 do
           select true into is_forbidden from forbidden_docs fd where fd.docid = tid;
           if is_forbidden then
              leave scanner;
           end if;
           select d.parent into tid from documents d
                  where d.id = tid;
           if cid = tid then
              leave scanner;
           end if;
           set cid = tid;
     end while ;
     select is_forbidden;             
end $$

delimiter ;
