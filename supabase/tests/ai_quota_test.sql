-- Teil B, Task B1.2: the quota RPCs of migration 20261108000100_b_ai_usage.sql.
--
-- pgTAP. Runs only against a local or branch database (`supabase test db`),
-- never against production. Everything happens inside one transaction that is
-- rolled back at the end.
--
-- Concurrency (Review Focus 4: two calls at the limit let at most one through)
-- needs two sessions, which a pgTAP file cannot open. Manual check against a
-- branch database, with <uid> an existing auth.users id:
--   session A: begin;
--   session A: select public.ai_consume_quota_b('<uid>', 'concurrency', 1, 1);  -- true, keep A open
--   session B: select public.ai_consume_quota_b('<uid>', 'concurrency', 1, 1);  -- waits for A
--   session A: commit;
--   session B: returns false: ON CONFLICT re-checks the WHERE on the committed row (calls = 1)
-- Repeat with `rollback` instead of `commit` in session A: session B then returns true.
-- Clean up: delete from public.ai_usage_daily_b where task = 'concurrency';

begin;

create extension if not exists pgtap with schema extensions;

select plan(35);

insert into auth.users (id, email) values
  ('00000000-0000-4000-8000-0000000000a1', 'quota-a@example.test'),
  ('00000000-0000-4000-8000-0000000000b2', 'quota-b@example.test');

-- Consume -------------------------------------------------------------------

select is(public.ai_consume_quota_b('00000000-0000-4000-8000-0000000000a1', 'avo_chat', 1, 1), true,
  'the first call at limit 1 passes');
select is(public.ai_consume_quota_b('00000000-0000-4000-8000-0000000000a1', 'avo_chat', 1, 1), false,
  'the second call at limit 1 is denied');
select is(public.ai_consume_quota_b('00000000-0000-4000-8000-0000000000a1', 'meal_photo', 1, 1), true,
  'another task has its own count');
select is(public.ai_consume_quota_b('00000000-0000-4000-8000-0000000000b2', 'avo_chat', 1, 1), true,
  'another person has their own count');

select is(public.ai_consume_quota_b('00000000-0000-4000-8000-0000000000a1', 'categorize', 60, 200), true,
  'categorize counts its items');
select is(public.ai_consume_quota_b('00000000-0000-4000-8000-0000000000a1', 'categorize', 141, 200), false,
  'more items than are left are denied');
select is(
  (select calls from public.ai_usage_daily_b
   where user_id = '00000000-0000-4000-8000-0000000000a1' and task = 'categorize'),
  60, 'a denied call counts nothing');
select is(public.ai_consume_quota_b('00000000-0000-4000-8000-0000000000a1', 'categorize', 140, 200), true,
  'a call up to exactly the limit passes');
select is(public.ai_consume_quota_b('00000000-0000-4000-8000-0000000000a1', 'categorize', 1, 200), false,
  'nothing passes once the limit is reached');

select is(public.ai_consume_quota_b('00000000-0000-4000-8000-0000000000a1', 'recommend', 6, 5), false,
  'a first call above the limit is denied');
select is(
  (select count(*) from public.ai_usage_daily_b
   where user_id = '00000000-0000-4000-8000-0000000000a1' and task = 'recommend'),
  0::bigint, 'and leaves no row behind');
select is(public.ai_consume_quota_b('00000000-0000-4000-8000-0000000000a1', 'recommend', 0, 5), false,
  'an amount of 0 is denied');
select is(public.ai_consume_quota_b('00000000-0000-4000-8000-0000000000a1', 'recommend', -3, 5), false,
  'a negative amount is denied and cannot lower the count');
select is(public.ai_consume_quota_b('00000000-0000-4000-8000-0000000000a1', 'recommend', 1, 0), false,
  'a limit of 0 denies everything');
select is(public.ai_consume_quota_b(null, 'recommend', 1, 5), false,
  'a missing user is denied');

select is(
  (select day from public.ai_usage_daily_b
   where user_id = '00000000-0000-4000-8000-0000000000a1' and task = 'avo_chat'),
  (now() at time zone 'Europe/Berlin')::date, 'the day is the calendar day in Berlin');

-- Refund --------------------------------------------------------------------

select public.ai_refund_quota_b('00000000-0000-4000-8000-0000000000a1', 'avo_chat', 1);
select is(
  (select calls from public.ai_usage_daily_b
   where user_id = '00000000-0000-4000-8000-0000000000a1' and task = 'avo_chat'),
  0, 'a refund gives the call back');
