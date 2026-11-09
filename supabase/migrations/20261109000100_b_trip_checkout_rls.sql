-- Teil B, Paket B8 (verlauf-kosten.md §7, L8): tighter rights on the trip
-- tables. DRAFT for the owner. Apply only AFTER
--   1. 20261109000000_b_trip_checkout.sql is applied, and
--   2. a build with B8a (writes splits through save_trip_split) is the only
--      one in use (TestFlight testers updated; App Store phased release done).
-- Older builds insert/delete expense_splits directly and write
-- shopping_history columns freely; with this file applied their
-- "Kosten teilen" fails. The new build keeps working before and after.
--
-- Live state checked read-only on 2026-11-09: authenticated has full table
-- grants on shopping_history, shopping_history_items and expense_splits;
-- "Owner or list members can update history" lets the person who finished a
-- trip and every member update every column (list_id, undo_token, …).
--
-- Idempotent: safe to run more than once.

-- ------------------------------------------------------------------ expense_splits
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

-- ------------------------------------------------------------------ shopping_history
-- Clients may change only the amount and who paid (older code paths and
-- the fallback of ExpenseSplitService.createSplits). list_id, the undo
-- token and the trip's market are written by the server functions only, so
-- undo_shopping_trip can trust them.
revoke update on table public.shopping_history from anon, authenticated;
grant update (total_cost, paid_by_user_id, paid_by_name) on table public.shopping_history to authenticated;

-- ------------------------------------------------------------------ shopping_history_items
-- Clients insert snapshots only with the plain columns (fallback path of
-- older builds); restore_row/source_item_id come from complete_shopping_trip.
revoke insert, update on table public.shopping_history_items from anon, authenticated;
grant insert (history_id, name, quantity, unit, category, price, price_retailer, price_old_value)
  on table public.shopping_history_items to authenticated;
