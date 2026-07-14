-- Feature 6 (calorie tracking) follow-up: diet challenges + meal-photo storage.
--
-- Part 1 documents schema that was already applied live without a tracked
-- file (same pattern as the pricing/cost-splitting and calorie-tracking
-- migrations before it — see their header comments): `daily_checkins` and
-- the one-active-challenge-per-type unique index on `nutrition_challenges`
-- already exist in the live database (migration `20260710062531
-- challenge_daily_checkins`, verified via the Supabase MCP tools before
-- writing this file). It is idempotent so it is safe to run again.
--
-- Part 2 is new: a `meal-photos` storage bucket so photo-tracked meals in
-- the food log can keep their source photo instead of discarding it after
-- the one-shot Gemini vision estimate. Mirrors the existing
-- `profile-pictures` bucket's shape exactly (public read, write/delete
-- restricted to the uploader's own `{user_id}/...` folder) for consistency
-- with the rest of the app's storage buckets.

-- Part 1: diet challenges (already live, documented here for version control)
alter table public.nutrition_challenges
  add column if not exists daily_checkins jsonb not null default '{}'::jsonb;

comment on column public.nutrition_challenges.daily_checkins is
  'Daily self check-ins: {"yyyy-MM-dd": kept?}. Absent days are unmarked (shown as missed, never silently counted as success).';

create unique index if not exists nutrition_challenges_one_active_per_type
  on public.nutrition_challenges(user_id, challenge_type)
  where status = 'active';

-- Part 2: meal-photos storage bucket (new)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('meal-photos', 'meal-photos', true, 5242880,
  array['image/jpeg', 'image/png', 'image/webp', 'image/gif'])
on conflict (id) do nothing;

drop policy if exists "Meal photos are publicly accessible" on storage.objects;
create policy "Meal photos are publicly accessible"
  on storage.objects for select
  using (bucket_id = 'meal-photos');

drop policy if exists "Users can upload their own meal photos" on storage.objects;
create policy "Users can upload their own meal photos"
  on storage.objects for insert
  with check (bucket_id = 'meal-photos' and (storage.foldername(name))[1] = (auth.uid())::text);

drop policy if exists "Users can delete their own meal photos" on storage.objects;
create policy "Users can delete their own meal photos"
  on storage.objects for delete
  using (bucket_id = 'meal-photos' and (storage.foldername(name))[1] = (auth.uid())::text);
