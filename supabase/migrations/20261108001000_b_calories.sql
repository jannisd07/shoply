-- Teil B, B6: calories data model (workouts, own foods, check-ins, estimate
-- fields, water RPC). NOT APPLIED: the owner applies it after an explicit yes.
--
-- Idempotent: safe to run more than once. Existing rows are kept. When it has
-- run, it sets the app flag `calories_schema_v2`; until the app sees that
-- flag it only writes the columns and source values that existed before, so
-- shipping the app before this migration is safe.
--
-- Contents
--   1. updated_at trigger function
--   2. user_food            own foods (manual entries, unknown barcodes), RLS own rows
--   3. food_log_entries     sources 'search'/'manual_estimated', estimate fields,
--                           logged_time, photo_path, health_uuid, updated_at
--   4. workout_log          own workouts, RLS own rows
--   5. nutrition_goals      credit_workouts, pace
--   6. nutrition_challenges title/question/duration_days for own challenges,
--                           one active row per built-in type only
--   7. challenge_checkins   one row per challenge and day (replaces the jsonb
--                           read-merge-write), RLS via the challenge owner,
--                           backfilled from daily_checkins
--   8. close_expired_nutrition_challenges_b()  server-side auto close, scheduled
--                           with pg_cron when the extension is installed
--   9. water_log.source + rpc log_water(p_ml, p_source, p_date)
--  10. app flag calories_schema_v2

-- 1. updated_at ----------------------------------------------------------------

create or replace function public.set_updated_at_b()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- 2. user_food -----------------------------------------------------------------

create table if not exists public.user_food (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (char_length(name) between 1 and 200),
  barcode text check (barcode is null or barcode ~ '^[0-9]{6,14}$'),
  kcal_100 numeric(7, 2) not null check (kcal_100 >= 0 and kcal_100 <= 900),
  protein_100 numeric(6, 2) check (protein_100 is null or (protein_100 >= 0 and protein_100 <= 100)),
  carbs_100 numeric(6, 2) check (carbs_100 is null or (carbs_100 >= 0 and carbs_100 <= 100)),
  fat_100 numeric(6, 2) check (fat_100 is null or (fat_100 >= 0 and fat_100 <= 100)),
  serving_g numeric(8, 2) check (serving_g is null or serving_g > 0),
  package_g numeric(8, 2) check (package_g is null or package_g > 0),
  created_at timestamptz not null default now()
);

comment on table public.user_food is
  'Own foods per user (manual entries with grams, barcodes Open Food Facts did not know). Values per 100 g.';

create unique index if not exists user_food_user_barcode_idx
  on public.user_food (user_id, barcode) where barcode is not null;
create index if not exists user_food_user_name_idx
  on public.user_food (user_id, lower(name));

alter table public.user_food enable row level security;

drop policy if exists "Users can view their own foods" on public.user_food;
create policy "Users can view their own foods"
  on public.user_food for select to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "Users can insert their own foods" on public.user_food;
create policy "Users can insert their own foods"
  on public.user_food for insert to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users can update their own foods" on public.user_food;
create policy "Users can update their own foods"
  on public.user_food for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users can delete their own foods" on public.user_food;
create policy "Users can delete their own foods"
  on public.user_food for delete to authenticated
  using ((select auth.uid()) = user_id);

-- 3. food_log_entries ------------------------------------------------------------

-- Replace the source check (created inline, so its name may differ between
-- databases): drop every check on this table that mentions `source` but not
-- `meal_type`, then add the new one.
do $$
declare
  c record;
begin
  for c in
    select conname
    from pg_constraint
    where conrelid = 'public.food_log_entries'::regclass
      and contype = 'c'
      and pg_get_constraintdef(oid) ilike '%source%'
      and pg_get_constraintdef(oid) not ilike '%meal_type%'
  loop
    execute format('alter table public.food_log_entries drop constraint %I', c.conname);
  end loop;
end;
$$;

alter table public.food_log_entries
  add constraint food_log_entries_source_check
  check (source in ('manual', 'recipe', 'barcode', 'photo', 'search', 'manual_estimated'));

alter table public.food_log_entries
  add column if not exists estimated boolean not null default false,
  add column if not exists confidence text
    check (confidence is null or confidence in ('high', 'medium', 'low')),
  add column if not exists health_uuid text,
  add column if not exists logged_time time,
  add column if not exists photo_path text,
  add column if not exists updated_at timestamptz not null default now();

