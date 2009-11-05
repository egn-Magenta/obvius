create table shortcuts (
       id int(8) unsigned not null auto_increment not null primary key,
       user_id int(8) unsigned not null,
       docid int(8) unsigned not null,
       name varchar(512) not null,
       order_number int(8) not null);
