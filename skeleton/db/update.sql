# Stuff that you need to run to use the new administration system:

alter table versions add column user smallint(5) unsigned;

# Also: create queue and annotations (see structure.sql).
