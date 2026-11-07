-- Teil B, Task B2.3 (Kap. 12 "Markt pro Liste"): the market a list is for.
--
-- One row per list, written when a person picks the market in the StoreChip
-- (source 'user'). The other sources are reserved for detected markets
-- ('name' from the list name, 'learned' from completed trips, 'location'
-- from the nearby store); today the app only writes 'user' and computes the
-- rest on the device (ListStoreRepository, storeForListProvider).
--
-- chain_id is a StoreChainDirectory id (marktguru uniqueName, e.g. 'lidl',
-- 'aldi-sued'): lowercase letters, digits and dashes only, so no member can
-- store free text that other members' apps would pass on to offer queries
-- or Avo. A market of the person's own needs its own column later.
--
-- A row with source 'user' (the person picked the market) is never replaced
-- by a detected source; only a person changes or deletes it (Kap. 12, 3.1).
--
-- Everyone who can see the list (owner or member) can read and change its
-- market. updated_by and updated_at are set by a trigger, never by the
-- client.
--
-- Idempotent: safe to run more than once.

create table if not exists public.list_store_assignments_b (
  list_id uuid primary key references public.shopping_lists(id) on delete cascade,
  chain_id text not null check (chain_id ~ '^[a-z0-9-]{1,64}$'),
  source text not null check (source in ('user', 'name', 'learned', 'location')),
  updated_by uuid references auth.users(id) on delete set null default auth.uid(),
  updated_at timestamptz not null default now()
);

comment on table public.list_store_assignments_b is
  'Market (supermarket chain) per shopping list for the StoreChip, offers and the order in store. source: user (picked), name, learned, location (detected).';

alter table public.list_store_assignments_b enable row level security;

revoke all on table public.list_store_assignments_b from anon, authenticated;
grant select, insert, update, delete on table public.list_store_assignments_b to authenticated;

-- Owner or member of the list.
create or replace function public.list_store_b_can_access(target_list_id uuid)
returns boolean
language sql
stable
security invoker
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

revoke execute on function public.list_store_b_can_access(uuid) from public, anon;
grant execute on function public.list_store_b_can_access(uuid) to authenticated;

drop policy if exists "List owner or members can view the list market" on public.list_store_assignments_b;
create policy "List owner or members can view the list market"
  on public.list_store_assignments_b
  for select
  to authenticated
  using (public.list_store_b_can_access(list_id));

drop policy if exists "List owner or members can set the list market" on public.list_store_assignments_b;
create policy "List owner or members can set the list market"
  on public.list_store_assignments_b
  for insert
  to authenticated
  with check (public.list_store_b_can_access(list_id));

drop policy if exists "List owner or members can change the list market" on public.list_store_assignments_b;
create policy "List owner or members can change the list market"
  on public.list_store_assignments_b
  for update
  to authenticated
  using (public.list_store_b_can_access(list_id))
  with check (public.list_store_b_can_access(list_id));

drop policy if exists "List owner or members can remove the list market" on public.list_store_assignments_b;
create policy "List owner or members can remove the list market"
  on public.list_store_assignments_b
  for delete
  to authenticated
  using (public.list_store_b_can_access(list_id));

create or replace function public.list_store_assignments_b_stamp()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' and old.source = 'user' and new.source <> 'user' then
    raise exception 'A market picked by a person is not replaced by a detected one'
      using errcode = 'check_violation';
  end if;
  new.updated_by := auth.uid();
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists list_store_assignments_b_stamp on public.list_store_assignments_b;
create trigger list_store_assignments_b_stamp
  before insert or update on public.list_store_assignments_b
  for each row
  execute function public.list_store_assignments_b_stamp();
