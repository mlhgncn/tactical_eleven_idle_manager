-- Three new achievements:
--   1. "Altından Kupa" - win a season as champion without a single loss (200 diamonds)
--   2. "Fabrika Ayarları" - upgrade a club's stadium or training facility to max level (80 diamonds)
--   3. "Sir Alex Ferguson" - claim the daily login reward on 45 consecutive days (150 diamonds)

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS achievement_unbeaten_champion_claimed BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS achievement_max_facility_claimed BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS achievement_45_day_streak_claimed BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS has_unbeaten_title BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS current_login_streak INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS longest_login_streak INT NOT NULL DEFAULT 0;

-- advance_completed_seasons: same body as 20260709192255_league_titles_trophy_tracking.sql,
-- but now also checks whether the champion finished with zero losses and
-- flags it on their profile at the moment of crowning - standings get
-- reset by the next season, so this can't be recomputed later from raw
-- match history the way total_wins/best_win_streak can.
CREATE OR REPLACE FUNCTION public.advance_completed_seasons()
RETURNS void AS $$
DECLARE
  season_rec RECORD;
  champion_id UUID;
  champion_user_id UUID;
  champion_losses INT;
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
        UPDATE public.profiles SET league_titles = league_titles + 1 WHERE id = champion_user_id;

        IF champion_losses = 0 THEN
          UPDATE public.profiles SET has_unbeaten_title = true WHERE id = champion_user_id;
        END IF;

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

-- claim_daily_login_reward: same body as 20260712210000_profile_levels_achievements_streaks.sql,
-- but now also maintains an unbounded consecutive-day counter alongside
-- the existing weekly 1-7 cycle (which by design resets every 7th claim -
-- not usable for a 45-day achievement). Consecutive here means "claimed
-- yesterday or this is the very first claim"; any gap resets to 1.
CREATE OR REPLACE FUNCTION public.claim_daily_login_reward(p_club_id UUID DEFAULT NULL)
RETURNS JSONB AS $$
DECLARE
  u_id UUID := auth.uid();
  profile_row public.profiles%ROWTYPE;
  club_row public.clubs%ROWTYPE;
  today DATE := (now() AT TIME ZONE 'Europe/Istanbul')::date;
  this_week_start DATE := today - EXTRACT(ISODOW FROM today)::int + 1;
  next_day INT;
  gp_reward INT;
  diamond_reward INT := 0;
  next_login_streak INT;
BEGIN
  IF u_id IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated';
  END IF;

  SELECT * INTO profile_row FROM public.profiles WHERE id = u_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Profil bulunamadı';
  END IF;

  IF profile_row.last_daily_claim_date = today THEN
    RAISE EXCEPTION 'Bugünkü ödülü zaten aldınız.';
  END IF;

  IF profile_row.daily_streak_week_start IS DISTINCT FROM this_week_start
     OR profile_row.last_daily_claim_date IS NULL
     OR profile_row.last_daily_claim_date < today - 1 THEN
    next_day := 1;
  ELSE
    next_day := LEAST(7, profile_row.daily_streak_day + 1);
  END IF;

  IF profile_row.last_daily_claim_date = today - 1 THEN
    next_login_streak := profile_row.current_login_streak + 1;
  ELSE
    next_login_streak := 1;
  END IF;

  IF p_club_id IS NOT NULL THEN
    SELECT * INTO club_row FROM public.clubs WHERE id = p_club_id AND user_id = u_id;
  ELSE
    SELECT * INTO club_row FROM public.clubs WHERE user_id = u_id LIMIT 1;
  END IF;

  IF next_day = 7 THEN
    diamond_reward := 20;
    UPDATE public.profiles
    SET diamonds = diamonds + diamond_reward,
        daily_streak_day = 7,
        daily_streak_week_start = this_week_start,
        last_daily_claim_date = today,
        current_login_streak = next_login_streak,
        longest_login_streak = GREATEST(longest_login_streak, next_login_streak)
    WHERE id = u_id RETURNING * INTO profile_row;
  ELSE
    gp_reward := next_day * 1000;
    IF club_row.id IS NOT NULL THEN
      UPDATE public.clubs SET budget = budget + gp_reward WHERE id = club_row.id;
      INSERT INTO public.financial_transactions(club_id, type, amount, description, source)
      VALUES (club_row.id, 'daily_login_reward', gp_reward, format('Günlük giriş ödülü (gün %s): +%s GP', next_day, gp_reward), 'claim_daily_login_reward');
    END IF;
    UPDATE public.profiles
    SET daily_streak_day = next_day,
        daily_streak_week_start = this_week_start,
        last_daily_claim_date = today,
        current_login_streak = next_login_streak,
        longest_login_streak = GREATEST(longest_login_streak, next_login_streak)
    WHERE id = u_id RETURNING * INTO profile_row;
  END IF;

  RETURN jsonb_build_object(
    'day', next_day,
    'gp_awarded', COALESCE(gp_reward, 0),
    'diamonds_awarded', diamond_reward,
    'profile', to_jsonb(profile_row)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- claim_achievement_reward: same body as 20260712210000_profile_levels_achievements_streaks.sql,
-- with 3 new ELSIF branches for the new achievements. "max_facility" is
-- checked live against the caller's clubs (no new club-side tracking
-- needed - stadium_capacity/training_facility_level are already
-- persistent columns); the other two just read the flags/counters
-- maintained above.
CREATE OR REPLACE FUNCTION public.claim_achievement_reward(p_achievement TEXT)
RETURNS public.profiles AS $$
DECLARE
  u_id UUID := auth.uid();
  profile_row public.profiles%ROWTYPE;
  reward_amount INT;
  has_max_facility BOOLEAN;
