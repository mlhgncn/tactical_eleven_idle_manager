-- Weekly quest system: 3 rotating quests per user per week (play matches,
-- win matches, develop players), GP/diamond reward on completion.
--
-- Design: a static pool of quest definitions + a per-user/per-week
-- progress table. Which 3 quests are "this week's" is deterministic (hash
-- of user_id + week_start against the pool) rather than stored separately,
-- so there's no need for a cron job to "roll" quests - get_or_init_weekly_
-- quests just lazily creates progress rows for the current week's 3 picks
-- the first time a user is seen that week. No reset cron needed either:
-- a new week_start naturally has no rows yet, so old weeks' rows are just
-- left in place as history (useful for a future "quests completed"
-- stat), and RLS/queries only ever look at the current week_start.

CREATE TABLE IF NOT EXISTS public.weekly_quest_definitions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  quest_key TEXT NOT NULL UNIQUE,
  metric TEXT NOT NULL, -- 'play_matches' | 'win_matches' | 'develop_players'
  target INT NOT NULL,
  gp_reward BIGINT NOT NULL DEFAULT 0,
  diamond_reward INT NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT true
);

CREATE TABLE IF NOT EXISTS public.user_quest_progress (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  quest_key TEXT NOT NULL REFERENCES public.weekly_quest_definitions(quest_key),
  week_start DATE NOT NULL,
  progress INT NOT NULL DEFAULT 0,
  target INT NOT NULL,
  claimed BOOLEAN NOT NULL DEFAULT false,
  completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, quest_key, week_start)
);

CREATE INDEX IF NOT EXISTS idx_user_quest_progress_user_week ON public.user_quest_progress(user_id, week_start);

ALTER TABLE public.weekly_quest_definitions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_quest_progress ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS weekly_quest_definitions_select_policy ON public.weekly_quest_definitions;
CREATE POLICY weekly_quest_definitions_select_policy ON public.weekly_quest_definitions
FOR SELECT USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS user_quest_progress_select_policy ON public.user_quest_progress;
CREATE POLICY user_quest_progress_select_policy ON public.user_quest_progress
FOR SELECT USING (user_id = auth.uid());

-- Seed pool - 6 definitions to pick 3 from per week. Numbers are modest
-- (a "week" of a typical idle-manager cadence is a handful of matches),
-- rewards scaled roughly to the daily-login-reward diamond pace (day 7 of
-- that gives 1 diamond) so weekly quests feel like a meaningfully bigger
-- but still occasional bonus.
INSERT INTO public.weekly_quest_definitions (quest_key, metric, target, gp_reward, diamond_reward) VALUES
  ('play_3_matches', 'play_matches', 3, 1500, 0),
  ('play_7_matches', 'play_matches', 7, 3000, 1),
  ('win_2_matches', 'win_matches', 2, 2000, 1),
  ('win_5_matches', 'win_matches', 5, 5000, 2),
  ('develop_2_players', 'develop_players', 2, 1500, 0),
  ('develop_5_players', 'develop_players', 5, 4000, 2)
ON CONFLICT (quest_key) DO NOTHING;

-- Increments progress for whichever of the caller's currently-assigned
-- weekly quests match [p_metric], capping at target and stamping
-- completed_at the moment it's first reached. Safe to call even if the
-- user has no row yet for that quest this week (nothing to increment) -
-- callers (match/development resolution) don't need to know whether the
-- user has that quest active.
CREATE OR REPLACE FUNCTION public.increment_weekly_quest_progress(p_user_id UUID, p_metric TEXT, p_amount INT DEFAULT 1)
RETURNS void AS $$
BEGIN
  UPDATE public.user_quest_progress uqp
  SET progress = LEAST(uqp.target, uqp.progress + p_amount),
      completed_at = CASE WHEN uqp.completed_at IS NULL AND LEAST(uqp.target, uqp.progress + p_amount) >= uqp.target THEN now() ELSE uqp.completed_at END
  FROM public.weekly_quest_definitions wqd
  WHERE uqp.quest_key = wqd.quest_key
    AND uqp.user_id = p_user_id
    AND wqd.metric = p_metric
    AND uqp.week_start = date_trunc('week', now())::date
    AND uqp.progress < uqp.target;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Deterministically picks this week's 3 quests for the caller (same
-- formula every call, so no separate "assignment" step is needed), lazily
-- inserts progress rows for any that don't exist yet, and returns the
-- current week's full set with progress.
CREATE OR REPLACE FUNCTION public.get_or_init_weekly_quests()
RETURNS TABLE(
  quest_key TEXT,
  metric TEXT,
  target INT,
  gp_reward BIGINT,
  diamond_reward INT,
  progress INT,
  claimed BOOLEAN,
  completed_at TIMESTAMPTZ
) AS $$
DECLARE
  this_week DATE := date_trunc('week', now())::date;
  pool_size INT;
  seed INT;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated user cannot load weekly quests';
  END IF;

  SELECT count(*) INTO pool_size FROM public.weekly_quest_definitions WHERE is_active;
  seed := abs(hashtext(auth.uid()::text || this_week::text));

  INSERT INTO public.user_quest_progress AS uqp (user_id, quest_key, week_start, target)
  SELECT auth.uid(), picked.quest_key, this_week, picked.target
  FROM (
    SELECT wqd.quest_key, wqd.target,
      row_number() OVER (ORDER BY (hashtext(wqd.quest_key || seed::text))) AS rn
    FROM public.weekly_quest_definitions wqd
    WHERE wqd.is_active
  ) picked
  WHERE picked.rn <= LEAST(3, pool_size)
  ON CONFLICT ON CONSTRAINT user_quest_progress_user_id_quest_key_week_start_key DO NOTHING;

  RETURN QUERY
  SELECT wqd.quest_key, wqd.metric, wqd.target, wqd.gp_reward, wqd.diamond_reward,
         uqp.progress, uqp.claimed, uqp.completed_at
  FROM public.user_quest_progress uqp
  JOIN public.weekly_quest_definitions wqd ON wqd.quest_key = uqp.quest_key
  WHERE uqp.user_id = auth.uid() AND uqp.week_start = this_week
  ORDER BY wqd.target;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Pays out a completed-but-unclaimed weekly quest, same idempotency
