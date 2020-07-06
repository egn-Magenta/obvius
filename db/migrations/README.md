# DB Migrations for `obvius`

This folder contains migrations relevant for all Obvius installations.
A migration consists of a folder containing one or more files. These
files can be SQL scripts, perl scripts or any file with the execute bit set.

Example directory structure:

```
migrations/
 |
 |-- 01-add-foo-data/
 |     \
 |      \-- 01-create-foo-table.sql
 |      |
 |      |-- 02-insert-foo-data.pl
 |
 |-- 02-add-bar-table/
      \
       \-- add-bar-table.sql
```