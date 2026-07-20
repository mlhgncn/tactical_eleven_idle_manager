-- players_select_policy only allowed a user to see players belonging to
-- ONE of their clubs - whichever `clubs WHERE user_id = auth.uid() LIMIT 1`
-- happened to pick (typically the oldest). For a user with 2+ clubs
-- (multi-league support), every player belonging to their 2nd/3rd/4th club
-- was invisible under RLS: squad screen empty, tactics screen couldn't
-- resolve starting XI names, match/opponent views missing rosters - even
-- though the underlying rows were always there (players_count queries
-- confirmed no data loss). Same bug family as the RPC "which club" bugs
-- fixed earlier, but on a SELECT policy instead of a function body.
DROP POLICY IF EXISTS players_select_policy ON public.players;
CREATE POLICY players_select_policy ON public.players
FOR SELECT
USING (
  club_id IS NULL
  OR club_id IN (SELECT id FROM public.clubs WHERE user_id = auth.uid())
  OR EXISTS (SELECT 1 FROM public.transfer_market tm WHERE tm.player_id = players.id)
);

-- Same bug on transfer_offers: a user's incoming/outgoing offers for their
-- 2nd+ club were invisible because from_club_id/to_club_id was compared
-- against a single arbitrarily-picked club instead of any owned club.
DROP POLICY IF EXISTS transfer_offers_select_policy ON public.transfer_offers;
CREATE POLICY transfer_offers_select_policy ON public.transfer_offers
FOR SELECT
USING (
  from_club_id IN (SELECT id FROM public.clubs WHERE user_id = auth.uid())
  OR to_club_id IN (SELECT id FROM public.clubs WHERE user_id = auth.uid())
);
