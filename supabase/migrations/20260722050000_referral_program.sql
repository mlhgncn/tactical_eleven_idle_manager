-- Friend referral program: every profile gets a stable referral_code
-- (same 6-char alphabet/format as leagues.invitation_code, deliberately
-- a separate code space so referral codes and league invite codes can't
-- be confused with each other). A new signup can pass one in via
-- supabase.auth.signUp's `data:` map (same mechanism already used for
-- username - handle_new_user already reads raw_user_meta_data->>'username',
-- extending it to also read 'referral_code' needs no new RPC). The
-- referral is recorded immediately (referred_by) but the diamond reward
-- for BOTH sides only fires once the new user actually sets up their
-- first club - via whichever of select_club_for_league/
-- join_league_with_code they use - not at signup. This means a bot
-- account that verifies email but never plays never pays out, which is
-- the cheapest fraud brake available given there's no device-fingerprint
-- signal anywhere in this codebase.

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS referral_code TEXT,
  ADD COLUMN IF NOT EXISTS referred_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS referral_reward_claimed BOOLEAN NOT NULL DEFAULT false;

CREATE UNIQUE INDEX IF NOT EXISTS idx_profiles_referral_code ON public.profiles(referral_code) WHERE referral_code IS NOT NULL;

CREATE OR REPLACE FUNCTION public.generate_referral_code()
RETURNS TEXT AS $$
DECLARE
  chars TEXT := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; -- no 0/O/1/I to avoid confusion
  code TEXT;
  taken BOOLEAN;
  i INT;
BEGIN
  LOOP
    code := '';
    FOR i IN 1..6 LOOP
      code := code || substr(chars, 1 + floor(random() * length(chars))::int, 1);
    END LOOP;
    SELECT EXISTS(SELECT 1 FROM public.profiles WHERE referral_code = code) INTO taken;
    EXIT WHEN NOT taken;
  END LOOP;
  RETURN code;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- handle_new_user: also assign a referral_code to every new profile, and
-- record referred_by if a valid, non-self referral code was passed at
-- signup (self-referral - a code matching the signing-up user, which
-- can't actually happen since their own code doesn't exist yet, but
-- guarded anyway - and an unknown code are both silently ignored rather
-- than failing signup over a cosmetic field).
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
DECLARE
  referrer_id UUID;
  supplied_code TEXT := NEW.raw_user_meta_data->>'referral_code';
BEGIN
  IF supplied_code IS NOT NULL AND length(trim(supplied_code)) > 0 THEN
    SELECT id INTO referrer_id FROM public.profiles WHERE referral_code = upper(trim(supplied_code));
  END IF;

  INSERT INTO public.profiles (id, email, language, username, referral_code, referred_by)
  VALUES (NEW.id, NEW.email, 'tr', NEW.raw_user_meta_data->>'username', public.generate_referral_code(), referrer_id)
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Backfill referral codes for existing profiles created before this migration.
UPDATE public.profiles SET referral_code = public.generate_referral_code() WHERE referral_code IS NULL;

-- Pays out both sides of a referral once, called from the two places a
-- user's FIRST club gets assigned. Idempotent via referral_reward_claimed
-- on the referred (new) user's own profile - only that side needs
-- guarding since this only ever runs once per new user's first club.
CREATE OR REPLACE FUNCTION public._award_referral_bonus_if_applicable(p_new_user_id UUID)
RETURNS void AS $$
DECLARE
  new_user_row public.profiles%ROWTYPE;
