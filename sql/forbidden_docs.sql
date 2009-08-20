delimiter $$
create table if not exists forbidden_docs (
       docid integer unsigned not null primary key
       ) $$


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
