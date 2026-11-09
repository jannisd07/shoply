-- A7 Onboarding: Entwurf, NICHT angewendet (Owner-Freigabe nötig; Spaltentypen gegen das Schema prüfen).
-- Konzept 17 §1.2 und §9.6. Stand 09.11.2026.

-- Migration: Flags nachtragen + Backfill (§9.6)
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS onboarding_completed boolean,
  ADD COLUMN IF NOT EXISTS tutorial_completed  boolean;
UPDATE public.users SET onboarding_completed = true
 WHERE onboarding_completed IS DISTINCT FROM true
   AND created_at < TIMESTAMPTZ '2026-11-09 00:00:00+00'; -- = Release-Tag = kOnboardingRedesignCutoff

-- RPC: Antworten von vor dem Konto in einer Transaktion
CREATE OR REPLACE FUNCTION public.apply_onboarding(answers jsonb)
RETURNS text LANGUAGE plpgsql SECURITY INVOKER SET search_path = public AS $$
DECLARE v_uid uuid := auth.uid(); v_done boolean; v_created timestamptz;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'not signed in' USING ERRCODE = '28000'; END IF;
  INSERT INTO users (id, email, auth_provider, created_at, updated_at)
    SELECT u.id, u.email, u.raw_app_meta_data->>'provider', now(), now()
      FROM auth.users u WHERE u.id = v_uid
  ON CONFLICT (id) DO NOTHING;
  SELECT onboarding_completed, created_at INTO v_done, v_created
    FROM users WHERE id = v_uid FOR UPDATE;
  IF v_done IS TRUE OR v_created < TIMESTAMPTZ '2026-11-09 00:00:00+00' THEN
    RETURN 'existing';
  END IF;
  IF answers ? 'modules' THEN
    INSERT INTO user_preferences (user_id, modules) VALUES (v_uid, answers->'modules')
    ON CONFLICT (user_id) DO UPDATE SET modules = EXCLUDED.modules;
  END IF;
  UPDATE users SET
    diet_preferences = COALESCE(answers->'diet_preferences', diet_preferences),
    allergies        = COALESCE(answers->'allergies', allergies),
    age    = COALESCE((answers#>>'{goal,age}')::int, age),
    height = COALESCE((answers#>>'{goal,height_cm}')::numeric, height),
    height_unit = CASE WHEN answers#>'{goal,height_cm}' IS NULL THEN height_unit ELSE 'cm' END,
    gender = COALESCE(answers#>>'{goal,gender}', gender),
    updated_at = now()
  WHERE id = v_uid;
  IF answers#>'{goal,current_weight_kg}' IS NOT NULL THEN
    INSERT INTO weight_logs (user_id, logged_date, weight_kg)
    VALUES (v_uid, (answers->>'local_date')::date, (answers#>>'{goal,current_weight_kg}')::numeric)
    ON CONFLICT (user_id, logged_date) DO UPDATE SET weight_kg = EXCLUDED.weight_kg;
  END IF;
  RETURN 'new';  -- setzt onboarding_completed bewusst NICHT (§1.2)
END $$;
REVOKE ALL ON FUNCTION public.apply_onboarding(jsonb) FROM public;
GRANT EXECUTE ON FUNCTION public.apply_onboarding(jsonb) TO authenticated;

-- Öffentliche Vorschau einer Einladung (§5.1); Rate-Limit über Edge Function oder Gateway
CREATE OR REPLACE FUNCTION public.invite_preview(p_code text)
RETURNS TABLE(list_name text, inviter_first_name text, open_items int)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT l.name, split_part(coalesce(u.display_name, ''), ' ', 1),
         (SELECT count(*) FROM shopping_items i WHERE i.list_id = l.id AND NOT i.is_checked)::int
    FROM shopping_lists l LEFT JOIN users u ON u.id = l.owner_id
   WHERE l.share_code = upper(p_code) LIMIT 1;
$$;
GRANT EXECUTE ON FUNCTION public.invite_preview(text) TO anon, authenticated;

-- Client: den Tag fürs Gewicht schickt die App (`local_date`), weil der Server in UTC rechnet.
-- Mit der RPC fallen `decideAccountStatus` und `kOnboardingRedesignCutoff` weg;
-- `OnboardingController.resolveAccount` ruft dann `apply_onboarding` auf.
