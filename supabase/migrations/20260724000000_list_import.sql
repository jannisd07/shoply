-- Photo → shopping-list import (Feature: "+" attachment → AI extraction).
--
-- Two pieces of backend state:
--   1. A PRIVATE storage bucket `list-imports` that the client uploads the
--      photographed list to, under `<uid>/<uuid>.jpg`. RLS restricts every
--      operation to the owner's own folder. The Edge Function reads it with
--      the service role and deletes it immediately after extraction (DSGVO),
--      so rows here are short-lived.
--   2. A tiny `list_import_events` table backing the Edge Function's
--      per-user rate limit (12 imports / 10 min). One row per import attempt.
--
-- Idempotent: safe to re-run.

-- 1. Private bucket ---------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit)
values ('list-imports', 'list-imports', false, 10485760) -- 10 MB
on conflict (id) do nothing;

-- Owner-scoped RLS on the objects. The first path segment is the uid.
drop policy if exists "list_imports_insert_own" on storage.objects;
create policy "list_imports_insert_own" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'list-imports'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "list_imports_select_own" on storage.objects;
create policy "list_imports_select_own" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'list-imports'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "list_imports_delete_own" on storage.objects;
create policy "list_imports_delete_own" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'list-imports'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- 2. Rate-limit ledger ------------------------------------------------------
create table if not exists public.list_import_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create index if not exists list_import_events_user_time_idx
  on public.list_import_events (user_id, created_at desc);

alter table public.list_import_events enable row level security;

-- Only the Edge Function (service role) reads/writes this; users get nothing.
-- A user may see their own rows (harmless), but never insert directly — the
-- count would be trivially bypassable otherwise.
drop policy if exists "list_import_events_select_own" on public.list_import_events;
create policy "list_import_events_select_own" on public.list_import_events
  for select to authenticated
  using (user_id = auth.uid());

-- Optional housekeeping: drop ledger rows older than a day. Run from a cron
-- or manually; the rate-limit query only ever looks back 10 minutes.
-- delete from public.list_import_events where created_at < now() - interval '1 day';
