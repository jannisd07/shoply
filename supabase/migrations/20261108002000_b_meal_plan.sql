-- Teil B, B7 (Konzept 14 "Wochenplan"): the weekly meal plan.
--
-- meal_plans          one row per account and week, only when the week has
--                     its own target list or was sent once (first_sent_at:
--                     the success moment shows only on the first send).
-- meal_plan_entries   one recipe on one day. The id is made on the device
--                     (uuid v4), so offline adds, undo (re-insert with the
--                     same id) and retried upserts are idempotent.
-- meal_plan_settings  one row per account.
--
-- plan_date and week_start are the person's LOCAL calendar days, never UTC.
-- A week runs Monday to Sunday (ISO, W-02).
--
-- recipe_id is text without a foreign key. recipes.id is text in
-- database/migrations/insert_50_recipes.sql ('recipe_001') but uuid
-- according to later migrations (food_log_entries.source_recipe_id uuid
-- references recipes(id)); the production type is not known for sure. text
-- holds both kinds of id, and saved_recipes.recipe_id does the same. A
-- deleted recipe leaves its row behind; recipe_snapshot keeps name, photo,
-- kcal and ingredients, and the app shows "Rezept nicht mehr verfügbar"
-- when the id no longer loads.
--
-- Access: every row belongs to one person (user_id = auth.uid()); the plan
-- is personal in version 1 (FW-03). A row may only point at a shopping list
-- the person owns or is a member of. That is checked by a trigger when the
-- list id is set or changed, not by the policies: a person who later leaves
-- a shared list can still change servings of an entry that was sent there.
--
-- Not done here (owner, OPEN-ISSUES): add meal_plan_entries and meal_plans
-- to the supabase_realtime publication for live sync between devices.
--
-- Idempotent: safe to run more than once.

-- ---------------------------------------------------------------- helpers

-- Whether the signed-in person owns [target_list_id] or is a member of it.
-- security definer so the answer does not depend on the list tables' own
-- policies; it only ever answers for auth.uid().
create or replace function public.meal_plan_b_can_use_list(target_list_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
      select 1 from public.shopping_lists sl
      where sl.id = target_list_id and sl.owner_id = (select auth.uid())
    )
    or exists (
      select 1 from public.list_members lm
      where lm.list_id = target_list_id and lm.user_id = (select auth.uid())
    );
$$;

revoke execute on function public.meal_plan_b_can_use_list(uuid) from public, anon;
grant execute on function public.meal_plan_b_can_use_list(uuid) to authenticated;

create or replace function public.meal_plan_b_touch()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- ---------------------------------------------------------------- meal_plans

create table if not exists public.meal_plans (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references public.users(id) on delete cascade,
  week_start date not null check (extract(isodow from week_start) = 1),
  target_list_id uuid references public.shopping_lists(id) on delete set null,
  first_sent_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, week_start)
);

comment on table public.meal_plans is
  'Wochenplan: one row per account and ISO week (week_start = Monday, local day). target_list_id overrides the default target list; first_sent_at marks the first send of the week.';

create or replace function public.meal_plans_b_check_list()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.target_list_id is not null
     and (tg_op = 'INSERT' or new.target_list_id is distinct from old.target_list_id)
     and not public.meal_plan_b_can_use_list(new.target_list_id) then
    raise exception 'target_list_id is not a list of this person'
      using errcode = 'insufficient_privilege';
  end if;
  return new;
end;
$$;

drop trigger if exists meal_plans_b_check_list on public.meal_plans;
create trigger meal_plans_b_check_list
  before insert or update on public.meal_plans
  for each row execute function public.meal_plans_b_check_list();

drop trigger if exists meal_plans_b_touch on public.meal_plans;
create trigger meal_plans_b_touch
  before update on public.meal_plans
  for each row execute function public.meal_plan_b_touch();

alter table public.meal_plans enable row level security;
revoke all on table public.meal_plans from anon, authenticated;
grant select, insert, update, delete on table public.meal_plans to authenticated;

drop policy if exists "Own meal plan weeks are readable" on public.meal_plans;
create policy "Own meal plan weeks are readable"
  on public.meal_plans for select to authenticated
  using (user_id = (select auth.uid()));

drop policy if exists "Own meal plan weeks can be added" on public.meal_plans;
create policy "Own meal plan weeks can be added"
  on public.meal_plans for insert to authenticated
  with check (user_id = (select auth.uid()));

drop policy if exists "Own meal plan weeks can be changed" on public.meal_plans;
create policy "Own meal plan weeks can be changed"
  on public.meal_plans for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

drop policy if exists "Own meal plan weeks can be removed" on public.meal_plans;
create policy "Own meal plan weeks can be removed"
  on public.meal_plans for delete to authenticated
  using (user_id = (select auth.uid()));

-- ---------------------------------------------------------------- meal_plan_entries

