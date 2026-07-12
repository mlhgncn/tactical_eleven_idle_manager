-- Module 7: user levels/frames (derived from league_titles - Silver 5,
-- Gold 10, Diamond 20, Emerald 50), win-count/win-streak achievements,
-- a weekly 7-day login streak, social-follow rewards, and avatar upload
-- support. Level itself is computed client-side from league_titles (no
-- new column needed - see lib/models/profile.dart), everything else
-- below is new state.

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS total_wins INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS current_win_streak INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS best_win_streak INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS achievement_100_wins_claimed BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS achievement_win_streak_10_claimed BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS daily_streak_day INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS daily_streak_week_start DATE,
  ADD COLUMN IF NOT EXISTS last_daily_claim_date DATE,
  ADD COLUMN IF NOT EXISTS social_instagram_followed BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS social_x_followed BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS social_tiktok_followed BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS social_engagement_claimed BOOLEAN NOT NULL DEFAULT false;

-- Win/streak bookkeeping, folded into the same RPC that already updates
-- league_standings after every resolved match - one call site, called
-- exactly once per match by match_engine.ts (auto_resolve_matches /
-- play_next_fixture), same non-idempotency guarantee as the rest of this
-- function (REVOKEd from authenticated/anon below as before).
CREATE OR REPLACE FUNCTION public.update_standings_after_match(p_match_id UUID)
RETURNS void AS $$
DECLARE
  match_row public.matches%ROWTYPE;
  home_row public.league_standings%ROWTYPE;
  away_row public.league_standings%ROWTYPE;
  home_owner UUID;
  away_owner UUID;
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

  -- Per-user (not per-club - a club can change owners) total win count and
  -- win streak, only for clubs with a real owner. A draw/loss resets the
  -- streak to 0 but never decrements total_wins.
  SELECT user_id INTO home_owner FROM public.clubs WHERE id = match_row.home_club_id;
  SELECT user_id INTO away_owner FROM public.clubs WHERE id = match_row.away_club_id;

  IF home_owner IS NOT NULL THEN
    IF match_row.home_score > match_row.away_score THEN
      UPDATE public.profiles
      SET total_wins = total_wins + 1,
          current_win_streak = current_win_streak + 1,
          best_win_streak = GREATEST(best_win_streak, current_win_streak + 1)
      WHERE id = home_owner;
    ELSE
      UPDATE public.profiles SET current_win_streak = 0 WHERE id = home_owner;
    END IF;
  END IF;

  IF away_owner IS NOT NULL THEN
    IF match_row.away_score > match_row.home_score THEN
      UPDATE public.profiles
      SET total_wins = total_wins + 1,
          current_win_streak = current_win_streak + 1,
          best_win_streak = GREATEST(best_win_streak, current_win_streak + 1)
      WHERE id = away_owner;
    ELSE
      UPDATE public.profiles SET current_win_streak = 0 WHERE id = away_owner;
    END IF;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE EXECUTE ON FUNCTION public.update_standings_after_match(uuid) FROM PUBLIC, authenticated, anon;

-- Claims a diamond achievement reward once its threshold is met. Both
-- achievements are one-time (guarded by their _claimed flag), so this
-- never double-pays even if the client calls it repeatedly.
CREATE OR REPLACE FUNCTION public.claim_achievement_reward(p_achievement TEXT)
RETURNS public.profiles AS $$
DECLARE
  u_id UUID := auth.uid();
  profile_row public.profiles%ROWTYPE;
  reward_amount INT;
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
  ELSE
    RAISE EXCEPTION 'Bilinmeyen başarım.';
  END IF;

  RETURN profile_row;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Weekly 7-day login streak. Days 1-6 pay increasing GP (to the caller's
-- own club - falls back to their first club if p_club_id is omitted), day
-- 7 pays 20 diamonds and the cycle then restarts from day 1 the next
-- claim. Resets to day 1 (not a lost streak) if the player skips a day OR
-- crosses into a new ISO week without having claimed - "weekly" per the
-- spec, so partial progress never carries across a week boundary.
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
        last_daily_claim_date = today
    WHERE id = u_id RETURNING * INTO profile_row;
  ELSE
    -- Day N pays N * 1000 GP (1000, 2000, ..., 6000) - compounding but
    -- simple, and small relative to match-day income so it can't be used
    -- to bypass the game's normal economy.
    gp_reward := next_day * 1000;
    IF club_row.id IS NOT NULL THEN
      UPDATE public.clubs SET budget = budget + gp_reward WHERE id = club_row.id;
      INSERT INTO public.financial_transactions(club_id, type, amount, description, source)
      VALUES (club_row.id, 'daily_login_reward', gp_reward, format('Günlük giriş ödülü (gün %s): +%s GP', next_day, gp_reward), 'claim_daily_login_reward');
    END IF;
    UPDATE public.profiles
    SET daily_streak_day = next_day,
        daily_streak_week_start = this_week_start,
        last_daily_claim_date = today
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