BEGIN
  SELECT * INTO new_user_row FROM public.profiles WHERE id = p_new_user_id FOR UPDATE;
  IF NOT FOUND OR new_user_row.referred_by IS NULL OR new_user_row.referral_reward_claimed THEN
    RETURN;
  END IF;
  IF new_user_row.referred_by = p_new_user_id THEN
    RETURN; -- self-referral guard, shouldn't be reachable but cheap to check
  END IF;

  UPDATE public.profiles SET referral_reward_claimed = true WHERE id = p_new_user_id;
  UPDATE public.profiles SET diamonds = diamonds + 15 WHERE id = p_new_user_id;
  UPDATE public.profiles SET diamonds = diamonds + 15 WHERE id = new_user_row.referred_by;

  INSERT INTO public.inbox_messages(recipient_id, title, body, is_read, created_at)
  VALUES (p_new_user_id, 'Davet Ödülü', 'Bir arkadaşının davet kodunu kullandın, hesabına 15 elmas hediye edildi!', false, now());
  INSERT INTO public.inbox_messages(recipient_id, title, body, is_read, created_at)
  VALUES (new_user_row.referred_by, 'Davet Ödülü', 'Davet ettiğin bir arkadaşın ilk kulübünü kurdu, hesabına 15 elmas hediye edildi!', false, now());
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.select_club_for_league(p_club_id UUID)
RETURNS public.clubs AS $$
DECLARE
  target_league_id UUID;
  target_is_premium BOOLEAN;
  target_cost INT;
  current_diamonds BIGINT;
  updated_row public.clubs;
  bot_club_id UUID;
  listing_rec RECORD;
  is_first_club BOOLEAN;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated user cannot select a club';
  END IF;
  IF public._user_club_count(auth.uid()) >= 4 THEN
    RAISE EXCEPTION 'En fazla 4 farklı ligde kulübünüz olabilir.';
  END IF;

  is_first_club := NOT EXISTS (SELECT 1 FROM public.clubs WHERE user_id = auth.uid());

  SELECT league_id, is_premium_locked, premium_unlock_cost
  INTO target_league_id, target_is_premium, target_cost
  FROM public.clubs
  WHERE id = p_club_id AND user_id IS NULL
  FOR UPDATE;

  IF target_league_id IS NULL THEN
    RAISE EXCEPTION 'Bu kulüp artık uygun değil.';
  END IF;

  IF EXISTS (SELECT 1 FROM public.clubs WHERE user_id = auth.uid() AND league_id = target_league_id) THEN
    RAISE EXCEPTION 'Bu ligde zaten bir kulübünüz var.';
  END IF;

  IF target_is_premium THEN
    SELECT diamonds INTO current_diamonds FROM public.profiles WHERE id = auth.uid() FOR UPDATE;
    IF current_diamonds IS NULL OR current_diamonds < target_cost THEN
      RAISE EXCEPTION 'Yetersiz elmas bakiyesi';
    END IF;
    UPDATE public.profiles SET diamonds = diamonds - target_cost WHERE id = auth.uid();
  END IF;

  UPDATE public.clubs SET user_id = auth.uid() WHERE id = p_club_id
  RETURNING * INTO updated_row;

  UPDATE public.leagues SET is_pending_selection = false WHERE id = target_league_id;

  FOR bot_club_id IN SELECT id FROM public.clubs WHERE league_id = target_league_id AND id <> p_club_id LOOP
    FOR listing_rec IN
      SELECT p.id AS player_id,
        GREATEST(1, ROUND(((p.current_ability * 15000 + p.potential_ability * 5000 + p.age * 100)::numeric / 40) * (0.8 + random() * 0.5))) AS price
      FROM public.players p
      WHERE p.club_id = bot_club_id
      ORDER BY random()
      LIMIT (1 + floor(random() * 2)::int)
    LOOP
      INSERT INTO public.transfer_market (player_id, asking_price)
      VALUES (listing_rec.player_id, listing_rec.price)
      ON CONFLICT (player_id) DO NOTHING;
    END LOOP;
  END LOOP;

  PERFORM public.generate_season_fixtures_for_league(target_league_id);

  IF is_first_club THEN
    PERFORM public._award_referral_bonus_if_applicable(auth.uid());
  END IF;

  RETURN updated_row;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.join_league_with_code(p_invitation_code TEXT)
RETURNS public.clubs AS $$
DECLARE
  target_league_id UUID;
  target_club_id UUID;
  updated_row public.clubs;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated user cannot join a league';
  END IF;
  IF EXISTS (SELECT 1 FROM public.clubs WHERE user_id = auth.uid()) THEN
    RAISE EXCEPTION 'Zaten bir kulübünüz var.';
  END IF;
  IF p_invitation_code IS NULL OR length(trim(p_invitation_code)) = 0 THEN
    RAISE EXCEPTION 'Davet kodu boş olamaz.';
  END IF;

  SELECT id INTO target_league_id
  FROM public.leagues
  WHERE invitation_code = upper(trim(p_invitation_code));

  IF target_league_id IS NULL THEN
    RAISE EXCEPTION 'Geçersiz davet kodu.';
  END IF;

  SELECT id INTO target_club_id
  FROM public.clubs
  WHERE league_id = target_league_id AND user_id IS NULL
  ORDER BY random()
  LIMIT 1
  FOR UPDATE SKIP LOCKED;

  IF target_club_id IS NULL THEN
    RAISE EXCEPTION 'Bu ligde boş takım kalmadı.';
  END IF;

  UPDATE public.clubs SET user_id = auth.uid() WHERE id = target_club_id
  RETURNING * INTO updated_row;

  PERFORM public._award_referral_bonus_if_applicable(auth.uid());

  RETURN updated_row;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Read-only lookup for the client: my own referral code + how many
-- successful (reward-paid) referrals I've made.
CREATE OR REPLACE FUNCTION public.get_my_referral_info()
RETURNS TABLE(referral_code TEXT, successful_referrals BIGINT) AS $$
  SELECT p.referral_code, (SELECT count(*) FROM public.profiles r WHERE r.referred_by = p.id AND r.referral_reward_claimed)
  FROM public.profiles p
  WHERE p.id = auth.uid();
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION public.get_my_referral_info() TO authenticated;
REVOKE EXECUTE ON FUNCTION public._award_referral_bonus_if_applicable(UUID) FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION public.select_club_for_league(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.join_league_with_code(TEXT) TO authenticated;
