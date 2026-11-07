-- Teil B, Task P0.1 (contract 3.2): remote kill switches and AI limits.
--
-- The app reads this table with the anon or user key and caches it on the
-- device (AppFlagsService, SharedPreferences key `app_flags_v1`). Nobody can
-- write through the API: there are no write policies, and anon/authenticated
-- keep only the select grant. The owner changes values in the dashboard / SQL
-- editor, which runs as a role that bypasses RLS.
--
-- The app hides offers until it knows the flags, so apply this migration
-- before shipping a build that reads it.
--
-- The edge function `ai` reads these rows with the service role: `ai_limits`
-- for the daily limits, and it has to refuse every call while `ai_enabled` is
-- false and leave out Avo's offer tools while `offers_enabled` is false, so
-- old or modified app builds cannot get around the switches.
--
-- Idempotent: safe to run more than once. Existing rows are never overwritten.

create table if not exists public.app_flags (
  key text primary key,
  enabled boolean not null default true,
  value jsonb,
  updated_at timestamptz not null default now()
);

comment on table public.app_flags is
  'Remote flags read by the app: offers_enabled and ai_enabled are kill switches, ai_limits holds the daily AI limits per plan.';

alter table public.app_flags enable row level security;

revoke all on table public.app_flags from anon, authenticated;
grant select on table public.app_flags to anon, authenticated;

drop policy if exists "App flags are readable by everyone" on public.app_flags;
create policy "App flags are readable by everyone"
  on public.app_flags
  for select
  to anon, authenticated
  using (true);

create or replace function public.app_flags_touch_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists app_flags_touch_updated_at on public.app_flags;
create trigger app_flags_touch_updated_at
  before update on public.app_flags
  for each row
  execute function public.app_flags_touch_updated_at();

insert into public.app_flags (key, enabled, value) values
  ('offers_enabled', true, null),
  ('ai_enabled', true, null),
  ('ai_limits', true, '{
    "free": {"avo_chat": 3, "meal_photo": 1, "list_import": 1, "categorize": 200, "recommend": 5, "nutrition_estimate": 10},
    "pro": {"avo_chat": 60, "meal_photo": 15, "list_import": 10, "categorize": 500, "recommend": 30, "nutrition_estimate": 50}
  }'::jsonb)
on conflict (key) do nothing;
