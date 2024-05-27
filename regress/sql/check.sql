SET client_min_messages = warning;

SELECT col1, to_char("time", 'YYYY-MM-DD HH24:MI:SS'), ","")" FROM tbl_cluster ORDER BY 1, 2;
SELECT * FROM tbl_only_ckey ORDER BY 1;
SELECT * FROM tbl_only_pkey ORDER BY 1;
SELECT * FROM tbl_gistkey ORDER BY 1;

SET enable_seqscan = on;
SET enable_indexscan = off;
SELECT * FROM tbl_with_dropped_column ;
SELECT * FROM view_for_tbl ORDER BY 1, 2;
SELECT * FROM tbl_with_dropped_toast;
SET enable_seqscan = off;
SET enable_indexscan = on;
SELECT * FROM tbl_with_dropped_column ORDER BY 1, 2;
SELECT * FROM view_for_tbl;
SELECT * FROM tbl_with_dropped_toast;
RESET enable_seqscan;
RESET enable_indexscan;
-- check if storage option for both table and TOAST table didn't go away.
SELECT CASE relkind
       WHEN 'r' THEN relname
       WHEN 't' THEN 'toast_table'
       END as table,
       reloptions
FROM pg_class
WHERE relname = 'tbl_with_toast' OR relname = 'pg_toast_' || 'tbl_with_toast'::regclass::oid
ORDER BY 1;
SELECT pg_relation_size(reltoastrelid) = 0 as check_toast_rel_size FROM pg_class WHERE relname = 'tbl_with_mod_column_storage';

--
-- check broken links or orphan toast relations
--
SELECT oid, relname
  FROM pg_class
 WHERE relkind = 't'
   AND oid NOT IN (SELECT reltoastrelid FROM pg_class WHERE relkind = 'r');

SELECT oid, relname
  FROM pg_class
 WHERE relkind = 'r'
   AND reltoastrelid <> 0
   AND reltoastrelid NOT IN (SELECT oid FROM pg_class WHERE relkind = 't');

-- check columns options
SELECT attname, attstattarget, attoptions
FROM pg_attribute
WHERE attrelid = 'tbl_idxopts'::regclass
AND attnum > 0
ORDER BY attnum;

--
-- NOT NULL UNIQUE
--
CREATE TABLE tbl_nn    (col1 int NOT NULL, col2 int NOT NULL);
CREATE TABLE tbl_uk    (col1 int NOT NULL, col2 int         , UNIQUE(col1, col2));
CREATE TABLE tbl_nn_uk (col1 int NOT NULL, col2 int NOT NULL, UNIQUE(col1, col2));
CREATE TABLE tbl_pk_uk (col1 int NOT NULL, col2 int NOT NULL, PRIMARY KEY(col1, col2), UNIQUE(col2, col1));
CREATE TABLE tbl_nn_puk (col1 int NOT NULL, col2 int NOT NULL);
CREATE UNIQUE INDEX tbl_nn_puk_pcol1_idx ON tbl_nn_puk(col1) WHERE col1 < 10;
\! halo_migrate --execute --alter='ADD COLUMN a1 INT' --dbname=contrib_regression --table=tbl_nn
-- => WARNING
\! halo_migrate --execute --alter='ADD COLUMN a1 INT' --dbname=contrib_regression --table=tbl_uk
-- => WARNING
\! halo_migrate --execute --alter='ADD COLUMN a1 INT' --dbname=contrib_regression --table=tbl_nn_uk
-- => OK
\! halo_migrate --execute --alter='ADD COLUMN a1 INT' --dbname=contrib_regression --table=tbl_pk_uk
-- => OK
\! halo_migrate --execute --alter='ADD COLUMN a1 INT' --dbname=contrib_regression --table=tbl_nn_puk
-- => WARNING

--
-- Triggers handling
--
CREATE FUNCTION trgtest() RETURNS trigger AS
$$BEGIN RETURN NEW; END$$
LANGUAGE plpgsql;
CREATE TABLE trg1 (id integer PRIMARY KEY);
CREATE TRIGGER repack_trigger_1 AFTER UPDATE ON trg1 FOR EACH ROW EXECUTE PROCEDURE trgtest();
\! halo_migrate --execute --alter='ADD COLUMN a1 INT' --dbname=contrib_regression --table=trg1
CREATE TABLE trg2 (id integer PRIMARY KEY);
CREATE TRIGGER repack_trigger AFTER UPDATE ON trg2 FOR EACH ROW EXECUTE PROCEDURE trgtest();
\! halo_migrate --execute --alter='ADD COLUMN a1 INT' --dbname=contrib_regression --table=trg2
CREATE TABLE trg3 (id integer PRIMARY KEY);
CREATE TRIGGER repack_trigger_1 BEFORE UPDATE ON trg3 FOR EACH ROW EXECUTE PROCEDURE trgtest();
\! halo_migrate --execute --alter='ADD COLUMN a1 INT' --dbname=contrib_regression --table=trg3


--
-- Dry run
--
\! halo_migrate --alter='ADD COLUMN a1 INT' --dbname=contrib_regression --table=tbl_cluster


-- Test --schema
--
CREATE SCHEMA test_schema1;
CREATE TABLE test_schema1.tbl1 (id INTEGER PRIMARY KEY);
CREATE TABLE test_schema1.tbl2 (id INTEGER PRIMARY KEY);
CREATE SCHEMA test_schema2;
CREATE TABLE test_schema2.tbl1 (id INTEGER PRIMARY KEY);
CREATE TABLE test_schema2.tbl2 (id INTEGER PRIMARY KEY);
-- => OK
\! halo_migrate --execute --alter='ADD COLUMN a1 INT' --dbname=contrib_regression --table=test_schema1.tbl1


--
-- don't kill backend
--
\! halo_migrate --execute  --alter='ADD COLUMN dkb1 INT' --dbname=contrib_regression --table=tbl_cluster --no-kill-backend


--
-- table inheritance check
--
CREATE TABLE parent_a(val integer primary key);
CREATE TABLE child_a_1(val integer primary key) INHERITS(parent_a);
CREATE TABLE child_a_2(val integer primary key) INHERITS(parent_a);
CREATE TABLE parent_b(val integer primary key, i1 int NOT NULL);
CREATE TABLE child_b_1(val integer primary key) INHERITS(parent_b);
CREATE TABLE child_b_2(val integer primary key) INHERITS(parent_b);
-- => OK
\! halo_migrate --execute --alter='ADD COLUMN a1 INT' --dbname=contrib_regression --table=parent_a
-- => OK
\! halo_migrate --execute --alter='ADD COLUMN a1 TEXT' --dbname=contrib_regression --table=child_a_1
-- => ERROR
-- TODO non deterministic output \! halo_migrate --execute --alter='NO INHERIT parent_a' --dbname=contrib_regression --table=child_a_2
-- => ERROR
-- TODO non deterministic output \! halo_migrate --execute --alter='ADD COLUMN i1 TEXT' --dbname=contrib_regression --table=child_b_1
