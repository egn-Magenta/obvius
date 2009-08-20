create table if not exists tags (
       id int(8) unsigned not null auto_increment,
       name varchar(256) not null,
       lang char(2) not null,
       unique (name, lang),
       primary key (id),
       index (name),
       index (lang)
       );