create table if not exists public.meal_plan_entries (
  id uuid primary key,
  user_id uuid not null default auth.uid() references public.users(id) on delete cascade,
  plan_date date not null,
  recipe_id text check (recipe_id is null or char_length(recipe_id) between 1 and 128),
  recipe_snapshot jsonb not null default '{}'::jsonb
    check (jsonb_typeof(recipe_snapshot) = 'object' and octet_length(recipe_snapshot::text) <= 65536),
  servings int not null check (servings between 1 and 20),
  meal_type text check (meal_type in ('breakfast', 'lunch', 'dinner', 'snack')),
  position int not null default 0 check (position >= 0),
  sent_list_id uuid references public.shopping_lists(id) on delete set null,
  sent_servings int check (sent_servings is null or sent_servings between 1 and 20),
  sent_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.meal_plan_entries is
  'Wochenplan: one recipe on one local day. id is made by the app. recipe_snapshot keeps name, photo, kcal per serving and ingredients. sent_list_id/sent_servings/sent_at: where and for how many servings the ingredients went (only the difference is sent again).';

create index if not exists meal_plan_entries_user_date_idx
  on public.meal_plan_entries (user_id, plan_date);

create or replace function public.meal_plan_entries_b_check_list()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.sent_list_id is not null
     and (tg_op = 'INSERT' or new.sent_list_id is distinct from old.sent_list_id)
     and not public.meal_plan_b_can_use_list(new.sent_list_id) then
    raise exception 'sent_list_id is not a list of this person'
      using errcode = 'insufficient_privilege';
  end if;
  return new;
end;
$$;

drop trigger if exists meal_plan_entries_b_check_list on public.meal_plan_entries;
create trigger meal_plan_entries_b_check_list
  before insert or update on public.meal_plan_entries
  for each row execute function public.meal_plan_entries_b_check_list();

drop trigger if exists meal_plan_entries_b_touch on public.meal_plan_entries;
create trigger meal_plan_entries_b_touch
  before update on public.meal_plan_entries
  for each row execute function public.meal_plan_b_touch();

alter table public.meal_plan_entries enable row level security;
revoke all on table public.meal_plan_entries from anon, authenticated;
grant select, insert, update, delete on table public.meal_plan_entries to authenticated;

drop policy if exists "Own meal plan entries are readable" on public.meal_plan_entries;
create policy "Own meal plan entries are readable"
  on public.meal_plan_entries for select to authenticated
  using (user_id = (select auth.uid()));

drop policy if exists "Own meal plan entries can be added" on public.meal_plan_entries;
create policy "Own meal plan entries can be added"
  on public.meal_plan_entries for insert to authenticated
  with check (user_id = (select auth.uid()));

drop policy if exists "Own meal plan entries can be changed" on public.meal_plan_entries;
create policy "Own meal plan entries can be changed"
  on public.meal_plan_entries for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

drop policy if exists "Own meal plan entries can be removed" on public.meal_plan_entries;
create policy "Own meal plan entries can be removed"
  on public.meal_plan_entries for delete to authenticated
  using (user_id = (select auth.uid()));

-- ---------------------------------------------------------------- meal_plan_settings

create table if not exists public.meal_plan_settings (
  user_id uuid primary key default auth.uid() references public.users(id) on delete cascade,
  default_servings int not null default 2 check (default_servings between 1 and 20),
  target_list_id uuid references public.shopping_lists(id) on delete set null,
  pantry text[] not null default '{Salz,Pfeffer,Wasser,Öl,Zucker,Mehl}'
    check (cardinality(pantry) <= 200),
  show_today_hint boolean not null default true,
  reminder_enabled boolean not null default false,
  reminder_weekday int not null default 7 check (reminder_weekday between 1 and 7),
  reminder_time time not null default '18:00',
  updated_at timestamptz not null default now()
);

comment on table public.meal_plan_settings is
  'Wochenplan settings per account: default servings, default target list (null = list opened last), pantry ("Hast du meist da"), home hint, weekly reminder (ISO weekday, local time).';

create or replace function public.meal_plan_settings_b_check_list()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.target_list_id is not null
     and (tg_op = 'INSERT' or new.target_list_id is distinct from old.target_list_id)
     and not public.meal_plan_b_can_use_list(new.target_list_id) then
    raise exception 'target_list_id is not a list of this person'
      using errcode = 'insufficient_privilege';
  end if;
  return new;
end;
$$;

drop trigger if exists meal_plan_settings_b_check_list on public.meal_plan_settings;
create trigger meal_plan_settings_b_check_list
  before insert or update on public.meal_plan_settings
  for each row execute function public.meal_plan_settings_b_check_list();

drop trigger if exists meal_plan_settings_b_touch on public.meal_plan_settings;
create trigger meal_plan_settings_b_touch
  before update on public.meal_plan_settings
  for each row execute function public.meal_plan_b_touch();

alter table public.meal_plan_settings enable row level security;
revoke all on table public.meal_plan_settings from anon, authenticated;
grant select, insert, update, delete on table public.meal_plan_settings to authenticated;

drop policy if exists "Own meal plan settings are readable" on public.meal_plan_settings;
create policy "Own meal plan settings are readable"
  on public.meal_plan_settings for select to authenticated
  using (user_id = (select auth.uid()));

drop policy if exists "Own meal plan settings can be added" on public.meal_plan_settings;
create policy "Own meal plan settings can be added"
  on public.meal_plan_settings for insert to authenticated
  with check (user_id = (select auth.uid()));

drop policy if exists "Own meal plan settings can be changed" on public.meal_plan_settings;
create policy "Own meal plan settings can be changed"
  on public.meal_plan_settings for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

drop policy if exists "Own meal plan settings can be removed" on public.meal_plan_settings;
create policy "Own meal plan settings can be removed"
  on public.meal_plan_settings for delete to authenticated
  using (user_id = (select auth.uid()));
