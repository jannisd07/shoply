-- Teil B, Paket B8 (verlauf-kosten.md §7, L1, L2, L5, L6, L8): finishing a
-- shopping trip atomically, its undo, the trip's market and amount source,
-- and saving a cost split in one transaction.
--
-- DRAFT for the owner to apply (Supabase SQL editor). The app keeps working
-- before it is applied: ShoppingHistoryService and ExpenseSplitService fall
-- back to today's inserts when a function or column is missing.
--
-- Rules for every function below: SECURITY DEFINER only together with
-- `set search_path = ''` and fully qualified names; access is checked
-- against auth.uid() (owner or member of the list); EXECUTE is granted to
-- `authenticated` only.
--
-- Idempotent: safe to run more than once.

-- ------------------------------------------------------------------ L2
-- The trip's market as a StoreChainDirectory id (never an OSM display name),
-- where it came from, that the amount was typed by a person (Bug 7: never
-- from offer prices), who finished the trip, and the undo window.

alter table public.shopping_history
  add column if not exists store_chain text
    check (store_chain is null or store_chain ~ '^[a-z0-9-]{1,64}$'),
  add column if not exists store_source text
    check (store_source is null or store_source in ('list', 'learned', 'location', 'user')),
  add column if not exists total_cost_source text
    check (total_cost_source is null or total_cost_source in ('user')),
  add column if not exists completed_by uuid references auth.users(id) on delete set null,
  add column if not exists undo_token uuid,
  add column if not exists undo_expires_at timestamptz;

comment on column public.shopping_history.store_chain is
  'StoreChainDirectory id of the market of this trip (lidl, rewe, aldi-sued); null without one.';
comment on column public.shopping_history.total_cost_source is
  'user: the amount was typed by a person. Null rows without an amount.';

-- The full shopping_items row of every snapshot, so undo_shopping_trip can
-- put the item back exactly (id, category, notes, price, order).
alter table public.shopping_history_items
  add column if not exists source_item_id uuid,
  add column if not exists restore_row jsonb;

create index if not exists shopping_history_list_completed_idx
  on public.shopping_history (list_id, completed_at desc);
create index if not exists shopping_history_user_completed_idx
  on public.shopping_history (user_id, completed_at desc);

-- ------------------------------------------------------------------ L5
-- How the split was made and the order of "Wer teilt?" (the rest cent of an
-- equal split goes to position 0), plus who wrote the row (undo refuses
-- when another member split the trip meanwhile).

alter table public.expense_splits
  add column if not exists split_mode text not null default 'custom'
    check (split_mode in ('equal', 'custom')),
  add column if not exists position integer not null default 0,
  add column if not exists created_by uuid references auth.users(id) on delete set null
    default auth.uid();

create index if not exists expense_splits_open_idx
  on public.expense_splits (user_id) where not is_paid;

-- ------------------------------------------------------------------ helpers

