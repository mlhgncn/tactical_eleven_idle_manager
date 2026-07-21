-- players_select_policy regressed AGAIN back to the LIMIT-1 (single
-- arbitrary club) version - the fix from 20260721000000 was correct and
-- applied, but supabase/schema.sql (which runs unconditionally on every
-- deploy) still had the pre-fix LIMIT 1 copy of this policy, so the very
-- next schema.sql deploy silently reverted it. Same stale-schema.sql-
-- reversion pattern that hit update_standings_after_match earlier - this
-- time fixed in BOTH schema.sql and here so it stops regressing.
DROP POLICY IF EXISTS players_select_policy ON public.players;
CREATE POLICY players_select_policy ON public.players
FOR SELECT
USING (
  club_id IS NULL
  OR club_id IN (SELECT id FROM public.clubs WHERE user_id = auth.uid())
  OR EXISTS (SELECT 1 FROM public.transfer_market tm WHERE tm.player_id = players.id)
);
