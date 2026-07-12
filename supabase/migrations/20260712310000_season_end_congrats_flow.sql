-- When a human-owned club's league season completes, the season used to
-- auto-continue immediately and invisibly (advance_completed_seasons
-- unconditionally called generate_season_fixtures_for_league right after
-- crowning a champion) - there was never a moment the client could show a
-- "congratulations, continue?" screen, because the next season had already
-- started before the user could see the completed one. This gates
-- auto-continuation: if a league has a human-owned club, that club is
-- flagged via pending_season_end_season_id instead of the league
-- auto-continuing, and the client asks the user to continue (same club,
-- fresh season, squad kept but weakened) or leave (club released, user
-- redirected to create/join a different league). Bot-only leagues keep
-- auto-continuing exactly as before.

ALTER TABLE public.clubs ADD COLUMN IF NOT EXISTS pending_season_end_season_id UUID REFERENCES public.seasons(id) ON DELETE SET NULL;

CREATE OR REPLACE FUNCTION public.advance_completed_seasons()
RETURNS void AS $$
DECLARE
  season_rec RECORD;
  champion_id UUID;
  champion_user_id UUID;
  champion_losses INT;
  human_club_id UUID;
BEGIN
  FOR season_rec IN
    SELECT s.id, s.league_id
    FROM public.seasons s
    WHERE s.is_active = true
      AND s.is_completed = false
      AND EXISTS (SELECT 1 FROM public.matches m WHERE m.season_id = s.id)
      AND NOT EXISTS (SELECT 1 FROM public.matches m WHERE m.season_id = s.id AND m.is_played = false)
  LOOP
    SELECT club_id, losses INTO champion_id, champion_losses
    FROM public.league_standings
    WHERE season_id = season_rec.id
    ORDER BY points DESC, goal_difference DESC, goals_for DESC
    LIMIT 1;

    UPDATE public.seasons
    SET is_completed = true, is_active = false, champion_club_id = champion_id, end_date = now()
    WHERE id = season_rec.id;

    IF champion_id IS NOT NULL THEN
      SELECT user_id INTO champion_user_id FROM public.clubs WHERE id = champion_id;
      IF champion_user_id IS NOT NULL THEN
        UPDATE public.profiles
        SET league_titles = league_titles + 1, diamonds = diamonds + 50
        WHERE id = champion_user_id;

        IF champion_losses = 0 THEN
          UPDATE public.profiles SET has_unbeaten_title = true WHERE id = champion_user_id;
        END IF;

        INSERT INTO public.inbox_messages(recipient_id, title, body, is_read, created_at)
        VALUES (
          champion_user_id,
          'Şampiyonluk!',
          'Tebrikler, kulübün ligi şampiyon olarak tamamladı! Kupa dolabına bir kupa daha eklendi ve hesabına 50 elmas hediye edildi.',
          false,
          now()
        );
      END IF;
    END IF;

    -- Only auto-continue if no human owns a club in this league. If one
    -- does, flag their club with the just-completed season id and stop -
    -- the client shows the congrats/decision screen, and either
    -- continue_club_new_season or release_club_and_leave_league picks up
    -- from here once the user answers.
    SELECT id INTO human_club_id FROM public.clubs WHERE league_id = season_rec.league_id AND user_id IS NOT NULL LIMIT 1;
    IF human_club_id IS NOT NULL THEN
      UPDATE public.clubs SET pending_season_end_season_id = season_rec.id WHERE id = human_club_id;
    ELSE
      PERFORM public.generate_season_fixtures_for_league(season_rec.league_id);
    END IF;
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- User chose "continue with this same club" on the congrats screen: keeps
-- the same players (so their names/identity persist - the user specifically
-- asked to avoid duplicate player names existing elsewhere in the league,
-- which is naturally satisfied since no new players are generated for this
-- club, only for whichever bot clubs regenerate as part of a normal new
-- league - this call reuses the SAME league, so bot clubs aren't touched
-- either), but weakens current_ability by 20-30% to feel like a fresh
-- start, then starts a new season for the league exactly like joining a
-- league does (48h delayed kickoff, open to new joiners in the meantime).
CREATE OR REPLACE FUNCTION public.continue_club_new_season(p_club_id UUID)
RETURNS public.clubs AS $$
DECLARE
  club_row public.clubs%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated user';
  END IF;

  SELECT * INTO club_row FROM public.clubs WHERE id = p_club_id AND user_id = auth.uid();
  IF NOT FOUND THEN
    RAISE EXCEPTION 'User does not own this club';
  END IF;

  IF club_row.pending_season_end_season_id IS NULL THEN
    RAISE EXCEPTION 'Bu kulüp için bekleyen bir sezon sonu yok.';
  END IF;

  UPDATE public.players
  SET current_ability = GREATEST(20, ROUND(current_ability * (0.70 + random() * 0.10)))
  WHERE club_id = p_club_id;

  UPDATE public.clubs SET pending_season_end_season_id = NULL WHERE id = p_club_id
  RETURNING * INTO club_row;

  PERFORM public.generate_season_fixtures_for_league(club_row.league_id);

  RETURN club_row;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- User chose "no, I'm done with this club" on the congrats screen: same
-- release pattern as leave_current_club (turns the club back into a bot
-- club rather than deleting it - deleting would orphan match history and
-- break the league for other participants), just also clearing the
-- pending flag so it doesn't linger on the now-bot-controlled row.
CREATE OR REPLACE FUNCTION public.release_club_and_leave_league(p_club_id UUID)
RETURNS void AS $$
DECLARE
  owned_club_id UUID;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated user';
  END IF;

  SELECT id INTO owned_club_id FROM public.clubs WHERE id = p_club_id AND user_id = auth.uid();
  IF owned_club_id IS NULL THEN
    RAISE EXCEPTION 'User does not own this club';
  END IF;

  UPDATE public.clubs SET user_id = NULL, pending_season_end_season_id = NULL WHERE id = owned_club_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION public.advance_completed_seasons() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.continue_club_new_season(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.release_club_and_leave_league(UUID) TO authenticated;
