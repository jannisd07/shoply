-- A8 Profil und Einstellungen: Entwurf, NICHT angewendet (Owner-Freigabe nötig; gegen das Schema prüfen).
-- Konzept 18 E18-09, E18-13, K18-06, K18-07. Stand 09.11.2026.

-- Mitteilungs-Kategorien und Uhrzeiten im Konto (K18-06); heute nur auf dem Gerät.
CREATE TABLE IF NOT EXISTS public.user_notification_prefs (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  categories jsonb NOT NULL DEFAULT '{}'::jsonb,  -- {"shopping_started":true,"dinner_ideas":false,…}
  times jsonb NOT NULL DEFAULT '{}'::jsonb,       -- {"restock":"9:00","dinner_ideas":"18:00"}
  updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.user_notification_prefs ENABLE ROW LEVEL SECURITY;
CREATE POLICY own_notification_prefs ON public.user_notification_prefs
  FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
-- send-push-notification (B) prüft die Kategorie vor dem Senden.

-- "Anderen zeigen, dass ich einkaufe" (K18-07) und "Rezepte automatisch anpassen".
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS share_presence boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS auto_adapt_recipes boolean NOT NULL DEFAULT true;

-- Passwort-Stand für die Zeile "Passwort" im Konto.
CREATE OR REPLACE FUNCTION public.account_has_password() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT coalesce(encrypted_password <> '', false) FROM auth.users WHERE id = auth.uid();
$$;
GRANT EXECUTE ON FUNCTION public.account_has_password() TO authenticated;

-- users.email mitführen, wenn sich die Adresse in auth.users ändert.
CREATE OR REPLACE FUNCTION public.sync_user_email() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  UPDATE public.users SET email = NEW.email, updated_at = now() WHERE id = NEW.id;
  RETURN NEW;
END $$;
CREATE TRIGGER on_auth_email_change AFTER UPDATE OF email ON auth.users
  FOR EACH ROW WHEN (OLD.email IS DISTINCT FROM NEW.email) EXECUTE FUNCTION public.sync_user_email();

-- Profilfotos (E18-13): Bucket `profile-pictures` privat; Lesen nur für die Person selbst und Mitglieder gemeinsamer
-- Listen; der Client holt Bilder mit createSignedUrl.

-- Edge Function `delete-account` (E18-09), Ablauf (TypeScript, nicht SQL):
--   Eingabe {method, apple_authorization_code?}; Antwort {ok: true} oder {ok: false}.
--   Prüfung: gültiges Supabase-JWT. Apple: Code bei https://appleid.apple.com/auth/token eintauschen
--   (client_secret als ES256-JWT, Codes gelten 5 Minuten); Google und E-Mail: auth.users.last_sign_in_at < 5 Minuten.
--   In EINER Transaktion:
--     1. geteilte eigene Listen an das zuerst beigetretene Mitglied übergeben (shopping_lists.owner_id, Rolle in
--        list_members); Listen ohne weitere Mitglieder samt shopping_items löschen;
--     2. eigene Mitgliedschaften löschen, in fremden Listen den Namen an shopping_items.added_by entfernen;
--     3. eigene recipes (F18-09: löschen) samt recipe_ratings, recipe_comments, saved_recipes, collection*,
--        creator_follows löschen;
--     4. shopping_history mit Positionen löschen; offene expense_splits für die anderen auf is_paid = true,
--        user_id/paid_by_user_id auf null;
--     5. food_log_entries, water_log, weight_log, workout_log, nutrition_goals, challenge_*, user_food, meal_plan*,
--        user_preferences, user_stats, user_achievements, user_notification_prefs und users löschen;
--     6. danach Ordner profile-pictures/<uid>/ leeren und auth.admin.deleteUser(uid).
--   Bei jedem Fehler Rollback und {ok: false}; den Apple-Token erst nach dem Commit widerrufen (/auth/revoke).

-- Supabase Auth: Vorlage "Change Email Address" mit {{ .Token }}; "Secure email change" aus (sonst Codes an beide
-- Adressen).
