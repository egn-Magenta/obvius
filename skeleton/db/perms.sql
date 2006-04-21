# $Id$

#include <conf/config.h>

#define QUOTE(a) #a

#if "DBTYPE" eq "mysql"
# XXX When Obvius starts to write on one handle as one user and read on
# another handle as another user, this needs adjustment:

#define USER QUOTE(DBUSERNAME##_normal)@QUOTE(HOSTNAME)

use mysql;
# grant select on DBNAME.* to USER identified by 'default_normal';
grant select,insert,update,delete on DBNAME.* to USER identified by QUOTE(DBPASSWORD);
# grant insert,update on DBNAME.subscribers to USER;
# grant insert,update,delete on DBNAME.subscriptions to USER;

#elif "DBTYPE" eq "pgsql"

#define U DBUSERNAME##_normal

#ifndef CYCLE

-- pgx_grant(PRIVILEGE, TABLES, USER)
--  Grants PRIVILEGE to USER on objects like TABLES%
--  Grants to tables, views and sequences.
CREATE OR REPLACE FUNCTION pgx_grant(text,text,text) RETURNS int4 AS $$
DECLARE
	priv ALIAS FOR $1;
	patt ALIAS FOR $2;
	who  ALIAS FOR $3;
	obj  record;
BEGIN
	FOR obj IN SELECT c.relname FROM pg_class c
	LEFT JOIN pg_namespace n ON
		n.oid = c.relnamespace
	WHERE c.relname LIKE patt 
	AND c.relkind IN ('r','v','S') 
	AND n.nspname NOT IN ('pg_catalog', 'pg_toast')
	AND pg_table_is_visible(c.oid)
	LOOP
		EXECUTE 'GRANT ' || priv || ' ON ' || obj.relname || ' TO ' || who;
	END LOOP;
	RETURN 0;
END;
$$ LANGUAGE 'plpgsql';

CREATE USER U;

#endif -- CYCLE

SELECT pgx_grant('SELECT,INSERT,UPDATE,DELETE', '%', QUOTE(U));

#else

#error DBTYPE is invalid or not specified, must be one of: [mysql, pgsql]

#endif
