SELECT version, dirty FROM schema_migrations;
SELECT rolname, rolsuper, rolcreatedb, rolcreaterole
FROM pg_roles WHERE rolname LIKE 'libratrack%';
SELECT id, title, isbn FROM books WHERE isbn LIKE 'DEVOPS-%' ORDER BY id;
