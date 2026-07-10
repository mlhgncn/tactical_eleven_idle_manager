-- CI trigger: update to force supabase_deploy.yml push
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- leagues must be created before clubs, since clubs.league_id references it
-- (this table order was previously reversed, which meant a fresh install of
-- this file would fail with "relation public.leagues does not exist").
CREATE TABLE IF NOT EXISTS public.leagues (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    country TEXT,
    tier INT NOT NULL DEFAULT 1,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

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
  WITH CHECK (false);

DROP POLICY IF EXISTS match_events_update_policy ON public.match_events;
CREATE POLICY match_events_update_policy ON public.match_events FOR UPDATE TO authenticated
  USING (false);

DROP POLICY IF EXISTS match_events_delete_policy ON public.match_events;
CREATE POLICY match_events_delete_policy ON public.match_events FOR DELETE TO authenticated
  USING (false);

-- Auction bidding (current_highest_bid/highest_bidder_id/end_time) is gone
-- - transfer_market is now just a "listed for transfer" marker with a
-- reference asking price; real negotiation happens via transfer_offers.
-- CREATE TABLE IF NOT EXISTS is a no-op against an existing table, so this
-- shape only matters for a genuinely fresh install (where the migrations
-- in supabase/migrations/ still replay in order and converge here anyway).
CREATE TABLE IF NOT EXISTS public.transfer_market (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    player_id UUID UNIQUE REFERENCES public.players(id) ON DELETE CASCADE,
    asking_price BIGINT NOT NULL DEFAULT 0,
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

-- Any authenticated user can see any club (needed to show opponent/rival
-- club names in league standings, fixtures, and match history) - mutations
-- stay locked down to the owner via the insert/update policies below.
DROP POLICY IF EXISTS clubs_select_policy ON public.clubs;
CREATE POLICY clubs_select_policy ON public.clubs FOR SELECT TO authenticated USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS clubs_insert_policy ON public.clubs;
CREATE POLICY clubs_insert_policy ON public.clubs FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS clubs_update_policy ON public.clubs;
CREATE POLICY clubs_update_policy ON public.clubs FOR UPDATE TO authenticated USING (false);

-- leagues/seasons/league_standings had RLS enabled above with no SELECT
-- policy at all, which silently returned zero rows for every user (no
-- error) - the league table, season name/week, and standings all appeared
-- permanently empty regardless of how much data existed.
DROP POLICY IF EXISTS leagues_select_policy ON public.leagues;
CREATE POLICY leagues_select_policy ON public.leagues FOR SELECT TO authenticated USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS seasons_select_policy ON public.seasons;
CREATE POLICY seasons_select_policy ON public.seasons FOR SELECT TO authenticated USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS league_standings_select_policy ON public.league_standings;
CREATE POLICY league_standings_select_policy ON public.league_standings FOR SELECT TO authenticated USING (auth.uid() IS NOT NULL);

-- club_id = own club OR club_id IS NULL used to be the whole policy, which
-- blocked reading ANY other club's player - not just their name on a
-- rival's squad screen, but the entire embedded `players` object on every
-- transfer market listing that wasn't the user's own (PostgREST nulls the
-- whole embed when the embedded row fails RLS), so listed players showed
-- neither a name nor a seller club. Also allow reading a player that's
-- currently listed on the transfer market, since browsing the market
-- fundamentally requires seeing other clubs' listed players.
DROP POLICY IF EXISTS players_select_policy ON public.players;
CREATE POLICY players_select_policy ON public.players FOR SELECT TO authenticated
  USING (
    club_id IS NULL
    OR club_id = (SELECT id FROM public.clubs WHERE user_id = auth.uid() LIMIT 1)
    OR EXISTS (SELECT 1 FROM public.transfer_market tm WHERE tm.player_id = players.id)
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
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

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
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- advance_player_development (the old synchronous instant-growth RPC) is
-- gone - player development is now a timed session, see
-- start_player_development/process_player_development in
-- supabase/migrations/20260709191004_simplify_player_development_random_growth.sql.
-- Kept out of this baseline file on purpose: schema.sql is executed
-- unconditionally on every CI deploy (unlike supabase/migrations/*.sql,
-- which is only applied once per file), so leaving a stale CREATE OR
-- REPLACE here would silently resurrect dead/superseded functions after
-- every push - see the sponsor/club upgrade fix below for a case where
-- that already happened for real.

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
  END IF;

  result := jsonb_build_object('awarded', true);
  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- SECURITY DEFINER, called by the auto_resolve_matches cron edge function
-- using the service role (no end-user JWT / auth.uid()) - must NOT gate on
-- auth.uid(), see supabase/migrations/20260710142613_fix_standings_update_service_role_auth_check.sql.
-- EXECUTE is revoked from PUBLIC/authenticated/anon below so end users can't
-- call this non-idempotent function directly to inflate their own stats.
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

-- place_transfer_bid / accept_transfer_offer / release_expired_transfer_bids
-- (the old auction-style bidding RPCs) are gone - the transfer market is
-- now offer-based, see make_transfer_offer/respond_to_transfer_offer in
-- supabase/migrations/20260709194633_real_transfer_offer_system.sql.
-- Deliberately not redefined here (see the note above
-- award_ad_reward's table for why leaving a stale copy in this
-- unconditionally-applied file is actively dangerous, not just untidy).

-- upgrade_club now only handles ticket price (instant); stadium/facility
-- upgrades moved to the timed start_club_development flow. See
-- supabase/migrations/20260709191459_ticket_price_time_gated_and_realistic_values.sql.
CREATE OR REPLACE FUNCTION public.upgrade_club(
  p_club_id UUID,
  p_ticket_price INT
)
RETURNS public.clubs AS $$
DECLARE
  current_club public.clubs%ROWTYPE;
  updated_row public.clubs;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated user cannot upgrade club';
  END IF;

  SELECT * INTO current_club
  FROM public.clubs
  WHERE id = p_club_id
    AND user_id = auth.uid();

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Club not found or not owned by current user';
  END IF;

  IF p_ticket_price IS NULL OR p_ticket_price <= current_club.ticket_price THEN
    RAISE EXCEPTION 'Ticket price must be higher than current price';
  END IF;

  IF current_club.budget < 500 THEN
    RAISE EXCEPTION 'Not enough budget for upgrade';
  END IF;

  UPDATE public.clubs
  SET budget = current_club.budget - 500,
      ticket_price = p_ticket_price
  WHERE id = p_club_id
  RETURNING * INTO updated_row;

  INSERT INTO public.financial_transactions(club_id, type, amount, description, source)
  VALUES (p_club_id, 'upgrade_club', -500, 'Bilet fiyatı güncelleme harcaması: -500 GP', 'upgrade_club');

  RETURN updated_row;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Sponsor upgrades are timed (1/3/5/7 days by level), not instant. See
-- supabase/migrations/20260709182919_time_gated_sponsor_upgrade.sql and
-- process_sponsor_upgrades (applied by the process_timed_upgrades cron)
-- for the completion side.
CREATE OR REPLACE FUNCTION public.upgrade_sponsor(club_id UUID)
RETURNS public.clubs AS $$
DECLARE
  current_club public.clubs%ROWTYPE;
  updated_row public.clubs;
  new_budget BIGINT;
  duration_days INT;
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

  IF current_club.sponsor_upgrade_completes_at IS NOT NULL AND current_club.sponsor_upgrade_completes_at > now() THEN
    RAISE EXCEPTION 'Sponsor upgrade already in progress';
  END IF;

  new_budget := current_club.budget - (5000 * current_club.sponsor_level);

  IF new_budget < 0 THEN
    RAISE EXCEPTION 'Not enough budget to upgrade sponsor';
  END IF;

  duration_days := 2 * current_club.sponsor_level - 1;

  UPDATE public.clubs
  SET budget = new_budget,
      sponsor_upgrade_completes_at = now() + make_interval(days => duration_days)
  WHERE id = club_id
  RETURNING * INTO updated_row;

  INSERT INTO public.financial_transactions(club_id, type, amount, description, source)
  VALUES (
    club_id,
    'upgrade_sponsor',
    -(5000 * current_club.sponsor_level),
    format('Sponsor yükseltme harcaması: -%s GP (%s gün sürecek)', 5000 * current_club.sponsor_level, duration_days),
    'upgrade_sponsor'
  );

  RETURN updated_row;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

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
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Removed: assign_club_to_new_user() / assign_club_to_new_user_trigger used
-- to silently hand every new signup the first unclaimed club, bypassing the
-- create-league/join-league onboarding screen entirely. Superseded by the
-- explicit create_league_and_join / join_league_with_code RPCs (see
-- supabase/migrations/20260709090000_league_create_join_flow.sql and
-- the migration that dropped this trigger in production).
DROP TRIGGER IF EXISTS assign_club_to_new_user_trigger ON auth.users;
DROP FUNCTION IF EXISTS public.assign_club_to_new_user();
