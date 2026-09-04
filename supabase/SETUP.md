# Supabase setup

The digest routine reads its subscriber list from the `public.subscribers`
table here. Addresses are never stored in plaintext:

| column | how it's made | used for |
|---|---|---|
| `email_hash` | `HMAC_SHA256(EMAIL_HASH_PEPPER, lower(trim(email)))`, hex | uniqueness, "is X subscribed?" |
| `email_enc`  | `Fernet(EMAIL_ENC_KEY).encrypt(lower(trim(email)))` | decrypt to build the send list |
| `test`       | boolean, default `false` | routing flag: scheduled runs send to `test = false` rows, manual test runs send to `test = true` rows — the two audiences never overlap ([`add_test_column.local.sql`](add_test_column.local.sql)) |

`EMAIL_HASH_PEPPER` and `EMAIL_ENC_KEY` live only in the routine's environment
(and a local gitignored `.env`) — never in the database, never in this repo.

## Fresh project

1. **New project** at supabase.com/dashboard — strong DB password, nearby region.
2. **SQL Editor → New query**, run in order:
   - [`schema.sql`](schema.sql) — creates `public.subscribers`, RLS on.
   - [`hash_emails.sql`](hash_emails.sql) — adds `email_hash`, opens anon `SELECT`.
   - [`encrypt_emails.sql`](encrypt_emails.sql) — adds `email_enc`.
   Each file's header explains its backfill step.
3. **Generate the keys** (once), store in the routine env + local `.env`:
   ```bash
   python3 -c "import secrets; print('EMAIL_HASH_PEPPER=' + secrets.token_hex(32))"
   python3 -c "from cryptography.fernet import Fernet; print('EMAIL_ENC_KEY=' + Fernet.generate_key().decode())"
   ```
4. **Routine environment** — set `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`
   (Project Settings → API keys → publishable — safe to expose), and
   `EMAIL_ENC_KEY`. Add `EMAIL_HASH_PEPPER` only if the routine also checks
   membership. Never put a `service_role` key or DB password here.

## RLS summary (after all three SQL files)

- RLS on; one policy: `anon` may `SELECT`.
- Column grant: `anon` sees `email_hash, email_enc, created_at` only.
- No write grant / no write policy → inserts, updates, deletes require the
  `service_role` key.

## Adding / removing a subscriber

Writes need the `service_role` key (Project Settings → API keys), so do this
from the SQL Editor or a separate admin tool — not the routine.

```sql
-- add
insert into public.subscribers (email_hash, email_enc)
values ('<hmac-sha256 hex>', '<fernet token>');

-- remove
delete from public.subscribers where email_hash = '<hmac-sha256 hex>';
```

Compute the two values with the pepper / key (see each SQL file's footer for
Python and shell snippets).

## If a key leaks

- **Publishable key** — Project Settings → API keys → roll it. Low urgency: it
  only yields ciphertext.
- **`EMAIL_ENC_KEY`** — generate a new one, re-encrypt every `email_enc`, update
  the routine env and `.env`.
- **`service_role` key** — Project Settings → API keys → roll it.
