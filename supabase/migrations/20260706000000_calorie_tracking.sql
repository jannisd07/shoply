-- Calorie tracking (Feature 6): nutrition goals, food/weight/water logs,
-- lightweight challenge tracking.
--
-- NOTE: Like the pricing/cost-splitting migration before it, this schema was
-- originally applied directly against the live Supabase project without a
-- tracked file. This file documents that already-applied schema for version
-- control; it is idempotent (IF NOT EXISTS / guarded) so it is safe to run
-- again.

-- One row per user: calorie/macro targets and the inputs used to calculate
-- them. calorie_tracking_enabled gates whether the feature is surfaced in
-- navbar/onboarding at all (mirrors the client-side SharedPreferences flag
-- used before an account existed / before this table was synced to).
create table if not exists public.nutrition_goals (
  user_id uuid primary key references public.users(id) on delete cascade,
  calorie_tracking_enabled boolean not null default false,
  goal_type text not null default 'maintain'
    check (goal_type in ('lose_weight', 'gain_muscle', 'maintain', 'custom')),
  activity_level text not null default 'moderate'
    check (activity_level in ('sedentary', 'light', 'moderate', 'active', 'very_active')),
  current_weight_kg double precision,
  target_weight_kg double precision,
  height_cm double precision,
  timeline_weeks integer,
  daily_calorie_target integer,
  protein_target_g integer,
  carbs_target_g integer,
  fat_target_g integer,
  water_target_ml integer default 2000,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.nutrition_goals is
  'One row per user: calorie/macro targets and the inputs used to calculate them. calorie_tracking_enabled gates whether the feature is surfaced in navbar/onboarding at all.';

alter table public.nutrition_goals enable row level security;

drop policy if exists "Users can view their own nutrition goals" on public.nutrition_goals;
create policy "Users can view their own nutrition goals"
  on public.nutrition_goals for select
  using (auth.uid() = user_id);

drop policy if exists "Users can insert their own nutrition goals" on public.nutrition_goals;
create policy "Users can insert their own nutrition goals"
  on public.nutrition_goals for insert
  with check (auth.uid() = user_id);

drop policy if exists "Users can update their own nutrition goals" on public.nutrition_goals;
create policy "Users can update their own nutrition goals"
  on public.nutrition_goals for update
  using (auth.uid() = user_id);

drop policy if exists "Users can delete their own nutrition goals" on public.nutrition_goals;
create policy "Users can delete their own nutrition goals"
  on public.nutrition_goals for delete
  using (auth.uid() = user_id);

-- A single logged food item for one meal on one day. source distinguishes
-- manual entry / logged-from-recipe / barcode lookup / AI photo analysis.
create table if not exists public.food_log_entries (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references public.users(id) on delete cascade,
  logged_date date not null default current_date,
  meal_type text not null default 'snack'
    check (meal_type in ('breakfast', 'lunch', 'dinner', 'snack')),
  source text not null default 'manual'
    check (source in ('manual', 'recipe', 'barcode', 'photo')),
  source_recipe_id uuid references public.recipes(id) on delete set null,
  food_name text not null,
  brand text,
  quantity double precision not null default 1,
  unit text,
  calories integer not null default 0,
  protein_g double precision,
  carbs_g double precision,
  fat_g double precision,
  barcode text,
  photo_url text,
  created_at timestamptz not null default now()
);

comment on table public.food_log_entries is
  'A single logged food item for one meal on one day. source distinguishes manual entry / logged-from-recipe / barcode lookup / AI photo analysis.';

create index if not exists food_log_entries_user_date_idx on public.food_log_entries(user_id, logged_date);

alter table public.food_log_entries enable row level security;

drop policy if exists "Users can view their own food log" on public.food_log_entries;
create policy "Users can view their own food log"
  on public.food_log_entries for select
  using (auth.uid() = user_id);

drop policy if exists "Users can insert their own food log" on public.food_log_entries;
create policy "Users can insert their own food log"
  on public.food_log_entries for insert
  with check (auth.uid() = user_id);

drop policy if exists "Users can update their own food log" on public.food_log_entries;
create policy "Users can update their own food log"
  on public.food_log_entries for update
  using (auth.uid() = user_id);

drop policy if exists "Users can delete their own food log" on public.food_log_entries;
create policy "Users can delete their own food log"
  on public.food_log_entries for delete
  using (auth.uid() = user_id);

-- One weigh-in per user per day (unique constraint) so re-logging the same
-- day overwrites via upsert.
create table if not exists public.weight_log (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references public.users(id) on delete cascade,
  logged_date date not null default current_date,
  weight_kg double precision not null,
  note text,
  created_at timestamptz not null default now(),
  unique (user_id, logged_date)
);

comment on table public.weight_log is
  'One weigh-in per user per day (unique constraint) so re-logging the same day overwrites via upsert.';

alter table public.weight_log enable row level security;

drop policy if exists "Users can view their own weight log" on public.weight_log;
create policy "Users can view their own weight log"
  on public.weight_log for select
  using (auth.uid() = user_id);

drop policy if exists "Users can insert their own weight log" on public.weight_log;
create policy "Users can insert their own weight log"
  on public.weight_log for insert
  with check (auth.uid() = user_id);

drop policy if exists "Users can update their own weight log" on public.weight_log;
create policy "Users can update their own weight log"
  on public.weight_log for update
  using (auth.uid() = user_id);

drop policy if exists "Users can delete their own weight log" on public.weight_log;
create policy "Users can delete their own weight log"
  on public.weight_log for delete
  using (auth.uid() = user_id);

-- Multiple entries per day (each logged glass/bottle); daily total is the
-- sum for that logged_date.
create table if not exists public.water_log (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references public.users(id) on delete cascade,
  logged_date date not null default current_date,
  amount_ml integer not null,
  created_at timestamptz not null default now()
);

comment on table public.water_log is
  'Multiple entries per day (each logged glass/bottle); daily total is the sum for that logged_date.';

create index if not exists water_log_user_date_idx on public.water_log(user_id, logged_date);

alter table public.water_log enable row level security;

drop policy if exists "Users can view their own water log" on public.water_log;
create policy "Users can view their own water log"
  on public.water_log for select
  using (auth.uid() = user_id);

drop policy if exists "Users can insert their own water log" on public.water_log;
create policy "Users can insert their own water log"
  on public.water_log for insert
  with check (auth.uid() = user_id);

drop policy if exists "Users can update their own water log" on public.water_log;
create policy "Users can update their own water log"
  on public.water_log for update
  using (auth.uid() = user_id);

drop policy if exists "Users can delete their own water log" on public.water_log;
create policy "Users can delete their own water log"
  on public.water_log for delete
  using (auth.uid() = user_id);

-- Lightweight challenge participation tracking (e.g. 16:8 fasting, 30-day no
-- sugar). One active row per challenge_type is expected but not enforced at
-- the DB level.
create table if not exists public.nutrition_challenges (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references public.users(id) on delete cascade,
  challenge_type text not null
    check (challenge_type in ('fasting_16_8', 'no_sugar_30', 'custom')),
  status text not null default 'active'
    check (status in ('active', 'completed', 'abandoned')),
  started_at timestamptz not null default now(),
  target_end_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz not null default now()
);

comment on table public.nutrition_challenges is
  'Lightweight challenge participation tracking (e.g. 16:8 fasting, 30-day no sugar). One active row per challenge_type is expected but not enforced at the DB level.';

create index if not exists nutrition_challenges_user_idx on public.nutrition_challenges(user_id, status);

alter table public.nutrition_challenges enable row level security;

drop policy if exists "Users can view their own challenges" on public.nutrition_challenges;
create policy "Users can view their own challenges"
  on public.nutrition_challenges for select
  using (auth.uid() = user_id);

drop policy if exists "Users can insert their own challenges" on public.nutrition_challenges;
create policy "Users can insert their own challenges"
  on public.nutrition_challenges for insert
  with check (auth.uid() = user_id);

drop policy if exists "Users can update their own challenges" on public.nutrition_challenges;
create policy "Users can update their own challenges"
  on public.nutrition_challenges for update
  using (auth.uid() = user_id);

drop policy if exists "Users can delete their own challenges" on public.nutrition_challenges;
create policy "Users can delete their own challenges"
  on public.nutrition_challenges for delete
  using (auth.uid() = user_id);
