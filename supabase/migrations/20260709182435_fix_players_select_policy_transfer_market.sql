-- players_select_policy only allowed reading players from the user's own
-- club (or free agents), which silently blocked the entire `players` embed
-- (name, position, AND nested club) for every transfer market listing that
-- wasn't the user's own club's player. Allow reading a player when it is
-- currently listed on the transfer market too, since the market
-- fundamentally requires showing other clubs' listed players.
DROP POLICY IF EXISTS players_select_policy ON public.players;
CREATE POLICY players_select_policy ON public.players
FOR SELECT
USING (
  club_id IS NULL
  OR club_id = (SELECT clubs.id FROM public.clubs WHERE clubs.user_id = auth.uid() LIMIT 1)
  OR EXISTS (SELECT 1 FROM public.transfer_market tm WHERE tm.player_id = players.id)
);