comment on column public.food_log_entries.estimated is
  'Numbers come from an AI estimate (photo, "Kalorien schätzen lassen", Avo); the diary keeps saying "geschätzt".';
comment on column public.food_log_entries.confidence is
  'Estimate confidence in three word levels: high = Recht sicher, medium = Unsicher, low = Grob geschätzt.';
comment on column public.food_log_entries.photo_path is
  'Path in the meal-photos bucket (signed URLs); replaces public photo_url.';

drop trigger if exists food_log_entries_updated_at_b on public.food_log_entries;
create trigger food_log_entries_updated_at_b
  before update on public.food_log_entries
  for each row execute function public.set_updated_at_b();

-- 4. workout_log ---------------------------------------------------------------

create table if not exists public.workout_log (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  started_at timestamptz not null,
  duration_min integer not null check (duration_min > 0 and duration_min <= 1440),
  type text not null default 'other'
    check (type in ('running', 'walking', 'cycling', 'swimming', 'strength', 'yoga', 'hiit', 'hiking', 'dance', 'other')),
  intensity text not null default 'moderate'
    check (intensity in ('light', 'moderate', 'hard')),
  calories integer check (calories is null or (calories >= 0 and calories <= 10000)),
  health_uuid text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.workout_log is
  'Own workouts. kcal estimated on the device from a MET table (type, intensity, duration, weight). Workouts read from Apple Health are never stored here.';

create index if not exists workout_log_user_started_idx
  on public.workout_log (user_id, started_at desc);

alter table public.workout_log enable row level security;

drop policy if exists "Users can view their own workouts" on public.workout_log;
create policy "Users can view their own workouts"
  on public.workout_log for select to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "Users can insert their own workouts" on public.workout_log;
create policy "Users can insert their own workouts"
  on public.workout_log for insert to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users can update their own workouts" on public.workout_log;
create policy "Users can update their own workouts"
  on public.workout_log for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users can delete their own workouts" on public.workout_log;
create policy "Users can delete their own workouts"
  on public.workout_log for delete to authenticated
  using ((select auth.uid()) = user_id);

drop trigger if exists workout_log_updated_at_b on public.workout_log;
create trigger workout_log_updated_at_b
  before update on public.workout_log
  for each row execute function public.set_updated_at_b();

-- 5. nutrition_goals -------------------------------------------------------------

alter table public.nutrition_goals
  add column if not exists credit_workouts boolean not null default false,
  add column if not exists pace text
    check (pace is null or pace in ('gemuetlich', 'normal', 'zuegig'));

comment on column public.nutrition_goals.credit_workouts is
  '"Verbrauch durch Workouts gutschreiben": remaining = goal - eaten + workout kcal. Default off.';
comment on column public.nutrition_goals.pace is
  'gemuetlich / normal / zuegig. Losing 0.25 / 0.5 / 0.75 kg per week, gaining 0.1 / 0.25 / 0.4. timeline_weeks stays readable.';

-- 6. nutrition_challenges --------------------------------------------------------

alter table public.nutrition_challenges
  add column if not exists title text check (title is null or char_length(title) between 1 and 80),
  add column if not exists question text check (question is null or char_length(question) between 1 and 120),
  add column if not exists duration_days integer check (duration_days is null or duration_days between 1 and 365);

-- Own challenges may run side by side; built-in types stay one active each.
drop index if exists public.nutrition_challenges_one_active_per_type;
create unique index if not exists nutrition_challenges_one_active_per_builtin_type
  on public.nutrition_challenges (user_id, challenge_type)
  where status = 'active' and challenge_type <> 'custom';

-- 7. challenge_checkins ----------------------------------------------------------

create table if not exists public.challenge_checkins (
  id uuid primary key default gen_random_uuid(),
  challenge_id uuid not null references public.nutrition_challenges(id) on delete cascade,
  date date not null,
  kept boolean not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (challenge_id, date)
);

comment on table public.challenge_checkins is
  'One self check-in per challenge and day ("Heute geschafft?"). Two devices never overwrite each other.';

alter table public.challenge_checkins enable row level security;

drop policy if exists "Challenge owners can view check-ins" on public.challenge_checkins;
create policy "Challenge owners can view check-ins"
  on public.challenge_checkins for select to authenticated
  using (exists (
    select 1 from public.nutrition_challenges c
    where c.id = challenge_id and c.user_id = (select auth.uid())
  ));

drop policy if exists "Challenge owners can insert check-ins" on public.challenge_checkins;
create policy "Challenge owners can insert check-ins"
  on public.challenge_checkins for insert to authenticated
  with check (exists (
    select 1 from public.nutrition_challenges c
    where c.id = challenge_id and c.user_id = (select auth.uid())
  ));

drop policy if exists "Challenge owners can update check-ins" on public.challenge_checkins;
create policy "Challenge owners can update check-ins"
  on public.challenge_checkins for update to authenticated
  using (exists (
    select 1 from public.nutrition_challenges c
    where c.id = challenge_id and c.user_id = (select auth.uid())
  ))
  with check (exists (
    select 1 from public.nutrition_challenges c
    where c.id = challenge_id and c.user_id = (select auth.uid())
  ));

drop policy if exists "Challenge owners can delete check-ins" on public.challenge_checkins;
create policy "Challenge owners can delete check-ins"
  on public.challenge_checkins for delete to authenticated
  using (exists (
    select 1 from public.nutrition_challenges c
    where c.id = challenge_id and c.user_id = (select auth.uid())
  ));

drop trigger if exists challenge_checkins_updated_at_b on public.challenge_checkins;
create trigger challenge_checkins_updated_at_b
  before update on public.challenge_checkins
  for each row execute function public.set_updated_at_b();

-- Backfill from the old jsonb map; existing rows win.
insert into public.challenge_checkins (challenge_id, date, kept)
select c.id, kv.key::date, kv.value::boolean
from public.nutrition_challenges c,
     jsonb_each(c.daily_checkins) kv
where kv.key ~ '^\d{4}-\d{2}-\d{2}$'
  and jsonb_typeof(kv.value) = 'boolean'
on conflict (challenge_id, date) do nothing;

-- 8. Auto close (server schedule, never on read) --------------------------------

create or replace function public.close_expired_nutrition_challenges_b()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  closed integer;
begin
  update public.nutrition_challenges
  set status = 'completed',
      completed_at = coalesce(completed_at, target_end_at)
  where status = 'active'
    and target_end_at is not null
    and target_end_at <= now();
  get diagnostics closed = row_count;
  return closed;
end;
$$;

revoke all on function public.close_expired_nutrition_challenges_b() from public, anon, authenticated;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule(
      'close-expired-nutrition-challenges-b',
      '15 * * * *',
      'select public.close_expired_nutrition_challenges_b()'
    );
  else
    raise notice 'pg_cron is not installed: schedule close_expired_nutrition_challenges_b() another way (OPEN-ISSUES).';
  end if;
end;
$$;

-- 9. water_log.source + log_water ------------------------------------------------

alter table public.water_log
  add column if not exists source text not null default 'app'
    check (source in ('app', 'widget', 'siri', 'shortcut', 'avo', 'control'));

create or replace function public.log_water(p_ml integer, p_source text default 'app', p_date date default null)
returns public.water_log
language plpgsql
security invoker
set search_path = ''
as $$
declare
  inserted public.water_log;
begin
  if (select auth.uid()) is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;
  if p_ml is null or p_ml <= 0 or p_ml > 5000 then
    raise exception 'amount must be between 1 and 5000 ml' using errcode = '22023';
  end if;
  insert into public.water_log (user_id, logged_date, amount_ml, source)
  values (
    (select auth.uid()),
    coalesce(p_date, (now() at time zone 'Europe/Berlin')::date),
    p_ml,
    coalesce(p_source, 'app')
  )
  returning * into inserted;
  return inserted;
end;
$$;

comment on function public.log_water(integer, text, date) is
  'Adds water for the calling user (widgets, Siri, Avo). Day = p_date or today in Europe/Berlin. RLS applies (security invoker).';

revoke all on function public.log_water(integer, text, date) from public, anon;
grant execute on function public.log_water(integer, text, date) to authenticated;

-- 10. App flag -------------------------------------------------------------------

do $$
begin
  if to_regclass('public.app_flags') is not null then
    insert into public.app_flags (key, enabled, value)
    values ('calories_schema_v2', true, null)
    on conflict (key) do update set enabled = true, updated_at = now();
  else
    raise notice 'app_flags is missing: apply 20261108000000_b_app_flags.sql, then run this file again.';
  end if;
end;
$$;
