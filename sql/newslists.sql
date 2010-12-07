drop table if exists newslists;
create table newslists (
       docid integer unsigned not null primary key
) engine=InnoDB;

drop table if exists calendars;
create table calendars (
       docid integer unsigned not null primary  key
) engine=InnoDB;


       