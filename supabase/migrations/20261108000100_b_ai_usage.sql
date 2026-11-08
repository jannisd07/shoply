-- Teil B, Task B1.2: daily AI quota and token usage per person and task.
--
-- The edge function `ai` is the only writer. It calls three RPCs with the
-- service role:
--   ai_consume_quota_b(p_user, p_task, p_amount, p_limit) -> boolean
--     Counts p_amount more calls (categorize: items) for today if they fit
--     under p_limit. One INSERT ... ON CONFLICT DO UPDATE ... WHERE: under
--     concurrency Postgres locks the row and re-checks the WHERE on the latest
--     version, so two calls at the limit let at most one through.
--   ai_refund_quota_b(p_user, p_task, p_amount)
--     Gives back calls nobody billed (provider 4xx/5xx, no connection, a task
--     that stopped before calling Claude). Never below 0, today only.
--   ai_record_usage_b(p_user, p_task, p_in, p_out, p_cache)
--     Adds the token counts of a finished call. p_in includes cache writes
--     (the app's usage shape folds them into input_tokens), so cost estimates
--     from this table price cache writes like plain input (they cost 1.25x).
--
-- "Today" is the calendar day in Europe/Berlin; the function tells the app the
-- seconds until that midnight (retry_after_s).
--
-- People can read their own rows (for a future "used today" display) and
-- nothing else. Nobody can write through the API, and only service_role may
-- execute the RPCs; otherwise a signed-in user could reset their own quota.
--
-- Idempotent: safe to run more than once.
-- Test: supabase/tests/ai_quota_test.sql (against a local or branch database).

create table if not exists public.ai_usage_daily_b (
  user_id uuid not null references auth.users (id) on delete cascade,
  day date not null,
  task text not null,
  calls integer not null default 0 check (calls >= 0),
  input_tokens bigint not null default 0 check (input_tokens >= 0),
  output_tokens bigint not null default 0 check (output_tokens >= 0),
  cache_read_tokens bigint not null default 0 check (cache_read_tokens >= 0),
  primary key (user_id, day, task)
);

comment on table public.ai_usage_daily_b is
  'AI calls and tokens per person, Berlin day and task. Written only by the ai edge function through the ai_*_b RPCs.';

alter table public.ai_usage_daily_b enable row level security;

revoke all on table public.ai_usage_daily_b from anon, authenticated;
grant select on table public.ai_usage_daily_b to authenticated;

drop policy if exists "People read their own AI usage" on public.ai_usage_daily_b;
create policy "People read their own AI usage"
  on public.ai_usage_daily_b
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

create or replace function public.ai_consume_quota_b(
  p_user uuid,
  p_task text,
  p_amount integer,
  p_limit integer
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_ok boolean;
begin
  if p_user is null or p_task is null or p_amount is null or p_limit is null
     or p_amount <= 0 or p_amount > p_limit then
    return false;
  end if;

  insert into public.ai_usage_daily_b as u (user_id, day, task, calls)
  values (p_user, (now() at time zone 'Europe/Berlin')::date, p_task, p_amount)
  on conflict (user_id, day, task) do update
    set calls = u.calls + excluded.calls
    where u.calls + excluded.calls <= p_limit
  returning true into v_ok;

  return coalesce(v_ok, false);
end;
$$;

create or replace function public.ai_refund_quota_b(
  p_user uuid,
  p_task text,
  p_amount integer
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_user is null or p_task is null or p_amount is null or p_amount <= 0 then
    return;
  end if;

  update public.ai_usage_daily_b
  set calls = greatest(calls - p_amount, 0)
  where user_id = p_user
    and task = p_task
    and day = (now() at time zone 'Europe/Berlin')::date;
end;
$$;

create or replace function public.ai_record_usage_b(
  p_user uuid,
  p_task text,
  p_in bigint,
  p_out bigint,
  p_cache bigint
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_user is null or p_task is null then
    return;
  end if;

  insert into public.ai_usage_daily_b as u
    (user_id, day, task, calls, input_tokens, output_tokens, cache_read_tokens)
  values (
    p_user,
    (now() at time zone 'Europe/Berlin')::date,
    p_task,
    0,
    greatest(coalesce(p_in, 0), 0),
    greatest(coalesce(p_out, 0), 0),
    greatest(coalesce(p_cache, 0), 0)
  )
  on conflict (user_id, day, task) do update
    set input_tokens = u.input_tokens + excluded.input_tokens,
        output_tokens = u.output_tokens + excluded.output_tokens,
        cache_read_tokens = u.cache_read_tokens + excluded.cache_read_tokens;
end;
$$;

revoke execute on function public.ai_consume_quota_b(uuid, text, integer, integer) from public, anon, authenticated;
revoke execute on function public.ai_refund_quota_b(uuid, text, integer) from public, anon, authenticated;
revoke execute on function public.ai_record_usage_b(uuid, text, bigint, bigint, bigint) from public, anon, authenticated;

grant execute on function public.ai_consume_quota_b(uuid, text, integer, integer) to service_role;
grant execute on function public.ai_refund_quota_b(uuid, text, integer) to service_role;
grant execute on function public.ai_record_usage_b(uuid, text, bigint, bigint, bigint) to service_role;
