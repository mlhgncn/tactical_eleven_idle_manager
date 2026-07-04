-- CI trigger: update to force supabase_deploy.yml push
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS public.clubs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    name TEXT NOT NULL,
    budget BIGINT NOT NULL DEFAULT 10000000,
    stadium_capacity INT NOT NULL DEFAULT 15000,
    fans_count INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
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
    week INT NOT NULL,
    home_club_id UUID REFERENCES public.clubs(id) ON DELETE SET NULL,
    away_club_id UUID REFERENCES public.clubs(id) ON DELETE SET NULL,
    home_score INT,
    away_score INT,
    is_played BOOLEAN NOT NULL DEFAULT FALSE,
    match_date TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.transfer_market (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    player_id UUID UNIQUE REFERENCES public.players(id) ON DELETE CASCADE,
    current_highest_bid BIGINT NOT NULL DEFAULT 0,
    highest_bidder_id UUID REFERENCES public.clubs(id) ON DELETE SET NULL,
    end_time TIMESTAMPTZ NOT NULL DEFAULT now() + interval '1 day'
);

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
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.players ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.matches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transfer_market ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.leaderboards ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS clubs_select_policy ON public.clubs;
CREATE POLICY clubs_select_policy ON public.clubs FOR SELECT TO authenticated USING (auth.uid() = user_id OR user_id IS NULL);

DROP POLICY IF EXISTS clubs_insert_policy ON public.clubs;
CREATE POLICY clubs_insert_policy ON public.clubs FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS clubs_update_policy ON public.clubs;
CREATE POLICY clubs_update_policy ON public.clubs FOR UPDATE TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS players_select_policy ON public.players;
CREATE POLICY players_select_policy ON public.players FOR SELECT TO authenticated
  USING (
    club_id = (
      SELECT id FROM public.clubs WHERE user_id = auth.uid() LIMIT 1
    ) OR club_id IS NULL
  );

DROP POLICY IF EXISTS players_update_policy ON public.players;
CREATE POLICY players_update_policy ON public.players FOR UPDATE TO authenticated
  USING (
    club_id = (
      SELECT id FROM public.clubs WHERE user_id = auth.uid() LIMIT 1
    )
  )
  WITH CHECK (
    club_id = (
      SELECT id FROM public.clubs WHERE user_id = auth.uid() LIMIT 1
    )
  );

DROP POLICY IF EXISTS matches_select_policy ON public.matches;
CREATE POLICY matches_select_policy ON public.matches FOR SELECT TO authenticated
  USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS transfer_market_select_policy ON public.transfer_market;
CREATE POLICY transfer_market_select_policy ON public.transfer_market FOR SELECT TO authenticated
  USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS transfer_market_update_policy ON public.transfer_market;
CREATE POLICY transfer_market_update_policy ON public.transfer_market FOR UPDATE TO authenticated
  USING (false);

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

DROP POLICY IF EXISTS inbox_messages_update_policy ON public.inbox_messages;
CREATE POLICY inbox_messages_update_policy ON public.inbox_messages FOR UPDATE TO authenticated
  USING (recipient_id = auth.uid())
  WITH CHECK (recipient_id = auth.uid());

DROP POLICY IF EXISTS leaderboards_select_policy ON public.leaderboards;
CREATE POLICY leaderboards_select_policy ON public.leaderboards FOR SELECT TO authenticated USING (auth.uid() = user_id);

DROP POLICY IF EXISTS leaderboards_insert_policy ON public.leaderboards;
CREATE POLICY leaderboards_insert_policy ON public.leaderboards FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS leaderboards_update_policy ON public.leaderboards;
CREATE POLICY leaderboards_update_policy ON public.leaderboards FOR UPDATE TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE OR REPLACE FUNCTION public.place_transfer_bid(market_id UUID, bid_amount BIGINT)
RETURNS public.transfer_market AS $$
DECLARE
  bidder_club_id UUID;
  updated_row public.transfer_market;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated user cannot place bid';
  END IF;

  SELECT id INTO bidder_club_id
  FROM public.clubs
  WHERE user_id = auth.uid()
  LIMIT 1;

  IF bidder_club_id IS NULL THEN
    RAISE EXCEPTION 'User does not own a club';
  END IF;

  UPDATE public.transfer_market
  SET current_highest_bid = bid_amount,
      highest_bidder_id = bidder_club_id
  WHERE id = market_id
    AND current_highest_bid < bid_amount
    AND end_time > now()
  RETURNING * INTO updated_row;

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  RETURN updated_row;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET row_security = off;

CREATE OR REPLACE FUNCTION public.claim_club(club_id UUID)
RETURNS public.clubs AS $$
DECLARE
  updated_row public.clubs;
  current_user_id UUID := auth.uid();
BEGIN
  IF current_user_id IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated user cannot claim club';
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
$$ LANGUAGE plpgsql SECURITY DEFINER SET row_security = off;

CREATE OR REPLACE FUNCTION public.assign_club_to_new_user()
RETURNS trigger AS $$
BEGIN
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS assign_club_to_new_user_trigger ON auth.users;
CREATE TRIGGER assign_club_to_new_user_trigger
AFTER INSERT ON auth.users
FOR EACH ROW
EXECUTE FUNCTION public.assign_club_to_new_user();
