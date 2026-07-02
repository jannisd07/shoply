-- Pricing (shopping_items, shopping_history_items) and trip cost-splitting
-- (expense_splits) support.
--
-- NOTE: This migration was originally applied directly against the live
-- Supabase project (2026-07-02) without a tracked file. This file documents
-- that already-applied schema for version control; it is idempotent
-- (IF NOT EXISTS / guarded) so it is safe to run again.

-- Per-item price snapshot, captured when a user picks a live offer.
alter table public.shopping_items
  add column if not exists price numeric,
  add column if not exists price_currency text default 'EUR',
  add column if not exists price_retailer text,
  add column if not exists price_unit text,
  add column if not exists price_updated_at timestamptz;

-- Trip-level cost, carried over from checkout for the cost-split feature.
alter table public.shopping_history
  add column if not exists total_cost numeric,
  add column if not exists paid_by_user_id uuid references auth.users(id) on delete set null,
  add column if not exists paid_by_name text;

-- Price snapshot carried into history when a trip is completed.
alter table public.shopping_history_items
  add column if not exists price numeric,
  add column if not exists price_retailer text;

-- Per-person share of a completed trip's cost, with paid/unpaid tracking.
create table if not exists public.expense_splits (
  id uuid primary key default gen_random_uuid(),
  history_id uuid not null references public.shopping_history(id) on delete cascade,
  user_id uuid references auth.users(id) on delete set null,
  participant_name text not null,
  amount numeric not null,
  is_paid boolean not null default false,
  paid_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.expense_splits is
  'Per-person shares of a completed shopping trip cost (shopping_history), with paid/unpaid tracking, for the trip cost-splitting feature.';

create index if not exists expense_splits_history_id_idx on public.expense_splits(history_id);
create index if not exists expense_splits_user_id_idx on public.expense_splits(user_id);

alter table public.expense_splits enable row level security;

drop policy if exists "Trip owner or list members can view splits" on public.expense_splits;
drop policy if exists "Trip owner, list members or the participant can view splits" on public.expense_splits;
create policy "Trip owner, list members or the participant can view splits"
  on public.expense_splits for select
  using (
    auth.uid() = (select user_id from public.shopping_history where id = expense_splits.history_id)
    or auth.uid() in (
      select lm.user_id from public.list_members lm
      join public.shopping_history sh on sh.list_id = lm.list_id
      where sh.id = expense_splits.history_id
    )
    or auth.uid() = expense_splits.user_id
  );

drop policy if exists "Trip owner or list members can insert splits" on public.expense_splits;
create policy "Trip owner or list members can insert splits"
  on public.expense_splits for insert
  with check (
    auth.uid() = (select user_id from public.shopping_history where id = expense_splits.history_id)
    or auth.uid() in (
      select lm.user_id from public.list_members lm
      join public.shopping_history sh on sh.list_id = lm.list_id
      where sh.id = expense_splits.history_id
    )
  );

drop policy if exists "Trip owner, list members or the participant can update splits" on public.expense_splits;
create policy "Trip owner, list members or the participant can update splits"
  on public.expense_splits for update
  using (
    auth.uid() = expense_splits.user_id
    or auth.uid() = (select user_id from public.shopping_history where id = expense_splits.history_id)
    or auth.uid() in (
      select lm.user_id from public.list_members lm
      join public.shopping_history sh on sh.list_id = lm.list_id
      where sh.id = expense_splits.history_id
    )
  );

drop policy if exists "Trip owner or list members can delete splits" on public.expense_splits;
create policy "Trip owner or list members can delete splits"
  on public.expense_splits for delete
  using (
    auth.uid() = (select user_id from public.shopping_history where id = expense_splits.history_id)
    or auth.uid() in (
      select lm.user_id from public.list_members lm
      join public.shopping_history sh on sh.list_id = lm.list_id
      where sh.id = expense_splits.history_id
    )
  );
