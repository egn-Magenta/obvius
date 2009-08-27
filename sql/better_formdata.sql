create table if not exists formdata_entry (
       entry_id integer unsigned primary key auto_increment not null,
       docid integer unsigned not null,
       entry_nr integer unsigned not null,
       time datetime not null,
       foreign key(docid) references documents(id),
       unique (docid, entry_nr)) 
           character set utf8 
           collate utf8_danish_ci;

create table if not exists formdata_entry_data (
       id integer unsigned primary key auto_increment not null,
       entry_id integer unsigned not null,
       name varchar(255) not null,
       value text not null,
       foreign key(entry_id) references formdata_entry(entry_id) on delete cascade,
       unique (name, entry_id))
          character set utf8
          collate utf8_danish_ci;
       
