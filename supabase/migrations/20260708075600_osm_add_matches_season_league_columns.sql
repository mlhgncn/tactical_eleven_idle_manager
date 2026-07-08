-- matches never had season_id/league_id columns despite
-- update_standings_after_match referencing match_row.season_id - that
-- function has been throwing "record has no field season_id" every time it
-- was actually invoked. Add both (league_id is a convenience for querying
-- "all matches in this league" without a season join).
ALTER TABLE public.matches
  ADD COLUMN IF NOT EXISTS season_id UUID REFERENCES public.seasons(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS league_id UUID REFERENCES public.leagues(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS idx_matches_season_id ON public.matches(season_id);
CREATE INDEX IF NOT EXISTS idx_matches_league_id ON public.matches(league_id);
CREATE INDEX IF NOT EXISTS idx_matches_is_played_match_date ON public.matches(is_played, match_date);