select is(public.ai_consume_quota_b('00000000-0000-4000-8000-0000000000a1', 'avo_chat', 1, 1), true,
  'after a refund the call fits again');
select public.ai_refund_quota_b('00000000-0000-4000-8000-0000000000a1', 'avo_chat', 5);
select is(
  (select calls from public.ai_usage_daily_b
   where user_id = '00000000-0000-4000-8000-0000000000a1' and task = 'avo_chat'),
  0, 'a refund never goes below 0');
select public.ai_refund_quota_b('00000000-0000-4000-8000-0000000000a1', 'meal_photo', -4);
select is(
  (select calls from public.ai_usage_daily_b
   where user_id = '00000000-0000-4000-8000-0000000000a1' and task = 'meal_photo'),
  1, 'a negative refund changes nothing');
select public.ai_refund_quota_b('00000000-0000-4000-8000-0000000000a1', 'list_import', 1);
select is(
  (select count(*) from public.ai_usage_daily_b
   where user_id = '00000000-0000-4000-8000-0000000000a1' and task = 'list_import'),
  0::bigint, 'a refund without a row creates none');

-- Record --------------------------------------------------------------------

select public.ai_record_usage_b('00000000-0000-4000-8000-0000000000a1', 'categorize', 120, 30, 900);
select public.ai_record_usage_b('00000000-0000-4000-8000-0000000000a1', 'categorize', 10, 5, null);
select results_eq(
  $$select calls, input_tokens, output_tokens, cache_read_tokens from public.ai_usage_daily_b
    where user_id = '00000000-0000-4000-8000-0000000000a1' and task = 'categorize'$$,
  $$values (200, 130::bigint, 35::bigint, 900::bigint)$$,
  'recording adds tokens and leaves the call count alone');
select public.ai_record_usage_b('00000000-0000-4000-8000-0000000000a1', 'nutrition_estimate', -50, 4, 0);
select results_eq(
  $$select calls, input_tokens, output_tokens from public.ai_usage_daily_b
    where user_id = '00000000-0000-4000-8000-0000000000a1' and task = 'nutrition_estimate'$$,
  $$values (0, 0::bigint, 4::bigint)$$,
  'recording without a consumed call creates a row with 0 calls and no negative tokens');

-- Privileges ----------------------------------------------------------------

select ok(not has_function_privilege('anon', 'public.ai_consume_quota_b(uuid, text, integer, integer)', 'execute'),
  'anon cannot consume');
select ok(not has_function_privilege('authenticated', 'public.ai_consume_quota_b(uuid, text, integer, integer)', 'execute'),
  'signed-in users cannot consume directly');
select ok(not has_function_privilege('authenticated', 'public.ai_refund_quota_b(uuid, text, integer)', 'execute'),
  'signed-in users cannot refund their own quota');
select ok(not has_function_privilege('authenticated', 'public.ai_record_usage_b(uuid, text, bigint, bigint, bigint)', 'execute'),
  'signed-in users cannot record usage');
select ok(not has_function_privilege('anon', 'public.ai_refund_quota_b(uuid, text, integer)', 'execute'),
  'anon cannot refund');
select ok(has_function_privilege('service_role', 'public.ai_consume_quota_b(uuid, text, integer, integer)', 'execute'),
  'the service role can consume');
select ok(has_function_privilege('service_role', 'public.ai_record_usage_b(uuid, text, bigint, bigint, bigint)', 'execute'),
  'the service role can record');
select ok(not has_table_privilege('authenticated', 'public.ai_usage_daily_b', 'insert'),
  'signed-in users cannot insert rows');
select ok(not has_table_privilege('authenticated', 'public.ai_usage_daily_b', 'update'),
  'signed-in users cannot update rows');
select ok(not has_table_privilege('anon', 'public.ai_usage_daily_b', 'select'),
  'anon cannot read usage');

-- Row level security --------------------------------------------------------

select set_config('request.jwt.claims', '{"sub": "00000000-0000-4000-8000-0000000000b2", "role": "authenticated"}', true);
set local role authenticated;
select is((select count(*) from public.ai_usage_daily_b), 1::bigint,
  'a person sees their own rows');
select is(
  (select count(*) from public.ai_usage_daily_b where user_id = '00000000-0000-4000-8000-0000000000a1'),
  0::bigint, 'and none of anyone else');
reset role;

select * from finish();

rollback;