-- Owner or member of the list (same rule as list_store_b_can_access).
create or replace function public.trip_b_can_access_list(target_list_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select target_list_id is not null and (
    exists (
      select 1 from public.shopping_lists sl
      where sl.id = target_list_id and sl.owner_id = (select auth.uid())
    )
    or exists (
      select 1 from public.list_members lm
      where lm.list_id = target_list_id and lm.user_id = (select auth.uid())
    )
  );
$$;

revoke execute on function public.trip_b_can_access_list(uuid) from public, anon;
grant execute on function public.trip_b_can_access_list(uuid) to authenticated;

-- The person who finished the trip, or a member of its list.
create or replace function public.trip_b_can_access_trip(target_trip_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.shopping_history sh
    where sh.id = target_trip_id
      and (sh.user_id = (select auth.uid())
           or public.trip_b_can_access_list(sh.list_id))
  );
$$;

revoke execute on function public.trip_b_can_access_trip(uuid) from public, anon;
grant execute on function public.trip_b_can_access_trip(uuid) to authenticated;

-- Equal shares in cents for [n] people: whole cents, the rest cents go to
-- the first positions (10,00 € / 3 = 3,34 + 3,33 + 3,33). Same rule as
-- `equalShareCents` in lib/data/services/trip_split_math.dart.
create or replace function public.trip_b_equal_share(total numeric, n integer, pos integer)
returns numeric
language sql
immutable
set search_path = ''
as $$
  select case when n <= 0 then 0::numeric else
    ((floor(round(total * 100) / n)
      + case when pos < (round(total * 100)::bigint % n) then 1 else 0 end) / 100.0)::numeric
  end;
$$;

revoke execute on function public.trip_b_equal_share(numeric, integer, integer) from public, anon;
grant execute on function public.trip_b_equal_share(numeric, integer, integer) to authenticated;

-- ------------------------------------------------------------------ L1
-- Finishes a trip in one transaction: snapshots the checked items that still
-- exist, removes them from the list, writes the trip. Returns jsonb:
--   {status: 'saved', trip_id, undo_token, total_items, completed_at, completed_by_name}
--   {status: 'already_completed', trip_id, completed_by_name}  (a member was faster)
--   {status: 'list_gone'} | {status: 'nothing_checked'}
-- p_total_cost is only what the person typed (null: no amount).

create or replace function public.complete_shopping_trip(
  p_list_id uuid,
  p_checked_item_ids uuid[],
  p_chain_id text default null,
  p_store_source text default null,
  p_total_cost numeric default null,
  p_split_planned boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := (select auth.uid());
  v_list_name text;
  v_name text;
  v_trip uuid;
  v_token uuid := gen_random_uuid();
  v_now timestamptz := now();
  v_count integer;
  v_other record;
begin
  if v_user is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;
  if p_total_cost is not null and (p_total_cost < 0 or p_total_cost > 100000) then
    raise exception 'invalid amount' using errcode = '22023';
  end if;
  if p_chain_id is not null and p_chain_id !~ '^[a-z0-9-]{1,64}$' then
    raise exception 'invalid chain' using errcode = '22023';
  end if;

  select sl.name into v_list_name from public.shopping_lists sl where sl.id = p_list_id;
  if v_list_name is null then
    return jsonb_build_object('status', 'list_gone');
  end if;
  if not public.trip_b_can_access_list(p_list_id) then
    raise exception 'not a member' using errcode = '42501';
  end if;

  -- Serialise checkouts of the same list: the second one sees the first.
  perform pg_advisory_xact_lock(hashtext('trip_b:' || p_list_id::text));

  select count(*) into v_count
  from public.shopping_items si
  where si.list_id = p_list_id and si.id = any(p_checked_item_ids);

  if v_count = 0 then
    select sh.id, sh.completed_by_name into v_other
    from public.shopping_history sh
    where sh.list_id = p_list_id
      and sh.user_id <> v_user
      and sh.completed_at > v_now - interval '10 minutes'
    order by sh.completed_at desc
    limit 1;
    if v_other.id is not null then
      return jsonb_build_object(
        'status', 'already_completed',
        'trip_id', v_other.id,
        'completed_by_name', v_other.completed_by_name
      );
    end if;
    return jsonb_build_object('status', 'nothing_checked');
  end if;

  select u.display_name into v_name from public.users u where u.id = v_user;

  insert into public.shopping_history (
    user_id, list_id, list_name, total_items, completed_at, completed_by_name,
    completed_by, total_cost, total_cost_source, store_chain, store_source,
    undo_token, undo_expires_at
  ) values (
    v_user, p_list_id, v_list_name, v_count, v_now, v_name,
    v_user, p_total_cost, case when p_total_cost is null then null else 'user' end,
    p_chain_id, case when p_chain_id is null then null else p_store_source end,
    v_token, v_now + interval '15 minutes'
  )
  returning id into v_trip;

  insert into public.shopping_history_items (
    history_id, name, quantity, unit, category, price, price_retailer,
    price_old_value, source_item_id, restore_row
  )
  select v_trip, si.name, si.quantity, si.unit, coalesce(si.category_id, si.category),
         si.price, si.price_retailer, si.price_old_value, si.id, to_jsonb(si)
  from public.shopping_items si
  where si.list_id = p_list_id and si.id = any(p_checked_item_ids);

  delete from public.shopping_items si
  where si.list_id = p_list_id and si.id = any(p_checked_item_ids);

  update public.shopping_lists set updated_at = now() where id = p_list_id;

  return jsonb_build_object(
    'status', 'saved',
    'trip_id', v_trip,
    'undo_token', v_token,
    'total_items', v_count,
    'completed_at', v_now,
    'completed_by_name', v_name,
    'split_planned', p_split_planned
  );
end;
$$;

revoke execute on function public.complete_shopping_trip(uuid, uuid[], text, text, numeric, boolean) from public, anon;
grant execute on function public.complete_shopping_trip(uuid, uuid[], text, text, numeric, boolean) to authenticated;

-- Takes a trip back inside its undo window: puts the items back on the list
-- as checked (same ids), deletes splits written by the same person and the
-- trip. Returns jsonb {status: 'undone' | 'expired' | 'split_by_other' |
-- 'not_found'}.
create or replace function public.undo_shopping_trip(p_trip_id uuid, p_token uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := (select auth.uid());
  v_trip record;
begin
  if v_user is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;

  select sh.* into v_trip from public.shopping_history sh
  where sh.id = p_trip_id
  for update;
  if v_trip.id is null or v_trip.user_id <> v_user then
    return jsonb_build_object('status', 'not_found');
  end if;
  if v_trip.undo_token is null or v_trip.undo_token <> p_token
     or v_trip.undo_expires_at < now() then
    return jsonb_build_object('status', 'expired');
  end if;
  if exists (
    select 1 from public.expense_splits es
    where es.history_id = p_trip_id
      and es.created_by is distinct from v_user
  ) then
    return jsonb_build_object('status', 'split_by_other');
  end if;

  if v_trip.list_id is not null
     and exists (select 1 from public.shopping_lists sl where sl.id = v_trip.list_id) then
    insert into public.shopping_items
    select (jsonb_populate_record(
              null::public.shopping_items,
              hi.restore_row
                || jsonb_build_object('is_checked', true, 'list_id', v_trip.list_id)
            )).*
    from public.shopping_history_items hi
    where hi.history_id = p_trip_id and hi.restore_row is not null
    on conflict (id) do nothing;
  end if;

  delete from public.expense_splits where history_id = p_trip_id;
  delete from public.shopping_history_items where history_id = p_trip_id;
  delete from public.shopping_history where id = p_trip_id;
  return jsonb_build_object('status', 'undone');
end;
$$;

revoke execute on function public.undo_shopping_trip(uuid, uuid) from public, anon;
grant execute on function public.undo_shopping_trip(uuid, uuid) to authenticated;

-- ------------------------------------------------------------------ L5
-- Saves the split of a trip: replaces the shares instead of insert-then-
-- delete. A share whose person and amount stay the same keeps its paid
-- state; a changed amount is open again (the payer's own share is always
-- paid). Also writes total_cost and who paid. p_shares is a jsonb array of
-- {user_id, participant_name, amount} in "Wer teilt?" order.
create or replace function public.save_trip_split(
  p_trip_id uuid,
  p_total_cost numeric,
  p_paid_by_user_id uuid,
  p_paid_by_name text,
  p_split_mode text,
  p_shares jsonb
)
returns setof public.expense_splits
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := (select auth.uid());
  v_payer uuid;
  v_share jsonb;
  v_pos integer := 0;
  v_keep uuid[] := '{}';
  v_existing record;
  v_amount numeric;
  v_uid uuid;
  v_name text;
  v_is_payer boolean;
  v_id uuid;
begin
  if v_user is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;
  if not public.trip_b_can_access_trip(p_trip_id) then
    raise exception 'not a member' using errcode = '42501';
  end if;
  if p_split_mode not in ('equal', 'custom') then
    raise exception 'invalid mode' using errcode = '22023';
  end if;
  if p_total_cost is null or p_total_cost < 0 or p_total_cost > 100000 then
    raise exception 'invalid amount' using errcode = '22023';
  end if;
  if jsonb_typeof(p_shares) <> 'array' or jsonb_array_length(p_shares) > 50 then
    raise exception 'invalid shares' using errcode = '22023';
  end if;
  if (select coalesce(sum((s->>'amount')::numeric), 0) from jsonb_array_elements(p_shares) s)
     <> p_total_cost then
    raise exception 'shares do not add up' using errcode = '22023';
  end if;

  v_payer := case when p_paid_by_user_id is null and p_paid_by_name is null
                  then v_user else p_paid_by_user_id end;

  update public.shopping_history
  set total_cost = p_total_cost,
      total_cost_source = 'user',
      paid_by_user_id = v_payer,
      paid_by_name = p_paid_by_name
  where id = p_trip_id;

  for v_share in select * from jsonb_array_elements(p_shares) loop
    v_uid := nullif(v_share->>'user_id', '')::uuid;
    v_name := left(coalesce(v_share->>'participant_name', ''), 80);
    v_amount := (v_share->>'amount')::numeric;
    if v_amount < 0 then
      raise exception 'invalid share' using errcode = '22023';
    end if;
    v_is_payer := case when v_uid is not null then v_uid = v_payer
                       else v_payer is null and v_name = p_paid_by_name end;

    select es.* into v_existing from public.expense_splits es
    where es.history_id = p_trip_id
      and ((v_uid is not null and es.user_id = v_uid)
           or (v_uid is null and es.user_id is null and es.participant_name = v_name))
      and not (es.id = any(v_keep))
    limit 1;

    if v_existing.id is not null then
      update public.expense_splits es
      set amount = v_amount,
          participant_name = v_name,
          position = v_pos,
          split_mode = p_split_mode,
          is_paid = case when v_is_payer then true
                         when es.amount = v_amount then es.is_paid
                         else false end,
          paid_at = case when v_is_payer then coalesce(es.paid_at, now())
                         when es.amount = v_amount then es.paid_at
                         else null end
      where es.id = v_existing.id;
      v_keep := v_keep || v_existing.id;
    else
      insert into public.expense_splits (
        history_id, user_id, participant_name, amount, is_paid, paid_at,
        split_mode, position, created_by
      ) values (
        p_trip_id, v_uid, v_name, v_amount, v_is_payer,
        case when v_is_payer then now() else null end,
        p_split_mode, v_pos, v_user
      )
      returning id into v_id;
      v_keep := v_keep || v_id;
    end if;
    v_existing := null;
    v_pos := v_pos + 1;
  end loop;

  delete from public.expense_splits es
  where es.history_id = p_trip_id and not (es.id = any(v_keep));

  return query
    select * from public.expense_splits es
    where es.history_id = p_trip_id
    order by es.position;
end;
$$;

revoke execute on function public.save_trip_split(uuid, numeric, uuid, text, text, jsonb) from public, anon;
grant execute on function public.save_trip_split(uuid, numeric, uuid, text, text, jsonb) to authenticated;

-- ------------------------------------------------------------------ L6
-- Changes the amount of a trip (V6). An equal split is recomputed in the
-- same transaction (rest cents by position, paid state kept where the share
-- did not change); a custom split is left alone and the app asks.
create or replace function public.set_trip_amount(p_trip_id uuid, p_total_cost numeric)
returns setof public.expense_splits
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_n integer;
  v_payer uuid;
  v_payer_name text;
begin
  if (select auth.uid()) is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;
  if not public.trip_b_can_access_trip(p_trip_id) then
    raise exception 'not a member' using errcode = '42501';
  end if;
  if p_total_cost is not null and (p_total_cost < 0 or p_total_cost > 100000) then
    raise exception 'invalid amount' using errcode = '22023';
  end if;

  update public.shopping_history
  set total_cost = p_total_cost,
      total_cost_source = case when p_total_cost is null then null else 'user' end
  where id = p_trip_id
  returning paid_by_user_id, paid_by_name into v_payer, v_payer_name;

  select count(*) into v_n from public.expense_splits
  where history_id = p_trip_id and split_mode = 'equal';

  if p_total_cost is not null and v_n > 0 then
    with ranked as (
      select es.id, es.amount as old_amount, es.user_id, es.participant_name,
             (row_number() over (order by es.position, es.created_at) - 1)::integer as pos
      from public.expense_splits es
      where es.history_id = p_trip_id
    ), shares as (
      select r.*, public.trip_b_equal_share(p_total_cost, v_n, r.pos) as new_amount,
             case when r.user_id is not null then r.user_id = v_payer
                  else v_payer is null and r.participant_name = v_payer_name end as is_payer
      from ranked r
    )
    update public.expense_splits es
    set amount = s.new_amount,
        position = s.pos,
        is_paid = case when s.is_payer then true
                       when s.new_amount = s.old_amount then es.is_paid
                       else false end,
        paid_at = case when s.is_payer then coalesce(es.paid_at, now())
                       when s.new_amount = s.old_amount then es.paid_at
                       else null end
    from shares s
    where es.id = s.id;
  end if;

  return query
    select * from public.expense_splits es
    where es.history_id = p_trip_id
    order by es.position;
end;
$$;

revoke execute on function public.set_trip_amount(uuid, numeric) from public, anon;
grant execute on function public.set_trip_amount(uuid, numeric) to authenticated;

-- ------------------------------------------------------------------ L8
-- expense_splits: rows are written only through save_trip_split /
-- set_trip_amount / undo_shopping_trip (SECURITY DEFINER). People change
-- only the paid state, and only the participant, the payer or the person
-- who finished the trip. Reading stays: participant, trip owner, members.

drop policy if exists "Trip owner or list members can insert splits" on public.expense_splits;
drop policy if exists "Trip owner or list members can delete splits" on public.expense_splits;
drop policy if exists "Trip owner, list members or the participant can update splits" on public.expense_splits;
drop policy if exists "Participant, payer or trip owner can mark splits paid" on public.expense_splits;

create policy "Participant, payer or trip owner can mark splits paid"
  on public.expense_splits
  for update
  to authenticated
  using (
    (select auth.uid()) = user_id
    or exists (
      select 1 from public.shopping_history sh
      where sh.id = expense_splits.history_id
        and ((select auth.uid()) = sh.user_id or (select auth.uid()) = sh.paid_by_user_id)
    )
  )
  with check (
    (select auth.uid()) = user_id
    or exists (
      select 1 from public.shopping_history sh
      where sh.id = expense_splits.history_id
        and ((select auth.uid()) = sh.user_id or (select auth.uid()) = sh.paid_by_user_id)
    )
  );

revoke insert, delete, update on table public.expense_splits from anon, authenticated;
grant select on table public.expense_splits to authenticated;
grant update (is_paid, paid_at) on table public.expense_splits to authenticated;

-- Open shares that involve the caller ("Offene Beträge", V8): unpaid shares
-- the caller owes on trips someone else paid, unpaid shares others owe on
-- trips the caller paid (the payer's own share left out), plus the ones
-- settled in the last 30 days. Runs with the caller's rights (RLS).
create or replace function public.open_split_shares()
returns table (
  split_id uuid,
  history_id uuid,
  user_id uuid,
  participant_name text,
  amount numeric,
  is_paid boolean,
  paid_at timestamptz,
  split_position integer,
  list_id uuid,
  list_name text,
  completed_at timestamptz,
  total_cost numeric,
  paid_by_user_id uuid,
  paid_by_name text,
  store_chain text
)
language sql
stable
security invoker
set search_path = ''
as $$
  select es.id, es.history_id, es.user_id, es.participant_name, es.amount,
         es.is_paid, es.paid_at, es.position, sh.list_id, sh.list_name,
         sh.completed_at, sh.total_cost, sh.paid_by_user_id, sh.paid_by_name,
         sh.store_chain
  from public.expense_splits es
  join public.shopping_history sh on sh.id = es.history_id
  where (not es.is_paid or es.paid_at > now() - interval '30 days')
    and (
      (es.user_id = (select auth.uid()) and sh.paid_by_user_id is distinct from (select auth.uid()))
      or (sh.paid_by_user_id = (select auth.uid()) and es.user_id is distinct from (select auth.uid()))
    )
  order by sh.completed_at desc, es.position;
$$;

revoke execute on function public.open_split_shares() from public, anon;
grant execute on function public.open_split_shares() to authenticated;

-- ------------------------------------------------------------------ RLS notes
-- shopping_history (unchanged, documented for Bug 4): only the person who
-- finished a trip may delete it ("Users can delete own history"); a member
-- deleting someone else's trip matches no row and the delete returns
-- without error. The app therefore offers "Einkauf löschen" only on own
-- trips and checks the affected row count.
