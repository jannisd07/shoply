-- Teil B, Task B1.7: the `meal-photos` bucket becomes private.
--
-- Migration 20260714000000_diet_challenges_and_meal_photos.sql created the
-- bucket as public with a select policy for everyone, so anybody with a link
-- (or a guessed user id and timestamp) could see a person's meal photos.
-- From now on only the owner reads them; the app shows them through signed
-- URLs (concept 15, 3.6, inventory 4.17).
--
-- Paths stay `<uid>/<file>`; every policy checks that the first folder is the
-- caller's own id. Insert, update (for `upsert: true` uploads) and delete stay
-- owner-only and are now limited to signed-in users. The edge functions use
-- the service role, which bypasses these policies.
--
-- Consequence for old app builds: they store `getPublicUrl` links in
-- `food_log_entries.photo_url`. Those links stop working once this runs (the
-- photo is still in the bucket, the row keeps its link). New builds keep the
-- path in `food_log_entries.photo_path` (migration
-- 20261108001000_b_calories.sql), can derive it from an old link
-- (`.../object/public/meal-photos/<path>`), and ask for a signed URL.
--
-- Idempotent: safe to run more than once.

-- 1. Private bucket (created here if the old migration never ran) ----------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('meal-photos', 'meal-photos', false, 5242880,
  array['image/jpeg', 'image/png', 'image/webp', 'image/gif'])
on conflict (id) do update set public = false;

-- 2. Owner-only policies on the objects ------------------------------------
drop policy if exists "Meal photos are publicly accessible" on storage.objects;
drop policy if exists "Users can upload their own meal photos" on storage.objects;
drop policy if exists "Users can delete their own meal photos" on storage.objects;

drop policy if exists "meal_photos_select_own" on storage.objects;
create policy "meal_photos_select_own" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'meal-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "meal_photos_insert_own" on storage.objects;
create policy "meal_photos_insert_own" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'meal-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "meal_photos_update_own" on storage.objects;
create policy "meal_photos_update_own" on storage.objects
  for update to authenticated
  using (
    bucket_id = 'meal-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  )
  with check (
    bucket_id = 'meal-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "meal_photos_delete_own" on storage.objects;
create policy "meal_photos_delete_own" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'meal-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );
