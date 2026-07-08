-- OSM pivot, part 2: scheduled match resolution infrastructure.
--
-- Previously the only way a match got a result was a user tapping "Maçı
-- Oyna" in the app - fixtures with a passed match_date just sat unplayed
-- forever if nobody opened the app. This adds a pg_cron job that calls the
-- new auto_resolve_matches edge function every 5 minutes, which plays every
-- match whose kickoff time has passed regardless of whether either club's
-- owner is online (falling back to bot AI tactics for unclaimed clubs).

-- update_standings_after_match is SECURITY DEFINER and only touches
-- standings for a match_id that already exists - the auth.uid() IS NULL
-- guard was meant to block anonymous abuse, but it also blocks the
-- service-role edge functions that are the only real callers (auth.uid()
-- resolves to NULL for service-role calls too, since there's no user JWT).
-- That means this call has likely been silently failing from
-- play_next_fixture ever since it was added. Drop the guard entirely.
CREATE OR REPLACE FUNCTION public.update_standings_after_match(p_match_id UUID)
RETURNS void AS $$
DECLARE
  match_row public.matches%ROWTYPE;
BEGIN
  SELECT * INTO match_row FROM public.matches WHERE id = p_match_id;
  IF NOT FOUND THEN
    RETURN;
  END IF;
  IF match_row.home_score IS NULL OR match_row.away_score IS NULL OR match_row.season_id IS NULL THEN
    RETURN;
  END IF;
  INSERT INTO public.league_standings (season_id, club_id, played, wins, draws, losses, goals_for, goals_against, goal_difference, points, position)
  VALUES (match_row.season_id, match_row.home_club_id, 0, 0, 0, 0, 0, 0, 0, 0, NULL)
  ON CONFLICT (season_id, club_id) DO NOTHING;
  INSERT INTO public.league_standings (season_id, club_id, played, wins, draws, losses, goals_for, goals_against, goal_difference, points, position)
  VALUES (match_row.season_id, match_row.away_club_id, 0, 0, 0, 0, 0, 0, 0, 0, NULL)
  ON CONFLICT (season_id, club_id) DO NOTHING;
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
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Daily recovery tick: injuries heal by a week and fitness regenerates a
-- little each day, driven by the schedule rather than "time since the
-- player last opened the app" (that was the offline-progress mechanic this
-- OSM pivot removes).
CREATE OR REPLACE FUNCTION public.daily_player_tick()
RETURNS void AS $$
BEGIN
  UPDATE public.players
  SET injury_duration_weeks = GREATEST(0, injury_duration_weeks - 1),
      is_suspended = GREATEST(0, injury_duration_weeks - 1) > 0,
      fitness = LEAST(100, fitness + 5)
  WHERE injury_duration_weeks > 0 OR fitness < 100;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Shared secret for pg_cron -> auto_resolve_matches auth. Generated
-- server-side so the raw value never has to appear in a migration file or
-- chat transcript; the edge function looks up this same row to validate the
-- x-cron-secret header pg_cron sends.
INSERT INTO public.environment_secrets (key, value, is_encrypted)
VALUES ('CRON_SHARED_SECRET', encode(gen_random_bytes(24), 'hex'), TRUE)
ON CONFLICT (key) DO NOTHING;

-- Retire the old pre-OSM cron jobs: 'auto-match-simulator-daily' pointed at
-- an edge function (auto_match_simulator) that was never actually deployed,
-- and 'offline-progress-simulator-6h' called simulate_offline_progress with
-- a process_all_clubs flag that function never implemented (it only ever
-- handled one JWT-authenticated club) - both have been no-ops or silent
-- failures. auto-resolve-matches below replaces what they were meant to do.
SELECT cron.unschedule(jobid) FROM cron.job WHERE jobname IN ('auto-match-simulator-daily', 'offline-progress-simulator-6h');

-- Every 5 minutes: resolve any match whose kickoff time has passed.
SELECT cron.unschedule(jobid) FROM cron.job WHERE jobname = 'auto-resolve-matches';
SELECT cron.schedule(
  'auto-resolve-matches',
  '*/5 * * * *',
  $$
  SELECT net.http_post(
    url := 'https://dfdidifutotlxvvslzrl.supabase.co/functions/v1/auto_resolve_matches',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cron-secret', (SELECT value FROM public.environment_secrets WHERE key = 'CRON_SHARED_SECRET')
    ),
    body := '{}'::jsonb
  );
  $$
);

-- Once daily at 03:00 UTC: injury recovery + fitness regen.
SELECT cron.unschedule(jobid) FROM cron.job WHERE jobname = 'daily-player-tick';
SELECT cron.schedule(
  'daily-player-tick',
  '0 3 * * *',
  $$SELECT public.daily_player_tick();$$
);
