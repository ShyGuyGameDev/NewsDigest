-- NewsDigest — subscriber table + RLS
-- Run this once against a blank Supabase project:
--   Dashboard → SQL Editor → paste → Run
--   or: supabase db push   (if you use the CLI)
--   or: psql "$SUPABASE_DB_URL" -f supabase/schema.sql
--
-- Security model:
--   * RLS is ON and there are NO policies for anon/authenticated → those roles
--     get zero access.
--   * The digest routine connects with the SERVICE ROLE key, which bypasses RLS.
--   * The password column stores a bcrypt HASH, never a plaintext password.

-- pgcrypto gives us crypt() / gen_salt() for password hashing.
create extension if not exists pgcrypto with schema extensions;

create table if not exists public.subscribers (
    id            uuid primary key default gen_random_uuid(),
    email         text not null,
    -- Optional. NULL = this subscriber has no password set.
    -- Store a hash (see set_subscriber_password below), not the raw password.
    password_hash text,
    created_at    timestamptz not null default now()
);

comment on table  public.subscribers            is 'NewsDigest recipients. Managed by the digest routine via the service role key.';
comment on column public.subscribers.password_hash is 'bcrypt hash (extensions.crypt). NULL when no password is set.';

-- Case-insensitive uniqueness on email.
create unique index if not exists subscribers_email_key
    on public.subscribers (lower(email));

-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------
alter table public.subscribers enable row level security;
alter table public.subscribers force  row level security;

-- Explicit deny-all for the client-facing roles. Functionally the same as
-- having no policy at all, but it documents the intent and survives someone
-- later adding a permissive policy by mistake (RESTRICTIVE wins).
drop policy if exists "deny anon and authenticated" on public.subscribers;
create policy "deny anon and authenticated"
    on public.subscribers
    as restrictive
    for all
    to anon, authenticated
    using (false)
    with check (false);

-- Nothing is granted to anon/authenticated. Only service_role (and the table
-- owner / postgres) can touch this table.
revoke all on public.subscribers from anon, authenticated;

-- ---------------------------------------------------------------------------
-- Optional password helpers (run through the service role / SQL editor)
-- ---------------------------------------------------------------------------
create or replace function public.set_subscriber_password(p_email text, p_password text)
returns void
language sql
security definer
set search_path = public, extensions
as $$
    update public.subscribers
       set password_hash = extensions.crypt(p_password, extensions.gen_salt('bf'))
     where lower(email) = lower(p_email);
$$;

create or replace function public.verify_subscriber_password(p_email text, p_password text)
returns boolean
language sql
security definer
set search_path = public, extensions
as $$
    select exists (
        select 1 from public.subscribers
         where lower(email) = lower(p_email)
           and password_hash is not null
           and password_hash = extensions.crypt(p_password, password_hash)
    );
$$;

-- Keep these callable only by the service role.
revoke all on function public.set_subscriber_password(text, text)    from public, anon, authenticated;
revoke all on function public.verify_subscriber_password(text, text) from public, anon, authenticated;
