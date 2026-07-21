-- Monthly cup: a 16-club single-elimination knockout, separate from the
-- league grind. Participants are drawn from across every theme/league
-- (human-owned clubs first, padded out with random bots to always reach
-- 16 - with only ~22 human-owned clubs total, a human-only bracket would
-- rarely fill), one club per user (a user with multiple clubs only enters
-- their first one, so the same person can't occupy two of the 16 slots).
-- Cup matches reuse matches/match_engine.ts unchanged (resolveMatch
-- already treats season_id as optional and skips league_standings/form
-- for it) - they're just matches rows with league_id/season_id left NULL
-- and cup_tournament_id/cup_round set instead, so the existing
-- auto_resolve_matches cron picks them up with no changes needed there.

CREATE TABLE IF NOT EXISTS public.cup_tournaments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  status TEXT NOT NULL DEFAULT 'active', -- 'active' | 'completed'
  current_round INT NOT NULL DEFAULT 1, -- 1=Round of 16, 2=QF, 3=SF, 4=Final
  champion_club_id UUID REFERENCES public.clubs(id) ON DELETE SET NULL,
  started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  completed_at TIMESTAMPTZ
);

ALTER TABLE public.matches
  ADD COLUMN IF NOT EXISTS cup_tournament_id UUID REFERENCES public.cup_tournaments(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS cup_round INT;

CREATE INDEX IF NOT EXISTS idx_matches_cup_tournament ON public.matches(cup_tournament_id) WHERE cup_tournament_id IS NOT NULL;

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS cup_titles INT NOT NULL DEFAULT 0;

ALTER TABLE public.cup_tournaments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS cup_tournaments_select_policy ON public.cup_tournaments;
CREATE POLICY cup_tournaments_select_policy ON public.cup_tournaments
FOR SELECT USING (auth.uid() IS NOT NULL);

-- Starts a new 16-club cup if none is currently active. Draw: every
-- human-owned club (one per user, oldest club per user wins ties) first,
-- then random bots to fill the remaining slots up to 16. If fewer than 16
-- clubs exist at all (shouldn't happen given ~1200+ bot clubs) it simply
-- doesn't start. Round-of-16 matches are scheduled 2 days out (same
-- "kickoff isn't instant" feel as a new league), each subsequent round
-- advance_cup_round schedules 3 days after the previous round's matches.
CREATE OR REPLACE FUNCTION public.start_monthly_cup()
RETURNS UUID AS $$
DECLARE
  new_tournament_id UUID;
  participants UUID[];
  human_clubs UUID[];
  bot_fill_count INT;
  bot_clubs UUID[];
  i INT;
  kickoff TIMESTAMPTZ := now() + interval '2 days';
BEGIN
  IF EXISTS (SELECT 1 FROM public.cup_tournaments WHERE status = 'active') THEN
    RAISE EXCEPTION 'Zaten aktif bir kupa turnuvası var';
  END IF;

  SELECT array_agg(pick.club_id) INTO human_clubs
  FROM (
    SELECT DISTINCT ON (c.user_id) c.id AS club_id
    FROM public.clubs c
    WHERE c.user_id IS NOT NULL
    ORDER BY c.user_id, c.created_at ASC
  ) pick;

  human_clubs := COALESCE(human_clubs, ARRAY[]::UUID[]);
  -- Cap human slots at 16 (shuffle first in case there are ever more than 16 users).
  IF array_length(human_clubs, 1) > 16 THEN
    SELECT array_agg(x) INTO human_clubs FROM (SELECT unnest(human_clubs) AS x ORDER BY random() LIMIT 16) s;
  END IF;

  bot_fill_count := 16 - COALESCE(array_length(human_clubs, 1), 0);

  IF bot_fill_count > 0 THEN
    SELECT array_agg(c.id) INTO bot_clubs
    FROM (
      SELECT id FROM public.clubs
      WHERE user_id IS NULL AND NOT (id = ANY(human_clubs))
      ORDER BY random()
      LIMIT bot_fill_count
    ) c;
  END IF;

  participants := human_clubs || COALESCE(bot_clubs, ARRAY[]::UUID[]);

  IF array_length(participants, 1) IS NULL OR array_length(participants, 1) < 16 THEN
    RAISE EXCEPTION 'Kupa için yeterli kulüp yok (16 gerekli, % bulundu)', COALESCE(array_length(participants, 1), 0);
  END IF;

  -- Shuffle the final bracket order so human vs human / human vs bot pairings are random.
  SELECT array_agg(x) INTO participants FROM (SELECT unnest(participants) AS x ORDER BY random()) s;

  INSERT INTO public.cup_tournaments (status, current_round) VALUES ('active', 1)
  RETURNING id INTO new_tournament_id;

  FOR i IN 1..8 LOOP
    INSERT INTO public.matches (home_club_id, away_club_id, match_date, is_played, cup_tournament_id, cup_round, week)
    VALUES (participants[i * 2 - 1], participants[i * 2], kickoff, false, new_tournament_id, 1, 1);
  END LOOP;

  RETURN new_tournament_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Advances every active cup whose current round has fully finished:
-- pairs up winners (draws broken by higher home+away combined score is
-- moot since resolveMatch never leaves a draw unresolved at the top level
-- - but as a safety net, a genuine tie is broken by coin flip so the
-- bracket can never stall), schedules the next round 3 days out, or
-- crowns a champion if the final just finished.
CREATE OR REPLACE FUNCTION public.advance_cup_round()
RETURNS void AS $$
DECLARE
  tourney public.cup_tournaments%ROWTYPE;
  round_matches RECORD;
  winners UUID[];
  winner_id UUID;
  i INT;
  next_kickoff TIMESTAMPTZ;
  champion_user_id UUID;
BEGIN
  FOR tourney IN SELECT * FROM public.cup_tournaments WHERE status = 'active' LOOP
    IF EXISTS (
      SELECT 1 FROM public.matches
      WHERE cup_tournament_id = tourney.id AND cup_round = tourney.current_round AND is_played = false
    ) THEN
      CONTINUE; -- round still in progress
    END IF;

    winners := ARRAY[]::UUID[];
    FOR round_matches IN
      SELECT home_club_id, away_club_id, home_score, away_score
      FROM public.matches
      WHERE cup_tournament_id = tourney.id AND cup_round = tourney.current_round
      ORDER BY match_date, id
    LOOP
      IF round_matches.home_score > round_matches.away_score THEN
        winner_id := round_matches.home_club_id;
      ELSIF round_matches.away_score > round_matches.home_score THEN
        winner_id := round_matches.away_club_id;
      ELSE
        winner_id := CASE WHEN random() < 0.5 THEN round_matches.home_club_id ELSE round_matches.away_club_id END;
      END IF;
      winners := winners || winner_id;
    END LOOP;

    IF array_length(winners, 1) = 1 THEN
      -- Final just finished - crown the champion.
      SELECT user_id INTO champion_user_id FROM public.clubs WHERE id = winners[1];
      UPDATE public.cup_tournaments
      SET status = 'completed', champion_club_id = winners[1], completed_at = now()
      WHERE id = tourney.id;

      IF champion_user_id IS NOT NULL THEN
        UPDATE public.profiles SET cup_titles = cup_titles + 1, diamonds = diamonds + 75 WHERE id = champion_user_id;
        INSERT INTO public.inbox_messages(recipient_id, club_id, title, body, is_read, created_at)
        VALUES (
          champion_user_id, winners[1], 'Kupa Şampiyonu!',
          'Tebrikler, aylık kupa turnuvasını kazandın! Hesabına 75 elmas hediye edildi.',
          false, now()
        );
      END IF;
      CONTINUE;
    END IF;

    next_kickoff := now() + interval '3 days';

    FOR i IN 1..(array_length(winners, 1) / 2) LOOP
      INSERT INTO public.matches (home_club_id, away_club_id, match_date, is_played, cup_tournament_id, cup_round, week)
      VALUES (winners[i * 2 - 1], winners[i * 2], next_kickoff, false, tourney.id, tourney.current_round + 1, 1);
    END LOOP;

    UPDATE public.cup_tournaments SET current_round = current_round + 1 WHERE id = tourney.id;
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Read-only view for the client: this user's cup matches (past and
-- upcoming) across any tournament, newest first.
CREATE OR REPLACE FUNCTION public.get_my_cup_matches()
RETURNS TABLE(
  match_id UUID,
  cup_tournament_id UUID,
  cup_round INT,
  home_club_id UUID,
  home_club_name TEXT,
  away_club_id UUID,
  away_club_name TEXT,
  home_score INT,
  away_score INT,
  is_played BOOLEAN,
  match_date TIMESTAMPTZ,
  tournament_status TEXT
) AS $$
  SELECT m.id, m.cup_tournament_id, m.cup_round,
    m.home_club_id, hc.name, m.away_club_id, ac.name,
    m.home_score, m.away_score, m.is_played, m.match_date, ct.status
  FROM public.matches m
  JOIN public.clubs hc ON hc.id = m.home_club_id
  JOIN public.clubs ac ON ac.id = m.away_club_id
  JOIN public.cup_tournaments ct ON ct.id = m.cup_tournament_id
  WHERE m.cup_tournament_id IS NOT NULL
    AND (hc.user_id = auth.uid() OR ac.user_id = auth.uid())
  ORDER BY m.match_date DESC;
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION public.get_my_cup_matches() TO authenticated;
REVOKE EXECUTE ON FUNCTION public.start_monthly_cup() FROM PUBLIC, authenticated, anon;
REVOKE EXECUTE ON FUNCTION public.advance_cup_round() FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION public.start_monthly_cup() TO service_role;
GRANT EXECUTE ON FUNCTION public.advance_cup_round() TO service_role;

-- Monthly kickoff: 1st of each month at 03:45 UTC (right after
-- advance-completed-seasons at 03:30, no schedule collision). Guards
-- itself against an already-active tournament, so a slow month doesn't
-- pile up parallel cups if this ever runs twice near a month boundary.
SELECT cron.schedule('start-monthly-cup', '45 3 1 * *', $$SELECT public.start_monthly_cup()$$);

-- Daily round-advance check: cheap no-op when no active tournament's
-- current round has finished yet.
SELECT cron.schedule('advance-cup-round', '50 3 * * *', $$SELECT public.advance_cup_round()$$);
