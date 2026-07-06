-- CI trigger: update to force supabase_deploy.yml push
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS public.clubs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    league_id UUID REFERENCES public.leagues(id) ON DELETE SET NULL,
    name TEXT NOT NULL,
    budget BIGINT NOT NULL DEFAULT 10000000,
    blocked_budget BIGINT NOT NULL DEFAULT 0,
    stadium_capacity INT NOT NULL DEFAULT 15000,
    ticket_price INT NOT NULL DEFAULT 5,
    training_facility_level INT NOT NULL DEFAULT 1,
    sponsor_level INT NOT NULL DEFAULT 1,
    last_maintenance_date TIMESTAMPTZ,
    fans_count INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS clubs_user_id_unique_partial
ON public.clubs (user_id)
WHERE user_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS public.leagues (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    country TEXT,
    tier INT NOT NULL DEFAULT 1,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.seasons (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    league_id UUID NOT NULL REFERENCES public.leagues(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    start_date TIMESTAMPTZ NOT NULL DEFAULT now(),
    end_date TIMESTAMPTZ,
    current_week INT NOT NULL DEFAULT 1,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    is_completed BOOLEAN NOT NULL DEFAULT FALSE,
    champion_club_id UUID REFERENCES public.clubs(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.league_standings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    season_id UUID NOT NULL REFERENCES public.seasons(id) ON DELETE CASCADE,
    club_id UUID NOT NULL REFERENCES public.clubs(id) ON DELETE CASCADE,
    played INT NOT NULL DEFAULT 0,
    wins INT NOT NULL DEFAULT 0,
    draws INT NOT NULL DEFAULT 0,
    losses INT NOT NULL DEFAULT 0,
    goals_for INT NOT NULL DEFAULT 0,
    goals_against INT NOT NULL DEFAULT 0,
    goal_difference INT NOT NULL DEFAULT 0,
    points INT NOT NULL DEFAULT 0,
    position INT,
    promotion_zone BOOLEAN NOT NULL DEFAULT FALSE,
    relegation_zone BOOLEAN NOT NULL DEFAULT FALSE,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(season_id, club_id)
);

CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name TEXT,
    avatar_url TEXT,
    email TEXT,
    language TEXT DEFAULT 'tr',
    fcm_token TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.players (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    club_id UUID REFERENCES public.clubs(id) ON DELETE SET NULL,
    name TEXT NOT NULL,
    position TEXT NOT NULL DEFAULT 'ST',
    age INT NOT NULL DEFAULT 20,
    current_ability INT NOT NULL DEFAULT 50,
    potential_ability INT NOT NULL DEFAULT 75,
    form_rating NUMERIC(4,2) NOT NULL DEFAULT 0.00,
    fitness INT NOT NULL DEFAULT 100,
    morale INT NOT NULL DEFAULT 75,
    finishing INT NOT NULL DEFAULT 10,
    passing INT NOT NULL DEFAULT 10,
    tackling INT NOT NULL DEFAULT 10,
    composure INT NOT NULL DEFAULT 10,
    determination INT NOT NULL DEFAULT 10,
    consistency INT NOT NULL DEFAULT 10,
    injury_proneness INT NOT NULL DEFAULT 5,
    injury_duration_weeks INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    is_suspended BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE IF NOT EXISTS public.inbox_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    recipient_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.matches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    league_id UUID REFERENCES public.leagues(id) ON DELETE SET NULL,
    season_id UUID REFERENCES public.seasons(id) ON DELETE SET NULL,
    week INT NOT NULL,
    home_club_id UUID REFERENCES public.clubs(id) ON DELETE SET NULL,
    away_club_id UUID REFERENCES public.clubs(id) ON DELETE SET NULL,
    home_score INT,
    away_score INT,
    is_played BOOLEAN NOT NULL DEFAULT FALSE,
    match_date TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.match_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    match_id UUID NOT NULL REFERENCES public.matches(id) ON DELETE CASCADE,
    minute INT NOT NULL,
    event_type TEXT NOT NULL,
    club_id UUID REFERENCES public.clubs(id) ON DELETE SET NULL,
    player_id UUID REFERENCES public.players(id) ON DELETE SET NULL,
    assist_player_id UUID REFERENCES public.players(id) ON DELETE SET NULL,
    description TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.match_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS match_events_select_policy ON public.match_events;
CREATE POLICY match_events_select_policy ON public.match_events FOR SELECT TO authenticated
  USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS match_events_insert_policy ON public.match_events;
CREATE POLICY match_events_insert_policy ON public.match_events FOR INSERT TO authenticated
  USING (false);

DROP POLICY IF EXISTS match_events_update_policy ON public.match_events;
CREATE POLICY match_events_update_policy ON public.match_events FOR UPDATE TO authenticated
  USING (false);

DROP POLICY IF EXISTS match_events_delete_policy ON public.match_events;
CREATE POLICY match_events_delete_policy ON public.match_events FOR DELETE TO authenticated
  USING (false);

CREATE TABLE IF NOT EXISTS public.transfer_market (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    player_id UUID UNIQUE REFERENCES public.players(id) ON DELETE CASCADE,
    current_highest_bid BIGINT NOT NULL DEFAULT 0,
    highest_bidder_id UUID REFERENCES public.clubs(id) ON DELETE SET NULL,
    end_time TIMESTAMPTZ NOT NULL DEFAULT now() + interval '1 day',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.transfer_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    player_id UUID NOT NULL REFERENCES public.players(id) ON DELETE CASCADE,
    seller_club_id UUID REFERENCES public.clubs(id) ON DELETE SET NULL,
    buyer_club_id UUID REFERENCES public.clubs(id) ON DELETE SET NULL,
    price BIGINT NOT NULL,
    completed_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.financial_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    club_id UUID NOT NULL REFERENCES public.clubs(id) ON DELETE CASCADE,
    type TEXT NOT NULL,
    amount BIGINT NOT NULL,
    description TEXT NOT NULL,
    source TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.financial_transactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS financial_transactions_select_policy ON public.financial_transactions;
CREATE POLICY financial_transactions_select_policy ON public.financial_transactions FOR SELECT TO authenticated
  USING (
    club_id IN (
      SELECT id FROM public.clubs WHERE user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS financial_transactions_insert_policy ON public.financial_transactions;
CREATE POLICY financial_transactions_insert_policy ON public.financial_transactions FOR INSERT TO authenticated
  WITH CHECK (false);

DROP POLICY IF EXISTS financial_transactions_update_policy ON public.financial_transactions;
CREATE POLICY financial_transactions_update_policy ON public.financial_transactions FOR UPDATE TO authenticated
  USING (false);

DROP POLICY IF EXISTS financial_transactions_delete_policy ON public.financial_transactions;
CREATE POLICY financial_transactions_delete_policy ON public.financial_transactions FOR DELETE TO authenticated
  USING (false);

CREATE TABLE IF NOT EXISTS public.leaderboards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
    username TEXT NOT NULL,
    high_score INT NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.tactics (
    club_id UUID REFERENCES public.clubs(id) ON DELETE CASCADE PRIMARY KEY,
    formation TEXT NOT NULL DEFAULT 'f442',
    mentality TEXT NOT NULL DEFAULT 'balanced',
    captain_id UUID REFERENCES public.players(id) ON DELETE SET NULL,
    penalty_taker_id UUID REFERENCES public.players(id) ON DELETE SET NULL
);

ALTER TABLE public.clubs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.leagues ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.seasons ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.league_standings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.players ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.matches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transfer_market ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.leaderboards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inbox_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tactics ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS clubs_select_policy ON public.clubs;
CREATE POLICY clubs_select_policy ON public.clubs FOR SELECT TO authenticated USING (auth.uid() = user_id OR user_id IS NULL);

DROP POLICY IF EXISTS clubs_insert_policy ON public.clubs;
CREATE POLICY clubs_insert_policy ON public.clubs FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS clubs_update_policy ON public.clubs;
CREATE POLICY clubs_update_policy ON public.clubs FOR UPDATE TO authenticated USING (false);

DROP POLICY IF EXISTS players_select_policy ON public.players;
CREATE POLICY players_select_policy ON public.players FOR SELECT TO authenticated
  USING (
    club_id = (
      SELECT id FROM public.clubs WHERE user_id = auth.uid() LIMIT 1
    ) OR club_id IS NULL
  );

DROP POLICY IF EXISTS players_update_policy ON public.players;
CREATE POLICY players_update_policy ON public.players FOR UPDATE TO authenticated USING (false);

DROP POLICY IF EXISTS matches_select_policy ON public.matches;
CREATE POLICY matches_select_policy ON public.matches FOR SELECT TO authenticated
  USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS transfer_market_select_policy ON public.transfer_market;
CREATE POLICY transfer_market_select_policy ON public.transfer_market FOR SELECT TO authenticated
  USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS transfer_market_update_policy ON public.transfer_market;
CREATE POLICY transfer_market_update_policy ON public.transfer_market FOR UPDATE TO authenticated
  USING (false);

ALTER TABLE public.transfer_history ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS transfer_history_select_policy ON public.transfer_history;
CREATE POLICY transfer_history_select_policy ON public.transfer_history FOR SELECT TO authenticated
  USING (
    seller_club_id IN (
      SELECT id FROM public.clubs WHERE user_id = auth.uid()
    )
    OR buyer_club_id IN (
      SELECT id FROM public.clubs WHERE user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS profiles_insert_policy ON public.profiles;
CREATE POLICY profiles_insert_policy ON public.profiles FOR INSERT TO authenticated
  WITH CHECK (id = auth.uid());

DROP POLICY IF EXISTS profiles_select_policy ON public.profiles;
CREATE POLICY profiles_select_policy ON public.profiles FOR SELECT TO authenticated
  USING (id = auth.uid());

DROP POLICY IF EXISTS profiles_update_policy ON public.profiles;
CREATE POLICY profiles_update_policy ON public.profiles FOR UPDATE TO authenticated
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

DROP POLICY IF EXISTS inbox_messages_select_policy ON public.inbox_messages;
CREATE POLICY inbox_messages_select_policy ON public.inbox_messages FOR SELECT TO authenticated
  USING (recipient_id = auth.uid());

DROP POLICY IF EXISTS inbox_messages_insert_policy ON public.inbox_messages;
CREATE POLICY inbox_messages_insert_policy ON public.inbox_messages FOR INSERT TO authenticated
  WITH CHECK (recipient_id = auth.uid());

DROP POLICY IF EXISTS inbox_messages_update_policy ON public.inbox_messages;
CREATE POLICY inbox_messages_update_policy ON public.inbox_messages FOR UPDATE TO authenticated
  USING (recipient_id = auth.uid())
  WITH CHECK (recipient_id = auth.uid());

DROP POLICY IF EXISTS inbox_messages_delete_policy ON public.inbox_messages;
CREATE POLICY inbox_messages_delete_policy ON public.inbox_messages FOR DELETE TO authenticated
  USING (recipient_id = auth.uid());

DROP POLICY IF EXISTS tactics_select_policy ON public.tactics;
CREATE POLICY tactics_select_policy ON public.tactics FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.clubs c
      WHERE c.id = tactics.club_id
        AND c.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS tactics_insert_policy ON public.tactics;
CREATE POLICY tactics_insert_policy ON public.tactics FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.clubs c
      WHERE c.id = club_id
        AND c.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS tactics_update_policy ON public.tactics;
CREATE POLICY tactics_update_policy ON public.tactics FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.clubs c
      WHERE c.id = tactics.club_id
        AND c.user_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.clubs c
      WHERE c.id = club_id
        AND c.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS tactics_delete_policy ON public.tactics;
CREATE POLICY tactics_delete_policy ON public.tactics FOR DELETE TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.clubs c
      WHERE c.id = tactics.club_id
        AND c.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS leaderboards_select_policy ON public.leaderboards;
CREATE POLICY leaderboards_select_policy ON public.leaderboards FOR SELECT TO authenticated USING (auth.uid() = user_id);

DROP POLICY IF EXISTS leaderboards_insert_policy ON public.leaderboards;
CREATE POLICY leaderboards_insert_policy ON public.leaderboards FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS leaderboards_update_policy ON public.leaderboards;
CREATE POLICY leaderboards_update_policy ON public.leaderboards FOR UPDATE TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE OR REPLACE FUNCTION public.create_season(p_league_id UUID, p_name TEXT, p_start_date TIMESTAMPTZ DEFAULT now())
RETURNS public.seasons AS $$
DECLARE
  new_season public.seasons;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated user cannot create a season';
  END IF;

  INSERT INTO public.seasons (league_id, name, start_date, current_week, is_active)
  VALUES (p_league_id, p_name, p_start_date, 1, TRUE)
  RETURNING * INTO new_season;

  RETURN new_season;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, row_security = off;

CREATE OR REPLACE FUNCTION public.generate_weekly_fixtures(p_season_id UUID, p_week INT)
RETURNS void AS $$
DECLARE
  season_row public.seasons%ROWTYPE;
  club_rows RECORD;
  home_club UUID;
  away_club UUID;
  clubs_for_week UUID[];
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated user cannot generate fixtures';
  END IF;

  SELECT * INTO season_row FROM public.seasons WHERE id = p_season_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Season not found';
  END IF;

  SELECT array_agg(id ORDER BY random()) INTO clubs_for_week
  FROM public.clubs
  WHERE league_id = season_row.league_id;

  IF clubs_for_week IS NULL OR array_length(clubs_for_week, 1) < 2 THEN
    RETURN;
  END IF;

  FOR home_club IN SELECT unnest(clubs_for_week) LOOP
    FOR away_club IN SELECT unnest(clubs_for_week) LOOP
      IF home_club = away_club THEN
        CONTINUE;
      END IF;
      INSERT INTO public.matches (league_id, season_id, week, home_club_id, away_club_id, match_date)
      VALUES (season_row.league_id, season_row.id, p_week, home_club, away_club, season_row.start_date + (p_week - 1) * interval '7 days');
    END LOOP;
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, row_security = off;

CREATE OR REPLACE FUNCTION public.advance_player_development(
  p_player_id UUID,
  p_minutes_played INT DEFAULT 90,
  p_training_facility_level INT DEFAULT 1,
  p_morale INT DEFAULT 75,
  p_form_rating DOUBLE PRECISION DEFAULT 0.0
)
RETURNS public.players AS $$
DECLARE
  player_row public.players%ROWTYPE;
  age_factor DOUBLE PRECISION;
  potential_factor DOUBLE PRECISION;
  training_factor DOUBLE PRECISION;
  minutes_factor DOUBLE PRECISION;
  morale_factor DOUBLE PRECISION;
  form_factor DOUBLE PRECISION;
  growth_delta INT;
  new_current_ability INT;
  new_fitness INT;
  new_morale INT;
  new_form_rating DOUBLE PRECISION;
BEGIN
  SELECT * INTO player_row FROM public.players WHERE id = p_player_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Player not found';
  END IF;

  IF player_row.age < 16 THEN
    age_factor := 0.85;
  ELSIF player_row.age BETWEEN 16 AND 23 THEN
    age_factor := 1.25;
  ELSIF player_row.age BETWEEN 24 AND 29 THEN
    age_factor := 0.95;
  ELSE
    age_factor := 0.75;
  END IF;

  potential_factor := (player_row.potential_ability / 100.0) * 0.9;
  training_factor := GREATEST(1, p_training_facility_level) * 0.6;
  minutes_factor := LEAST(1.0, GREATEST(0.0, p_minutes_played::DOUBLE PRECISION / 180.0));
  morale_factor := 1.0 + ((p_morale - 75) / 100.0) * 0.15;
  form_factor := 1.0 + (COALESCE(p_form_rating, 0.0) / 100.0) * 0.1;

  growth_delta := ROUND((8.0 + (player_row.potential_ability - player_row.current_ability) * 0.02) * age_factor * potential_factor * training_factor * minutes_factor * morale_factor * form_factor);
  new_current_ability := LEAST(99, GREATEST(1, player_row.current_ability + growth_delta));
  new_fitness := LEAST(100, GREATEST(40, player_row.fitness + ROUND(growth_delta * 0.15)));
  new_morale := LEAST(100, GREATEST(30, player_row.morale + ROUND(growth_delta * 0.03)));
  new_form_rating := LEAST(100.0, GREATEST(0.0, player_row.form_rating + (growth_delta * 0.15)));

  UPDATE public.players
  SET current_ability = new_current_ability,
      fitness = new_fitness,
      morale = new_morale,
      form_rating = new_form_rating
  WHERE id = p_player_id
  RETURNING * INTO player_row;

  RETURN player_row;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, row_security = off;

-- Table to record rewarded ad awards (server-side ledger)
CREATE TABLE IF NOT EXISTS public.ad_rewards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    reward_type TEXT NOT NULL,
    amount BIGINT,
    data JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.ad_rewards ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS ad_rewards_select_policy ON public.ad_rewards;
CREATE POLICY ad_rewards_select_policy ON public.ad_rewards FOR SELECT TO authenticated
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS ad_rewards_insert_policy ON public.ad_rewards;
CREATE POLICY ad_rewards_insert_policy ON public.ad_rewards FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

-- RPC: Award an ad reward to the authenticated user with server-side rate limiting
CREATE OR REPLACE FUNCTION public.award_ad_reward(p_reward_type TEXT, p_amount BIGINT DEFAULT NULL)
RETURNS JSONB AS $$
DECLARE
  u_id UUID := auth.uid();
  last_time TIMESTAMPTZ;
  result JSONB;
  club_row public.clubs%ROWTYPE;
BEGIN
  IF u_id IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated';
  END IF;

  SELECT created_at INTO last_time FROM public.ad_rewards WHERE user_id = u_id ORDER BY created_at DESC LIMIT 1;

  -- Frequency limit: 15 minutes between rewarded ad awards
  IF last_time IS NOT NULL AND now() - last_time < interval '15 minutes' THEN
    result := jsonb_build_object('awarded', false, 'reason', 'rate_limited');
    RETURN result;
  END IF;

  INSERT INTO public.ad_rewards(user_id, reward_type, amount)
  VALUES (u_id, p_reward_type, p_amount);

  IF p_reward_type = 'extra_para' THEN
    IF p_amount IS NULL THEN
      p_amount := 100000; -- default amount if not specified
    END IF;
    UPDATE public.clubs SET budget = budget + p_amount WHERE user_id = u_id RETURNING id, budget INTO club_row;
    INSERT INTO public.financial_transactions(club_id, type, amount, description, source)
    VALUES (club_row.id, 'ad_reward', p_amount, format('Reklam ödülü: +%s GP', p_amount), 'award_ad_reward');
  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, row_security = off;

CREATE OR REPLACE FUNCTION public.update_standings_after_match(p_match_id UUID)
RETURNS void AS $$
DECLARE
  match_row public.matches%ROWTYPE;
  home_row public.league_standings%ROWTYPE;
  away_row public.league_standings%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated user cannot update standings';
  END IF;

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
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, row_security = off;

CREATE OR REPLACE FUNCTION public.place_transfer_bid(market_id UUID, bid_amount BIGINT)
RETURNS public.transfer_market AS $$
DECLARE
  bidder_club_id UUID;
  bidder_budget BIGINT;
  bidder_blocked BIGINT;
  seller_club_id UUID;
  current_bid BIGINT;
  current_bidder_id UUID;
  available_budget BIGINT;
  bid_difference BIGINT;
  updated_row public.transfer_market;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated user cannot place bid';
  END IF;

  SELECT id, budget, blocked_budget INTO bidder_club_id, bidder_budget, bidder_blocked
  FROM public.clubs
  WHERE user_id = auth.uid()
  LIMIT 1;

  IF bidder_club_id IS NULL THEN
    RAISE EXCEPTION 'User does not own a club';
  END IF;

  SELECT tm.current_highest_bid, tm.highest_bidder_id, p.club_id
  INTO current_bid, current_bidder_id, seller_club_id
  FROM public.transfer_market tm
  JOIN public.players p ON p.id = tm.player_id
  WHERE tm.id = market_id
    AND tm.end_time > now();

  IF seller_club_id IS NULL THEN
    RAISE EXCEPTION 'Transfer market listing not found or has expired';
  END IF;

  IF seller_club_id = bidder_club_id THEN
    RAISE EXCEPTION 'Cannot bid on your own club player';
  END IF;

  IF bid_amount <= current_bid THEN
    RAISE EXCEPTION 'Bid must be higher than the current highest bid';
  END IF;

  IF current_bidder_id = bidder_club_id THEN
    available_budget := bidder_budget - bidder_blocked + current_bid;
  ELSE
    available_budget := bidder_budget - bidder_blocked;
  END IF;

  IF available_budget < bid_amount THEN
    RAISE EXCEPTION 'Insufficient available budget to place bid';
  END IF;

  UPDATE public.transfer_market
  SET current_highest_bid = bid_amount,
      highest_bidder_id = bidder_club_id
  WHERE id = market_id
    AND current_highest_bid = current_bid
    AND end_time > now()
  RETURNING * INTO updated_row;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Bid could not be placed. Please try again.';
  END IF;

  IF current_bidder_id IS NOT NULL AND current_bidder_id != bidder_club_id THEN
    UPDATE public.clubs
    SET blocked_budget = GREATEST(0, blocked_budget - current_bid)
    WHERE id = current_bidder_id;
  END IF;

  IF current_bidder_id = bidder_club_id THEN
    bid_difference := bid_amount - current_bid;
    UPDATE public.clubs
    SET blocked_budget = blocked_budget + bid_difference
    WHERE id = bidder_club_id;
  ELSE
    UPDATE public.clubs
    SET blocked_budget = blocked_budget + bid_amount
    WHERE id = bidder_club_id;
  END IF;

  RETURN updated_row;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, row_security = off;

CREATE OR REPLACE FUNCTION public.accept_transfer_offer(p_player_id UUID)
RETURNS public.clubs AS $$
DECLARE
  seller_club_id UUID;
  buyer_club_id UUID;
  bid_amount BIGINT;
  seller_club public.clubs%ROWTYPE;
  buyer_club public.clubs%ROWTYPE;
  updated_row public.clubs;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated user cannot accept transfer offer';
  END IF;

  SELECT club_id INTO seller_club_id
  FROM public.players
  WHERE id = p_player_id;

  IF seller_club_id IS NULL THEN
    RAISE EXCEPTION 'Player must belong to a club to accept offers';
  END IF;

  SELECT * INTO seller_club
  FROM public.clubs
  WHERE id = seller_club_id
    AND user_id = auth.uid();

  IF NOT FOUND THEN
    RAISE EXCEPTION 'User does not own the selling club';
  END IF;

  SELECT current_highest_bid, highest_bidder_id INTO bid_amount, buyer_club_id
  FROM public.transfer_market
  WHERE player_id = p_player_id
    AND end_time > now();

  IF buyer_club_id IS NULL OR bid_amount <= 0 THEN
    RAISE EXCEPTION 'No active transfer offer exists for this player';
  END IF;

  IF buyer_club_id = seller_club_id THEN
    RAISE EXCEPTION 'Cannot accept a bid from the same club';
  END IF;

  SELECT * INTO buyer_club
  FROM public.clubs
  WHERE id = buyer_club_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Buyer club not found';
  END IF;

  IF buyer_club.budget < bid_amount THEN
    RAISE EXCEPTION 'Buyer club has insufficient budget';
  END IF;

  IF buyer_club.blocked_budget < bid_amount THEN
    RAISE EXCEPTION 'Buyer club has insufficient reserved funds to complete transfer';
  END IF;

  UPDATE public.clubs
  SET budget = budget + bid_amount
  WHERE id = seller_club_id;

  UPDATE public.clubs
  SET budget = budget - bid_amount,
      blocked_budget = GREATEST(0, blocked_budget - bid_amount)
  WHERE id = buyer_club_id;

  INSERT INTO public.financial_transactions(club_id, type, amount, description, source)
  VALUES
    (seller_club_id, 'transfer_revenue', bid_amount, format('Transfer geliri: %s GP', bid_amount), 'accept_transfer_offer'),
    (buyer_club_id, 'transfer_cost', -bid_amount, format('Transfer satın alım maliyeti: -%s GP', bid_amount), 'accept_transfer_offer');

  UPDATE public.players
  SET club_id = buyer_club_id
  WHERE id = p_player_id;

  INSERT INTO public.transfer_history (player_id, seller_club_id, buyer_club_id, price)
  VALUES (p_player_id, seller_club_id, buyer_club_id, bid_amount);

  DELETE FROM public.transfer_market
  WHERE player_id = p_player_id;

  SELECT * INTO updated_row
  FROM public.clubs
  WHERE id = seller_club_id;

  RETURN updated_row;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, row_security = off;

CREATE OR REPLACE FUNCTION public.release_expired_transfer_bids()
RETURNS void AS $$
DECLARE
  expired_record RECORD;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated user cannot release expired bids';
  END IF;

  FOR expired_record IN
    SELECT id, current_highest_bid, highest_bidder_id
    FROM public.transfer_market
    WHERE end_time <= now()
  LOOP
    IF expired_record.highest_bidder_id IS NOT NULL THEN
      UPDATE public.clubs
      SET blocked_budget = GREATEST(0, blocked_budget - expired_record.current_highest_bid)
      WHERE id = expired_record.highest_bidder_id;
    END IF;

    DELETE FROM public.transfer_market
    WHERE id = expired_record.id;
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, row_security = off;

CREATE OR REPLACE FUNCTION public.upgrade_club(
  club_id UUID,
  stadium_capacity INT,
  training_facility_level INT,
  ticket_price INT
)
RETURNS public.clubs AS $$
DECLARE
  current_club public.clubs%ROWTYPE;
  total_cost BIGINT := 0;
  updated_row public.clubs;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated user cannot upgrade club';
  END IF;

  SELECT * INTO current_club
  FROM public.clubs
  WHERE id = club_id
    AND user_id = auth.uid();

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Club not found or not owned by current user';
  END IF;

  IF stadium_capacity IS NOT NULL AND stadium_capacity > current_club.stadium_capacity THEN
    IF stadium_capacity > 100000 THEN
      RAISE EXCEPTION 'Stadium capacity cannot exceed 100000';
    END IF;
    total_cost := total_cost + 1000 + (stadium_capacity / 1000);
  END IF;

  IF training_facility_level IS NOT NULL THEN
    IF training_facility_level <= current_club.training_facility_level THEN
      RAISE EXCEPTION 'Training facility level must be higher than current level';
    END IF;
    IF training_facility_level > 10 THEN
      RAISE EXCEPTION 'Training facility level cannot exceed 10';
    END IF;
    total_cost := total_cost + 2000 + (training_facility_level * 1500);
  END IF;

  IF ticket_price IS NOT NULL THEN
    IF ticket_price <= current_club.ticket_price THEN
      RAISE EXCEPTION 'Ticket price must be higher than current price';
    END IF;
    total_cost := total_cost + 500;
  END IF;

  IF current_club.budget < total_cost THEN
    RAISE EXCEPTION 'Not enough budget for upgrade';
  END IF;

  UPDATE public.clubs
  SET budget = current_club.budget - total_cost,
      stadium_capacity = COALESCE(stadium_capacity, current_club.stadium_capacity),
      training_facility_level = COALESCE(training_facility_level, current_club.training_facility_level),
      ticket_price = COALESCE(ticket_price, current_club.ticket_price)
  WHERE id = club_id
  RETURNING * INTO updated_row;

  INSERT INTO public.financial_transactions(club_id, type, amount, description, source)
  VALUES (
    club_id,
    'upgrade_club',
    -total_cost,
    format('Kulüp yükseltme harcaması: -%s GP', total_cost),
    'upgrade_club'
  );

  RETURN updated_row;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, row_security = off;

CREATE OR REPLACE FUNCTION public.upgrade_sponsor(club_id UUID)
RETURNS public.clubs AS $$
DECLARE
  current_club public.clubs%ROWTYPE;
  updated_row public.clubs;
  new_budget BIGINT;
  new_sponsor_level INT;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated user cannot upgrade sponsor';
  END IF;

  SELECT * INTO current_club
  FROM public.clubs
  WHERE id = club_id
    AND user_id = auth.uid();

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Club not found or not owned by current user';
  END IF;

  IF current_club.sponsor_level >= 5 THEN
    RAISE EXCEPTION 'Sponsor level cannot exceed 5';
  END IF;

  new_sponsor_level := current_club.sponsor_level + 1;
  new_budget := current_club.budget - (5000 * current_club.sponsor_level);

  IF new_budget < 0 THEN
    RAISE EXCEPTION 'Not enough budget to upgrade sponsor';
  END IF;

  UPDATE public.clubs
  SET budget = new_budget,
      sponsor_level = new_sponsor_level
  WHERE id = club_id
  RETURNING * INTO updated_row;

  INSERT INTO public.financial_transactions(club_id, type, amount, description, source)
  VALUES (
    club_id,
    'upgrade_sponsor',
    -(5000 * current_club.sponsor_level),
    format('Sponsor yükseltme harcaması: -%s GP', 5000 * current_club.sponsor_level),
    'upgrade_sponsor'
  );

  RETURN updated_row;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, row_security = off;

CREATE OR REPLACE FUNCTION public.claim_club(club_id UUID)
RETURNS public.clubs AS $$
DECLARE
  updated_row public.clubs;
  current_user_id UUID := auth.uid();
  owned_club_id UUID;
BEGIN
  IF current_user_id IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated user cannot claim club';
  END IF;

  SELECT id INTO owned_club_id
  FROM public.clubs
  WHERE user_id = current_user_id
  LIMIT 1;

  IF FOUND THEN
    RAISE EXCEPTION 'Bu kullanıcı zaten bir kulübe sahip.';
  END IF;

  UPDATE public.clubs
  SET user_id = current_user_id
  WHERE id = club_id
    AND user_id IS NULL
  RETURNING * INTO updated_row;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Kulüp bulunamadı veya zaten sahiplenilmiş.';
  END IF;

  RETURN updated_row;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, row_security = off;

CREATE OR REPLACE FUNCTION public.assign_club_to_new_user()
RETURNS trigger AS $$
BEGIN
  IF TG_OP IS NULL THEN
    RAISE EXCEPTION 'This function may only be called as a trigger';
  END IF;

  UPDATE public.clubs
  SET user_id = NEW.id
  WHERE id = (
    SELECT id
    FROM public.clubs
    WHERE user_id IS NULL
    ORDER BY id
    LIMIT 1
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, row_security = off;

DROP TRIGGER IF EXISTS assign_club_to_new_user_trigger ON auth.users;
CREATE TRIGGER assign_club_to_new_user_trigger
AFTER INSERT ON auth.users
FOR EACH ROW
EXECUTE FUNCTION public.assign_club_to_new_user();
