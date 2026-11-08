-- Teil B: stop-gap for the subscription RPCs the Supabase advisor flagged
-- (security definer, callable by `anon`). Applied 2026-11-08 after the
-- owner's yes.
--
-- Why now: since S3 the AI quota (`ai_consume_quota_b`) gives Pro limits to
-- everyone `is_premium_user` says yes to. `activate_subscription(user_uuid,
-- ...)` checked neither the caller nor a receipt, so anybody with the public
-- anon key could set any account to Pro and spend AI money.
--
-- What changes:
--   activate_subscription  only for the signed-in person's own id (or the
--                          service role); anon can no longer call it.
--                          Still no receipt check: a signed-in person can
--                          grant themselves Pro until the server-side receipt
--                          validation exists (OPEN-ISSUES, section 2).
--   activate_trial         same rule; still once per account.
--   expire_subscriptions   service role only (the daily edge function).
--   get_recommended_items  unused by the app; read any person's purchase
--                          stats by id. Service role only.
--   is_premium_user        no longer for anon (the app and the `ai` function
--                          call it signed in).
--   is_list_member stays as it is: the shopping_items and list_members
--   policies apply to `public`, so revoking anon would turn an empty answer
--   into a permission error.
--
-- The function bodies are unchanged apart from the caller check.
-- Idempotent: safe to run more than once.

create or replace function public.activate_subscription(
  user_uuid uuid,
  tier text,
  transaction_id_param text,
  platform_param text,
  expiry_date_param timestamp with time zone
)
returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  if coalesce((select auth.role()), '') <> 'service_role'
     and user_uuid is distinct from (select auth.uid()) then
    raise exception 'only your own subscription can be activated'
      using errcode = 'insufficient_privilege';
  end if;

  update users
  set
    subscription_tier = tier,
    subscription_status = 'active',
    subscription_expires_at = expiry_date_param,
    subscription_started_at = coalesce(subscription_started_at, now()),
    last_payment_date = now()
  where id = user_uuid;

  insert into subscription_transactions (
    user_id,
    transaction_id,
    product_id,
    platform,
    purchase_date,
    expiry_date,
    is_trial
  ) values (
    user_uuid,
    transaction_id_param,
    tier,
    platform_param,
    now(),
    expiry_date_param,
    false
  );
end;
$function$;

create or replace function public.activate_trial(user_uuid uuid)
returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  if coalesce((select auth.role()), '') <> 'service_role'
     and user_uuid is distinct from (select auth.uid()) then
    raise exception 'only your own trial can be activated'
      using errcode = 'insufficient_privilege';
  end if;

  update users
  set
    subscription_status = 'trial',
    trial_ends_at = now() + interval '14 days',
    subscription_expires_at = now() + interval '14 days',
    subscription_started_at = now()
  where id = user_uuid
    and subscription_status = 'inactive'
    and trial_ends_at is null; -- only once per account
end;
$function$;

revoke execute on function public.activate_subscription(uuid, text, text, text, timestamp with time zone)
  from public, anon;
grant execute on function public.activate_subscription(uuid, text, text, text, timestamp with time zone)
  to authenticated, service_role;

revoke execute on function public.activate_trial(uuid) from public, anon;
grant execute on function public.activate_trial(uuid) to authenticated, service_role;

revoke execute on function public.expire_subscriptions() from public, anon, authenticated;
grant execute on function public.expire_subscriptions() to service_role;

revoke execute on function public.get_recommended_items(uuid, integer) from public, anon, authenticated;
grant execute on function public.get_recommended_items(uuid, integer) to service_role;

revoke execute on function public.is_premium_user(uuid) from public, anon;
grant execute on function public.is_premium_user(uuid) to authenticated, service_role;
