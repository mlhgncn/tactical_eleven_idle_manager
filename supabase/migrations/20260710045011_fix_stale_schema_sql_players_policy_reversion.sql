-- Same root cause as fix_stale_schema_sql_function_reversion: schema.sql
-- runs unconditionally on every CI deploy and still had the OLD
-- restrictive players_select_policy (no transfer_market carve-out),
-- silently reverting the fix from migration
-- 20260709182435_fix_players_select_policy_transfer_market.sql after
-- every single deploy since. Restoring it live now; the companion fix to
-- supabase/schema.sql (same commit) stops this specific policy from
-- reverting again.
DROP POLICY IF EXISTS players_select_policy ON public.players;
CREATE POLICY players_select_policy ON public.players
FOR SELECT
USING (
  club_id IS NULL
  OR club_id = (SELECT id FROM public.clubs WHERE user_id = auth.uid() LIMIT 1)
  OR EXISTS (SELECT 1 FROM public.transfer_market tm WHERE tm.player_id = players.id)
);
