# Supabase setup — from a brand-new project

**Status: not in use.** The digest routine reads recipients from Gmail. Only
follow this when you decide to move the subscriber list into Supabase.

The table holds email addresses (PII) and optional password hashes, so every
step below is about keeping the key that can read it out of anywhere public.

---

## 0. Clean up the old project first

If you created an earlier project and pasted a `service_role` key into
`.env.example` or the cloud "Environment variables" box:

1. In the Supabase dashboard, open the old project → **Settings → General →
   Delete project**. Deleting it permanently invalidates every key it issued,
   which is the simplest way to kill the leaked one.
2. Remove those `SUPABASE_*` lines from the Claude Code cloud environment box
   (the field that says "visible to anyone using this environment").
3. Confirm no real key is in `.env.example` (it should only have placeholders)
   and that `.env` is listed in `.gitignore`.

---

## 1. Create the project

1. https://supabase.com/dashboard → **New project**.
2. Pick an org, name it (e.g. `newsdigest`), set a strong database password,
   choose a region near you. Wait for provisioning.

## 2. Create the schema

1. Left sidebar → **SQL Editor** → **New query**.
2. Paste the entire contents of [`schema.sql`](schema.sql) and click **Run**.
3. Verify: **Table Editor** → you should see `public.subscribers` with a
   shield icon (RLS enabled). **Authentication → Policies** should show one
   restrictive `deny anon and authenticated` policy.

## 3. Get a secret API key

1. **Project Settings → API keys**.
2. Use the modern **secret keys** (not the legacy `service_role` JWT if you can
   avoid it): click **Create new secret key**, name it `newsdigest-routine`,
   copy the value once (it is shown only once).
   - This key bypasses RLS. Treat it like a password.
3. Also copy the **Project URL** (`https://<ref>.supabase.co`) from
   **Project Settings → API**.

## 4. Store the key — where it may and may not go

| Location | OK? |
|---|---|
| `.env` in this repo (gitignored) | ✅ for local runs only |
| The routine's dedicated secret store / encrypted env | ✅ |
| `.env.example` | ❌ that file is committed |
| Claude Code cloud "Environment variables" box | ❌ shared-visible, warns against secrets |
| Any git-tracked file, Slack, a comment | ❌ |

Local setup:

```bash
cp .env.example .env
# edit .env:
#   SUPABASE_URL=https://<ref>.supabase.co
#   SUPABASE_SERVICE_ROLE_KEY=<the secret key>
```

## 5. Tighten access (recommended)

Rather than a project-wide secret key, give the routine a dedicated database
role that can only read this one table. In the SQL Editor:

```sql
create role newsdigest_reader login password 'CHOOSE-A-STRONG-ONE';
grant usage on schema public to newsdigest_reader;
grant select on public.subscribers to newsdigest_reader;
```

Then the routine connects with that role's connection string
(**Project Settings → Database → Connection string**, swap in the role name and
password) instead of the secret key. A leak of this credential exposes reads of
the subscriber list and nothing else.

## 6. Point the routine at Supabase

1. Add `SUPABASE_URL` and the key/connection string to the routine's secret
   env (step 4).
2. Change the recipient-building step to read from Supabase instead of Gmail:

   ```bash
   curl -s "$SUPABASE_URL/rest/v1/subscribers?select=email" \
     -H "apikey: $SUPABASE_SERVICE_ROLE_KEY" \
     -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY"
   ```

   Lowercase, trim, dedupe, drop `shyguygamedev@gmail.com`, use the rest as Bcc.
3. Update `README.md`: replace the Gmail "Recipients" mechanism with the
   Supabase one (or document that Supabase is now primary and Gmail forwards are
   ignored). Flip the "NOT IN USE" heading.
4. Decide how rows get added/removed (manual SQL, a small admin page, an
   unsubscribe RPC — see the helper functions in `schema.sql`).

## 7. If a key ever leaks

- Secret key: **Project Settings → API keys → revoke**, create a new one.
- `newsdigest_reader` role: `ALTER ROLE newsdigest_reader PASSWORD '...';`
- Legacy `service_role` JWT: **Project Settings → API → roll the JWT secret**
  (this also rotates `anon`; update every consumer).
