-- Trophy count lives on profiles (the user), not clubs, since clubs can
-- change owners (bot reassignment, or a user leaving via
-- leave_current_club) after a title was already won - capture the
-- winning user_id at the moment of crowning so a later ownership change
-- can never retroactively gain or lose someone their trophy.
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS league_titles INT NOT NULL DEFAULT 0;

CREATE OR REPLACE FUNCTION public.advance_completed_seasons()
RETURNS void AS $$
DECLARE
  season_rec RECORD;
  champion_id UUID;
  champion_user_id UUID;
BEGIN
  FOR season_rec IN
    SELECT s.id, s.league_id
    FROM public.seasons s
    WHERE s.is_active = true
      AND s.is_completed = false
      AND EXISTS (SELECT 1 FROM public.matches m WHERE m.season_id = s.id)
      AND NOT EXISTS (SELECT 1 FROM public.matches m WHERE m.season_id = s.id AND m.is_played = false)
  LOOP
    SELECT club_id INTO champion_id
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
        UPDATE public.profiles SET league_titles = league_titles + 1 WHERE id = champion_user_id;

        INSERT INTO public.inbox_messages(recipient_id, title, body, is_read, created_at)
        VALUES (
          champion_user_id,
          'Şampiyonluk!',
          'Tebrikler, kulübün ligi şampiyon olarak tamamladı! Kupa dolabına bir kupa daha eklendi.',
          false,
          now()
        );
      END IF;
    END IF;

    PERFORM public.generate_season_fixtures_for_league(season_rec.league_id);
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