-- Social-media rewards. Following each platform is a one-time 20-diamond
-- claim per platform (client opens the link, then self-reports the tap -
-- there is no real API check yet, matching the spec's "will add these
-- accounts later" note). The combined like+comment engagement reward is a
-- single one-time 10-diamond claim (a stand-in "callback simulation"
-- until a real API/webhook exists to verify it server-side).
CREATE OR REPLACE FUNCTION public.claim_social_reward(p_platform TEXT)
RETURNS public.profiles AS $$
DECLARE
  u_id UUID := auth.uid();
  profile_row public.profiles%ROWTYPE;
BEGIN
  IF u_id IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated';
  END IF;

  SELECT * INTO profile_row FROM public.profiles WHERE id = u_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Profil bulunamadı';
  END IF;

  IF p_platform = 'instagram' THEN
    IF profile_row.social_instagram_followed THEN
      RAISE EXCEPTION 'Bu ödül zaten alındı.';
    END IF;
    UPDATE public.profiles SET social_instagram_followed = true, diamonds = diamonds + 20 WHERE id = u_id RETURNING * INTO profile_row;
  ELSIF p_platform = 'x' THEN
    IF profile_row.social_x_followed THEN
      RAISE EXCEPTION 'Bu ödül zaten alındı.';
    END IF;
    UPDATE public.profiles SET social_x_followed = true, diamonds = diamonds + 20 WHERE id = u_id RETURNING * INTO profile_row;
  ELSIF p_platform = 'tiktok' THEN
    IF profile_row.social_tiktok_followed THEN
      RAISE EXCEPTION 'Bu ödül zaten alındı.';
    END IF;
    UPDATE public.profiles SET social_tiktok_followed = true, diamonds = diamonds + 20 WHERE id = u_id RETURNING * INTO profile_row;
  ELSIF p_platform = 'engagement' THEN
    IF profile_row.social_engagement_claimed THEN
      RAISE EXCEPTION 'Bu ödül zaten alındı.';
    END IF;
    UPDATE public.profiles SET social_engagement_claimed = true, diamonds = diamonds + 10 WHERE id = u_id RETURNING * INTO profile_row;
  ELSE
    RAISE EXCEPTION 'Bilinmeyen platform.';
  END IF;

  RETURN profile_row;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Extends the existing club_id -> username lookup with the owner's
-- league_titles (used client-side to compute + render the level frame in
-- the standings table) - same narrow SECURITY DEFINER shape as before,
-- profiles RLS still only allows reading your own row directly.
DROP FUNCTION IF EXISTS public.get_club_owner_usernames(uuid[]);
CREATE FUNCTION public.get_club_owner_usernames(p_club_ids uuid[])
RETURNS TABLE(club_id uuid, username text, league_titles int) AS $$
  SELECT c.id, p.username, p.league_titles
  FROM public.clubs c
  JOIN public.profiles p ON p.id = c.user_id
  WHERE c.id = ANY(p_club_ids) AND p.username IS NOT NULL;
$$ LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE;

GRANT EXECUTE ON FUNCTION public.get_club_owner_usernames(uuid[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.claim_achievement_reward(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.claim_daily_login_reward(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.claim_social_reward(TEXT) TO authenticated;

-- Avatar upload: a public-read bucket (avatar URLs are shown to other
-- users in standings/profile), writes restricted to the owning user via
-- a folder-per-user-id convention (avatars/<uid>/<filename>).
INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "Avatar images are publicly accessible" ON storage.objects;
CREATE POLICY "Avatar images are publicly accessible"
ON storage.objects FOR SELECT
USING (bucket_id = 'avatars');

DROP POLICY IF EXISTS "Users can upload their own avatar" ON storage.objects;
CREATE POLICY "Users can upload their own avatar"
ON storage.objects FOR INSERT
WITH CHECK (bucket_id = 'avatars' AND (storage.foldername(name))[1] = auth.uid()::text);

DROP POLICY IF EXISTS "Users can update their own avatar" ON storage.objects;
CREATE POLICY "Users can update their own avatar"
ON storage.objects FOR UPDATE
USING (bucket_id = 'avatars' AND (storage.foldername(name))[1] = auth.uid()::text);

DROP POLICY IF EXISTS "Users can delete their own avatar" ON storage.objects;
CREATE POLICY "Users can delete their own avatar"
ON storage.objects FOR DELETE
USING (bucket_id = 'avatars' AND (storage.foldername(name))[1] = auth.uid()::text);