BEGIN
  IF u_id IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated';
  END IF;

  SELECT * INTO profile_row FROM public.profiles WHERE id = u_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Profil bulunamadı';
  END IF;

  IF p_achievement = '100_wins' THEN
    IF profile_row.achievement_100_wins_claimed THEN
      RAISE EXCEPTION 'Bu başarım zaten alındı.';
    END IF;
    IF profile_row.total_wins < 100 THEN
      RAISE EXCEPTION 'Bu başarım için henüz yeterli galibiyetiniz yok.';
    END IF;
    reward_amount := 100;
    UPDATE public.profiles
    SET achievement_100_wins_claimed = true, diamonds = diamonds + reward_amount
    WHERE id = u_id RETURNING * INTO profile_row;
  ELSIF p_achievement = 'win_streak_10' THEN
    IF profile_row.achievement_win_streak_10_claimed THEN
      RAISE EXCEPTION 'Bu başarım zaten alındı.';
    END IF;
    IF profile_row.best_win_streak < 10 THEN
      RAISE EXCEPTION 'Bu başarım için henüz üst üste 10 galibiyet almadınız.';
    END IF;
    reward_amount := 50;
    UPDATE public.profiles
    SET achievement_win_streak_10_claimed = true, diamonds = diamonds + reward_amount
    WHERE id = u_id RETURNING * INTO profile_row;
  ELSIF p_achievement = 'unbeaten_champion' THEN
    IF profile_row.achievement_unbeaten_champion_claimed THEN
      RAISE EXCEPTION 'Bu başarım zaten alındı.';
    END IF;
    IF NOT profile_row.has_unbeaten_title THEN
      RAISE EXCEPTION 'Bu başarım için henüz yenilgisiz şampiyon olmadınız.';
    END IF;
    reward_amount := 200;
    UPDATE public.profiles
    SET achievement_unbeaten_champion_claimed = true, diamonds = diamonds + reward_amount
    WHERE id = u_id RETURNING * INTO profile_row;
  ELSIF p_achievement = 'max_facility' THEN
    IF profile_row.achievement_max_facility_claimed THEN
      RAISE EXCEPTION 'Bu başarım zaten alındı.';
    END IF;
    SELECT EXISTS (
      SELECT 1 FROM public.clubs
      WHERE user_id = u_id AND (stadium_capacity >= 100000 OR training_facility_level >= 10)
    ) INTO has_max_facility;
    IF NOT has_max_facility THEN
      RAISE EXCEPTION 'Bu başarım için henüz stadyum veya tesisinizi maksimum seviyeye çıkarmadınız.';
    END IF;
    reward_amount := 80;
    UPDATE public.profiles
    SET achievement_max_facility_claimed = true, diamonds = diamonds + reward_amount
    WHERE id = u_id RETURNING * INTO profile_row;
  ELSIF p_achievement = '45_day_streak' THEN
    IF profile_row.achievement_45_day_streak_claimed THEN
      RAISE EXCEPTION 'Bu başarım zaten alındı.';
    END IF;
    IF profile_row.longest_login_streak < 45 THEN
      RAISE EXCEPTION 'Bu başarım için henüz 45 gün aralıksız oyuna girmediniz.';
    END IF;
    reward_amount := 150;
    UPDATE public.profiles
    SET achievement_45_day_streak_claimed = true, diamonds = diamonds + reward_amount
    WHERE id = u_id RETURNING * INTO profile_row;
  ELSE
    RAISE EXCEPTION 'Bilinmeyen başarım.';
  END IF;

  RETURN profile_row;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION public.advance_completed_seasons() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.claim_daily_login_reward(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.claim_achievement_reward(TEXT) TO authenticated;
