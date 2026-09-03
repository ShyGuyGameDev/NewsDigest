-- ============================================================================
-- Hash subscriber emails, and let the publishable (anon) key read the table
-- so the service_role key is no longer needed just to read.
--
-- WHAT THIS CHANGES
--   * public.subscribers no longer stores an email address. It stores
--     email_hash = HMAC_SHA256(key = pepper, msg = lower(trim(email))), hex.
--   * The pepper (HMAC key) lives ONLY in the routine's env as
--     EMAIL_HASH_PEPPER. It is never stored in the database, so leaking the
--     anon key or the whole table still reveals no addresses (an email is
--     low-entropy and a plain SHA-256 of it would be trivially brute-forced;
--     the secret pepper is what makes the hash safe to expose).
--   * anon (the sb_publishable_... key) may SELECT email_hash + created_at.
--     Writes still require the service_role key (or a privileged DB role).
--
-- NOTE
--   email_hash is one-way: it answers "is <email> subscribed?" and enforces
--   uniqueness, but cannot produce a list of addresses. encrypt_emails.sql
--   adds email_enc (reversible) for building the actual send list.
--
-- Run in the Supabase SQL Editor, top to bottom, after schema.sql.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 0. Drop the restrictive deny-all policy from schema.sql. A RESTRICTIVE
--    policy ANDs with every other policy, so while it exists nothing anon can
--    read. Dropping it first also stops FORCE ROW LEVEL SECURITY from blocking
--    the backfill UPDATE below.
-- ---------------------------------------------------------------------------
drop policy if exists "deny anon and authenticated" on public.subscribers;

-- ---------------------------------------------------------------------------
-- 1. Add the hash column and backfill every existing row.
--    For each row, compute HMAC_SHA256(key = EMAIL_HASH_PEPPER,
--    msg = lower(trim(email))) (see the snippet at the bottom) and UPDATE that
--    row by its current email. Every row must end up non-NULL or the SET NOT
--    NULL in step 2 fails.
-- ---------------------------------------------------------------------------
alter table public.subscribers add column if not exists email_hash text;

-- one UPDATE per existing row, e.g.:
-- update public.subscribers
--    set email_hash = '<hmac-sha256 hex of that row''s email>'
--  where email = '<that row''s email>';

-- ---------------------------------------------------------------------------
-- 2. Lock the column down; drop the plaintext email.
-- ---------------------------------------------------------------------------
alter table public.subscribers
  alter column email_hash set not null,
  add constraint subscribers_email_hash_hex check (email_hash ~ '^[0-9a-f]{64}$');

create unique index if not exists subscribers_email_hash_key
  on public.subscribers (email_hash);

drop index  if exists public.subscribers_email_key;
alter table public.subscribers drop column email;

-- The password-by-email helpers from schema.sql can't work without an email
-- column. Drop them (password_hash column stays; set it via service_role).
drop function if exists public.set_subscriber_password(text, text);
drop function if exists public.verify_subscriber_password(text, text);

-- ---------------------------------------------------------------------------
-- 3. Allow the anon / publishable key to read (RLS stays ON).
--    Column-level grant: anon sees email_hash + created_at only, never
--    password_hash or id. No write grant + no write policy => anon cannot
--    insert/update/delete.
-- ---------------------------------------------------------------------------
grant select (email_hash, created_at) on public.subscribers to anon;

drop policy if exists "anon reads hashes" on public.subscribers;
create policy "anon reads hashes"
  on public.subscribers
  for select
  to anon
  using (true);

-- ---------------------------------------------------------------------------
-- Recomputing hashes (do this in the routine, where the pepper lives — not in
-- the database). Python:
--
--   import hmac, hashlib, os
--   def email_hash(addr):
--       key = os.environ["EMAIL_HASH_PEPPER"].encode()
--       msg = addr.strip().lower().encode()
--       return hmac.new(key, msg, hashlib.sha256).hexdigest()
--
-- Shell (the pepper is used as an opaque string key, matching the Python above
-- which does pepper.encode() — NOT hexkey):
--   printf '%s' "$EMAIL" | tr 'A-Z' 'a-z' \
--     | openssl dgst -sha256 -mac HMAC -macopt "key:$EMAIL_HASH_PEPPER" -r \
--     | cut -d' ' -f1
-- ============================================================================