-- pattern as claim_achievement_reward/claim_daily_login_reward: row lock,
-- completion + not-already-claimed guard, then GP to the caller's active
-- club (if any) and/or diamonds to the profile.
CREATE OR REPLACE FUNCTION public.claim_weekly_quest_reward(p_quest_key TEXT, p_club_id UUID DEFAULT NULL)
RETURNS jsonb AS $$
DECLARE
  this_week DATE := date_trunc('week', now())::date;
  progress_row public.user_quest_progress%ROWTYPE;
  quest_row public.weekly_quest_definitions%ROWTYPE;
  target_club_id UUID;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated user cannot claim a quest reward';
  END IF;

  SELECT * INTO progress_row
  FROM public.user_quest_progress
  WHERE user_id = auth.uid() AND quest_key = p_quest_key AND week_start = this_week
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Bu görev bu hafta için atanmamış.';
  END IF;
  IF progress_row.progress < progress_row.target THEN
    RAISE EXCEPTION 'Görev henüz tamamlanmadı.';
  END IF;
  IF progress_row.claimed THEN
    RAISE EXCEPTION 'Bu görevin ödülü zaten alındı.';
  END IF;

  SELECT * INTO quest_row FROM public.weekly_quest_definitions WHERE quest_key = p_quest_key;

  UPDATE public.user_quest_progress SET claimed = true WHERE id = progress_row.id;

  IF quest_row.gp_reward > 0 THEN
    IF p_club_id IS NOT NULL THEN
      SELECT id INTO target_club_id FROM public.clubs WHERE id = p_club_id AND user_id = auth.uid();
    ELSE
      SELECT id INTO target_club_id FROM public.clubs WHERE user_id = auth.uid() LIMIT 1;
    END IF;

    IF target_club_id IS NOT NULL THEN
      UPDATE public.clubs SET budget = budget + quest_row.gp_reward WHERE id = target_club_id;
      INSERT INTO public.financial_transactions(club_id, type, amount, description, source)
      VALUES (target_club_id, 'income', quest_row.gp_reward, format('Haftalık görev ödülü: +%s GP', quest_row.gp_reward), 'weekly_quest');
    END IF;
  END IF;

  IF quest_row.diamond_reward > 0 THEN
    UPDATE public.profiles SET diamonds = diamonds + quest_row.diamond_reward WHERE id = auth.uid();
  END IF;

  RETURN jsonb_build_object('gp_awarded', quest_row.gp_reward, 'diamonds_awarded', quest_row.diamond_reward);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- process_player_development: bump the develop_players weekly quest for
-- each player's owner as their development completes.
CREATE OR REPLACE FUNCTION public.process_player_development()
RETURNS void AS $$
DECLARE
  player_row public.players%ROWTYPE;
  growth_percent DOUBLE PRECISION;
  growth_delta INT;
  new_current_ability INT;
  owner_id UUID;
  proximity_ratio NUMERIC;
  diminishing_factor NUMERIC;
BEGIN
  FOR player_row IN
    SELECT * FROM public.players
    WHERE development_completes_at IS NOT NULL AND development_completes_at <= now()
  LOOP
    proximity_ratio := player_row.current_ability::numeric / GREATEST(1, player_row.potential_ability);
    diminishing_factor := CASE
      WHEN proximity_ratio < 0.9 THEN 1.0
      ELSE GREATEST(0.1, 1.0 - (proximity_ratio - 0.9) * 9.0)
    END;

    growth_percent := (0.01 + random() * 0.02) * diminishing_factor;
    growth_delta := GREATEST(1, ROUND(player_row.current_ability * growth_percent));
    new_current_ability := LEAST(player_row.potential_ability, player_row.current_ability + growth_delta);

    UPDATE public.players
    SET current_ability = new_current_ability,
        development_completes_at = NULL,
        development_ad_uses = 0
    WHERE id = player_row.id;

    IF player_row.club_id IS NOT NULL THEN
      SELECT user_id INTO owner_id FROM public.clubs WHERE id = player_row.club_id;
      IF owner_id IS NOT NULL THEN
        INSERT INTO public.inbox_messages(recipient_id, club_id, title, body, is_read, created_at)
        VALUES (
          owner_id,
          player_row.club_id,
          'Oyuncu Gelişimi',
          format('%s gelişimini tamamladı! Yeni güç: %s (+%s)', player_row.name, new_current_ability, new_current_ability - player_row.current_ability),
          false,
          now()
        );
        PERFORM public.increment_weekly_quest_progress(owner_id, 'develop_players', 1);
      END IF;
    END IF;
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT SELECT ON public.weekly_quest_definitions TO authenticated;
GRANT SELECT ON public.user_quest_progress TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_or_init_weekly_quests() TO authenticated;
GRANT EXECUTE ON FUNCTION public.claim_weekly_quest_reward(TEXT, UUID) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.increment_weekly_quest_progress(UUID, TEXT, INT) FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION public.process_player_development() TO authenticated, service_role;
