-- Replaces the silent "recruiting league" auto-onboarding (new clubs quietly
-- queued into a league until it hit 18 members, sometimes waiting a long
-- time) with two explicit, instant actions: create a brand new league that
-- starts immediately (bot-filled to 18 clubs so there's a full fixture list
-- from minute one), or join a friend's league via a shareable invitation
-- code. Every league gets a short invitation code so it can be shared.

-- ============================================================
-- 1. Invitation codes on leagues
-- ============================================================
ALTER TABLE public.leagues ADD COLUMN IF NOT EXISTS invitation_code TEXT;

CREATE OR REPLACE FUNCTION public.generate_invitation_code()
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
    SELECT EXISTS(SELECT 1 FROM public.leagues WHERE invitation_code = code) INTO taken;
    EXIT WHEN NOT taken;
  END LOOP;
  RETURN code;
END;
$$ LANGUAGE plpgsql;

DO $$
DECLARE
  league_rec RECORD;
BEGIN
  FOR league_rec IN SELECT id FROM public.leagues WHERE invitation_code IS NULL LOOP
    UPDATE public.leagues SET invitation_code = public.generate_invitation_code() WHERE id = league_rec.id;
  END LOOP;
END;
$$;

ALTER TABLE public.leagues ALTER COLUMN invitation_code SET NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS leagues_invitation_code_unique ON public.leagues (invitation_code);

-- ============================================================
-- 2. Bot club name generator, used to instantly fill a new league
-- ============================================================
CREATE OR REPLACE FUNCTION public.generate_bot_club_name()
RETURNS TEXT AS $$
DECLARE
  city_names TEXT[] := ARRAY[
    'Ankara','Istanbul','Izmir','Bursa','Antalya','Konya','Adana','Gaziantep','Kayseri','Mersin',
    'Trabzon','Samsun','Eskisehir','Diyarbakir','Malatya','Erzurum','Van','Denizli','Sakarya','Manisa',
    'Kocaeli','Balikesir','Aydin','Tekirdag','Ordu','Rize','Sivas','Elazig','Batman','Corum'
  ];
  suffixes TEXT[] := ARRAY[
    'FK','SK','United','City','Athletic','Rovers','Town','Wanderers','CF','Spor',
    'Gucu','Yildiz','Birlik','Genclik','Kartal','Yildizspor'
  ];
BEGIN
  RETURN city_names[1 + floor(random() * array_length(city_names, 1))::int] || ' ' ||
         suffixes[1 + floor(random() * array_length(suffixes, 1))::int];
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 3. create_league_and_join: brand new league, instantly playable
-- ============================================================
CREATE OR REPLACE FUNCTION public.create_league_and_join(p_club_name TEXT)
RETURNS public.clubs AS $$
DECLARE
  new_league_id UUID;
  new_club_id UUID;
  league_counter INT;
  invite_code TEXT;
  i INT;
  bot_club_id UUID;
  updated_row public.clubs;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated user cannot create a league';
  END IF;
  IF EXISTS (SELECT 1 FROM public.clubs WHERE user_id = auth.uid()) THEN
    RAISE EXCEPTION 'Zaten bir kulübünüz var.';
  END IF;
  IF p_club_name IS NULL OR length(trim(p_club_name)) = 0 THEN
    RAISE EXCEPTION 'Kulüp adı boş olamaz.';
  END IF;

  invite_code := public.generate_invitation_code();
  SELECT count(*) INTO league_counter FROM public.leagues;

  INSERT INTO public.leagues (name, tier, is_active, season_generated, invitation_code)
  VALUES ('Lig ' || (league_counter + 1), 1, true, false, invite_code)
  RETURNING id INTO new_league_id;

  INSERT INTO public.clubs (name, user_id, league_id)
  VALUES (trim(p_club_name), auth.uid(), new_league_id)
  RETURNING id INTO new_club_id;

  PERFORM public.generate_squad_for_club(new_club_id, NULL);

  -- Fill the rest of the league with bot clubs so it can start playing
  -- immediately instead of waiting for 17 more real signups.
  FOR i IN 1..17 LOOP
    INSERT INTO public.clubs (name, league_id)
    VALUES (public.generate_bot_club_name(), new_league_id)
    RETURNING id INTO bot_club_id;
    PERFORM public.generate_squad_for_club(bot_club_id, NULL);
  END LOOP;

  PERFORM public.generate_season_fixtures_for_league(new_league_id);

  SELECT * INTO updated_row FROM public.clubs WHERE id = new_club_id;
  RETURN updated_row;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ============================================================
-- 4. join_league_with_code: take over a bot-controlled slot in a
--    friend's league via their invitation code
-- ============================================================
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

  RETURN updated_row;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ============================================================
-- 5. The old silent "recruiting league" auto-assignment is fully
--    superseded by the explicit create/join flow above - if left in
--    place it would fire on create_league_and_join's own club insert
--    (AFTER INSERT ... WHEN NEW.user_id IS NOT NULL) and clobber the
--    league_id that function just set, plus double-generate a squad.
-- ============================================================
DROP TRIGGER IF EXISTS onboard_new_club_trigger ON public.clubs;
DROP FUNCTION IF EXISTS public.onboard_new_club();
