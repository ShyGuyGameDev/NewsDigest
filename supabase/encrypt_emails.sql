-- ============================================================================
-- Add a REVERSIBLE encrypted copy of each email, so someone holding the
-- encryption key can list every subscriber address without knowing any of
-- them in advance -- while anyone with only the publishable key still sees
-- ciphertext.
--
-- Run in the Supabase SQL Editor, top to bottom, AFTER hash_emails.sql.
--
-- COLUMNS AFTER THIS RUNS
--   email_hash  HMAC-SHA256(pepper, email)      -- one-way; dedup + "is X subscribed?"
--   email_enc   Fernet(EMAIL_ENC_KEY, email)    -- two-way; decrypt to enumerate
--
-- KEYS (both live ONLY in the routine's env / .env, never in the database):
--   EMAIL_HASH_PEPPER   HMAC key for email_hash
--   EMAIL_ENC_KEY       Fernet key (AES-128-CBC + HMAC) for email_enc
--
-- A leak of the publishable key or the whole table still exposes no address:
-- email_hash is not invertible, and email_enc is useless without EMAIL_ENC_KEY.
-- Decrypt happens in the routine (Python: cryptography.fernet), never in SQL.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Add the column and backfill every existing row.
--    For each row compute Fernet(EMAIL_ENC_KEY).encrypt(lower(trim(email)))
--    (see the snippet at the bottom) and UPDATE that row, matched by its
--    email_hash. Regenerate EMAIL_ENC_KEY => re-encrypt every row. Every row
--    must end up non-NULL or the SET NOT NULL below fails.
-- ---------------------------------------------------------------------------
alter table public.subscribers add column if not exists email_enc text;

-- one UPDATE per existing row, e.g.:
-- update public.subscribers
--    set email_enc = '<fernet token for that row''s email>'
--  where email_hash = '<that row''s email_hash>';

-- ---------------------------------------------------------------------------
-- 2. Constrain it.  Fernet tokens are URL-safe base64 and always start "gAAAAA".
-- ---------------------------------------------------------------------------
alter table public.subscribers
  alter column email_enc set not null,
  add constraint subscribers_email_enc_fmt
    check (email_enc ~ '^gAAAAA[A-Za-z0-9_-]+=*$');

-- ---------------------------------------------------------------------------
-- 3. Let the publishable (anon) key read it. Re-stating the whole column list
--    is idempotent. The existing "anon reads hashes" SELECT policy already
--    covers every column anon is granted, so no policy change is needed.
--    Still no write grant / no write policy => writes need the service_role key.
-- ---------------------------------------------------------------------------
grant select (email_hash, email_enc, created_at) on public.subscribers to anon;

-- ---------------------------------------------------------------------------
-- Enumerate every subscriber (run in the routine, where EMAIL_ENC_KEY lives):
--
--   import os, requests
--   from cryptography.fernet import Fernet
--   f = Fernet(os.environ["EMAIL_ENC_KEY"].encode())
--   rows = requests.get(
--       f'{os.environ["SUPABASE_URL"]}/rest/v1/subscribers',
--       params={"select": "email_enc"},
--       headers={"apikey": os.environ["SUPABASE_PUBLISHABLE_KEY"],
--                "Authorization": f'Bearer {os.environ["SUPABASE_PUBLISHABLE_KEY"]}'},
--   ).json()
--   emails = sorted(f.decrypt(r["email_enc"].encode()).decode() for r in rows)
-- ============================================================================
