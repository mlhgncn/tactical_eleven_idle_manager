-- Root cause of "Puan durumu güncellenmiyor" (standings never update):
-- update_standings_after_match() had an `auth.uid() IS NULL` guard left
-- over from when it was only ever called by a logged-in user's manual
-- "Maçı Oyna" button. That button was removed earlier this session -
-- auto_resolve_matches (a pg_cron edge function using the SERVICE ROLE,
-- no end-user JWT) is now the ONLY path that resolves matches, so this
-- guard has been rejecting every single call. The failure was completely
-- silent because supabase/functions/_shared/match_engine.ts awaited the
-- RPC without checking the returned error (fixed in the same commit).
--
-- Also adds position-ranking recomputation (previously `position` was
-- never set at all) and revokes direct EXECUTE from authenticated/anon
-- now that the auth.uid() guard is gone, since this is a non-idempotent
-- bookkeeping RPC that must only run once per resolved match.

CREATE OR REPLACE FUNCTION public.update_standings_after_match(p_match_id UUID)
RETURNS void AS $$
DECLARE
  match_row public.matches%ROWTYPE;
  home_row public.league_standings%ROWTYPE;
  away_row public.league_standings%ROWTYPE;
BEGIN
  SELECT * INTO match_row FROM public.matches WHERE id = p_match_id;
  IF NOT FOUND THEN
    RETURN;
  END IF;

  IF match_row.home_score IS NULL OR match_row.away_score IS NULL THEN
    RETURN;
  END IF;

  INSERT INTO public.league_standings (season_id, club_id, played, wins, draws, losses, goals_for, goals_against, goal_difference, points, position)
  VALUES (match_row.season_id, match_row.home_club_id, 0, 0, 0, 0, 0, 0, 0, 0, NULL)
  ON CONFLICT (season_id, club_id) DO NOTHING;

  INSERT INTO public.league_standings (season_id, club_id, played, wins, draws, losses, goals_for, goals_against, goal_difference, points, position)
  VALUES (match_row.season_id, match_row.away_club_id, 0, 0, 0, 0, 0, 0, 0, 0, NULL)
  ON CONFLICT (season_id, club_id) DO NOTHING;

  SELECT * INTO home_row FROM public.league_standings WHERE season_id = match_row.season_id AND club_id = match_row.home_club_id;
  SELECT * INTO away_row FROM public.league_standings WHERE season_id = match_row.season_id AND club_id = match_row.away_club_id;

  UPDATE public.league_standings
  SET played = played + 1,
      goals_for = goals_for + match_row.home_score,
      goals_against = goals_against + match_row.away_score,
      goal_difference = (goals_for + match_row.home_score) - (goals_against + match_row.away_score),
      wins = wins + CASE WHEN match_row.home_score > match_row.away_score THEN 1 ELSE 0 END,
      draws = draws + CASE WHEN match_row.home_score = match_row.away_score THEN 1 ELSE 0 END,
      losses = losses + CASE WHEN match_row.home_score < match_row.away_score THEN 1 ELSE 0 END,
      points = points + CASE WHEN match_row.home_score > match_row.away_score THEN 3 WHEN match_row.home_score = match_row.away_score THEN 1 ELSE 0 END,
      updated_at = now()
  WHERE season_id = match_row.season_id AND club_id = match_row.home_club_id;

  UPDATE public.league_standings
  SET played = played + 1,
      goals_for = goals_for + match_row.away_score,
      goals_against = goals_against + match_row.home_score,
      goal_difference = (goals_for + match_row.away_score) - (goals_against + match_row.home_score),
      wins = wins + CASE WHEN match_row.away_score > match_row.home_score THEN 1 ELSE 0 END,
      draws = draws + CASE WHEN match_row.home_score = match_row.away_score THEN 1 ELSE 0 END,
      losses = losses + CASE WHEN match_row.away_score < match_row.home_score THEN 1 ELSE 0 END,
      points = points + CASE WHEN match_row.away_score > match_row.home_score THEN 3 WHEN match_row.home_score = match_row.away_score THEN 1 ELSE 0 END,
      updated_at = now()
  WHERE season_id = match_row.season_id AND club_id = match_row.away_club_id;

  WITH ranked AS (
    SELECT id, ROW_NUMBER() OVER (
      ORDER BY points DESC, goal_difference DESC, goals_for DESC
    ) AS rn
    FROM public.league_standings
    WHERE season_id = match_row.season_id
  )
  UPDATE public.league_standings ls
  SET position = ranked.rn
  FROM ranked
  WHERE ls.id = ranked.id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE EXECUTE ON FUNCTION public.update_standings_after_match(uuid) FROM PUBLIC, authenticated, anon;
