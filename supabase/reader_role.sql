-- Read-only role for the digest routine.
-- Run in the Supabase SQL Editor AFTER schema.sql.
-- Replace the password with a long random string and store it in a password manager.

create role newsdigest_reader with login password 'REPLACE-WITH-LONG-RANDOM-STRING';

grant usage  on schema public            to newsdigest_reader;
grant select on public.subscribers       to newsdigest_reader;

-- Optional: keep it working if the table is ever dropped/recreated.
alter default privileges in schema public grant select on tables to newsdigest_reader;

-- Verify: should return exactly one row -> subscribers | SELECT
select table_name, privilege_type
from information_schema.role_table_grants
where grantee = 'newsdigest_reader';
