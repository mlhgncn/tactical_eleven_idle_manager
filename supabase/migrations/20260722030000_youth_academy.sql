-- Youth academy: club-scoped, low/no-cost young-player production, meant
-- as an alternative income of new talent to the transfer market/diamond
-- packs. One production slot per club (matches the "one development per
-- position group" single-track feel already established by
-- start_player_development), gated by training_facility_level (which the
-- user already invests GP into for stadium/facility upgrades - this gives
-- that investment a second payoff instead of adding a new currency sink).
--
-- Distinguishing academy players from _insert_generated_player output:
-- academy players are deliberately WEAKER right now (age 15-18 vs the
-- general 17-33 pool, lower current_ability) but with a wider
-- potential-current gap, so they read as "raw talent, needs development"
-- rather than a shortcut to a good starting XI - keeps this from
-- outcompeting the diamond-pack economy (packs guarantee high CA now;
-- academy trades CA-now for a cheap/free long-term prospect).

ALTER TABLE public.clubs
  ADD COLUMN IF NOT EXISTS academy_completes_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS academy_ad_uses INT NOT NULL DEFAULT 0;

-- Produces one academy player: age 15-18, current_ability scaled modestly
-- by training_facility_level (higher facility = slightly better raw
-- talent pool), potential_ability given a wide age-appropriate ceiling.
-- Mirrors _insert_generated_player's stat-derivation formulas so academy
-- players aren't a different "kind" of player stat-wise, just younger and
-- weaker-now/higher-ceiling.
CREATE OR REPLACE FUNCTION public._insert_academy_player(p_club_id UUID, p_facility_level INT)
RETURNS public.players AS $$
DECLARE
  chosen_pos TEXT := public._random_position();
  gen_ca INT;
  gen_age INT := (15 + floor(random() * 4))::int;
  gen_pa INT;
  new_row public.players;
  target_league_id UUID;
  first_names TEXT[] := ARRAY[
    'Ariel','Bruno','Cesar','Diego','Erik','Felix','Gustavo','Hugo','Ivan','Jonas',
    'Kwame','Lars','Marco','Nils','Omar','Pedro','Quinten','Rafael','Sami','Tomas',
    'Umut','Viktor','Wesley','Xander','Yusuf','Zoltan','Adam','Bilal','Carlos','Denis',
    'Emre','Fabio','Giorgio','Hakan','Igor','Jamal','Kevin','Luca','Milan','Nico',
    'Oscar','Pablo','Quincy','Ruben','Stefan','Tarik','Urs','Vasco','Walid','Yannick'
  ];
  last_names TEXT[] := ARRAY[
    'Aydin','Berg','Costa','Duarte','Eriksen','Fischer','Garcia','Hansen','Ibrahim','Jansen',
    'Kovac','Lindberg','Martins','Novak','Oliveira','Petrov','Quiroga','Rossi','Santos','Tanaka',
    'Ulrich','Vidal','Weber','Xhaka','Yildiz','Zeman','Andersson','Batista','Costello','Dimitrov',
    'Ekstrom','Ferreira','Gomez','Hoffmann','Ivanovic','Johansson','Kruger','Larsen','Mendes','Nilsson',
    'Ostrowski','Perez','Radic','Sorensen','Torres','Uzun','Varga','Wagner','Yamamoto','Zorc'
  ];
BEGIN
  SELECT league_id INTO target_league_id FROM public.clubs WHERE id = p_club_id;

  gen_ca := GREATEST(12, LEAST(40, 14 + p_facility_level + floor(random() * 10)::int));
  gen_pa := LEAST(109, gen_ca + (25 + floor(random() * 21))::int);

  INSERT INTO public.players (
    club_id, name, position, current_ability, potential_ability, age,
    morale, fitness, finishing, passing, tackling, composure,
    determination, consistency, injury_proneness, preferred_foot
  ) VALUES (
    p_club_id, public._unique_player_name_for_league(target_league_id, first_names, last_names), chosen_pos, gen_ca, gen_pa, gen_age,
    (65 + floor(random() * 25))::int,
    (85 + floor(random() * 16))::int,
    GREATEST(5, LEAST(20, CASE
      WHEN chosen_pos IN ('ST','LW','RW') THEN (gen_ca / 5 + 2 + floor(random() * 3))::int
      WHEN chosen_pos IN ('CM','CDM','CAM','LM','RM') THEN (gen_ca / 5 + floor(random() * 3))::int
      ELSE (gen_ca / 6)::int
    END)),
    GREATEST(5, LEAST(20, CASE
      WHEN chosen_pos IN ('CM','CDM','CAM','LM','RM') THEN (gen_ca / 5 + 2 + floor(random() * 3))::int
      ELSE (gen_ca / 6 + floor(random() * 2))::int
    END)),
    GREATEST(5, LEAST(20, CASE
      WHEN chosen_pos IN ('CB','LB','RB') THEN (gen_ca / 5 + 2 + floor(random() * 3))::int
      ELSE (gen_ca / 8)::int
    END)),
    (8 + floor(random() * 10))::int,
    (8 + floor(random() * 10))::int,
    (8 + floor(random() * 10))::int,
    (3 + floor(random() * 10))::int,
    public._random_preferred_foot()
  )
  RETURNING * INTO new_row;

  RETURN new_row;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Starts a production cycle: 24 hours, shortened by 3h per facility level
-- above 1 (floor 4h at max facility level 10) - investing in the
-- facility both improves the eventual player's floor (via
-- _insert_academy_player) and shortens the wait.
CREATE OR REPLACE FUNCTION public.start_academy_production(p_club_id UUID DEFAULT NULL)
RETURNS public.clubs AS $$
DECLARE
  club_row public.clubs%ROWTYPE;
  wait_hours INT;
  updated_row public.clubs;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated user cannot start academy production';
  END IF;

  IF p_club_id IS NOT NULL THEN
    SELECT * INTO club_row FROM public.clubs WHERE id = p_club_id AND user_id = auth.uid();
  ELSE
    SELECT * INTO club_row FROM public.clubs WHERE user_id = auth.uid() LIMIT 1;
  END IF;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Bir kulübünüz yok';
  END IF;

  IF club_row.academy_completes_at IS NOT NULL AND club_row.academy_completes_at > now() THEN
    RAISE EXCEPTION 'Akademide zaten bir üretim sürüyor';
  END IF;

  PERFORM public._check_roster_limit(club_row.id);

  wait_hours := GREATEST(4, 24 - (club_row.training_facility_level - 1) * 3);

  UPDATE public.clubs
  SET academy_completes_at = now() + (wait_hours || ' hours')::interval,
      academy_ad_uses = 0
  WHERE id = club_row.id
  RETURNING * INTO updated_row;

  RETURN updated_row;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Same ad-speedup pattern as reduce_player_development_time_with_ad: up
-- to 2 uses, each cutting remaining time by 25%.
CREATE OR REPLACE FUNCTION public.reduce_academy_time_with_ad(p_club_id UUID DEFAULT NULL)
RETURNS public.clubs AS $$
DECLARE
  club_row public.clubs%ROWTYPE;
  remaining INTERVAL;
  updated_row public.clubs;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated user cannot reduce academy time';
  END IF;

  IF p_club_id IS NOT NULL THEN
    SELECT * INTO club_row FROM public.clubs WHERE id = p_club_id AND user_id = auth.uid();
  ELSE
    SELECT * INTO club_row FROM public.clubs WHERE user_id = auth.uid() LIMIT 1;
  END IF;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Bir kulübünüz yok';
  END IF;

  IF club_row.academy_completes_at IS NULL OR club_row.academy_completes_at <= now() THEN
    RAISE EXCEPTION 'Hızlandırılacak bir üretim yok';
  END IF;

  IF club_row.academy_ad_uses >= 2 THEN
    RAISE EXCEPTION 'Bu üretim için reklam hakkınız kalmadı (en fazla 2 kez).';
  END IF;

  remaining := club_row.academy_completes_at - now();

  UPDATE public.clubs
  SET academy_completes_at = now() + (remaining * 0.75),
      academy_ad_uses = academy_ad_uses + 1
  WHERE id = club_row.id
  RETURNING * INTO updated_row;

  RETURN updated_row;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Cron-driven completion, same shape as process_player_development: finds
-- clubs whose production has finished, inserts the player (skipping ones
-- whose roster filled up in the meantime rather than erroring, so one
-- full club doesn't stall the whole batch), notifies via inbox.
CREATE OR REPLACE FUNCTION public.process_academy_production()
RETURNS void AS $$
DECLARE
  club_row public.clubs%ROWTYPE;
  new_player public.players;
  roster_count INT;
BEGIN
  FOR club_row IN
    SELECT * FROM public.clubs
    WHERE academy_completes_at IS NOT NULL AND academy_completes_at <= now()
  LOOP
    SELECT count(*) INTO roster_count FROM public.players WHERE club_id = club_row.id;

    IF roster_count < 30 THEN
      new_player := public._insert_academy_player(club_row.id, club_row.training_facility_level);

      IF club_row.user_id IS NOT NULL THEN
        INSERT INTO public.inbox_messages(recipient_id, club_id, title, body, is_read, created_at)
        VALUES (
          club_row.user_id,
          club_row.id,
          'Akademiden Yeni Yetenek',
          format('Akademi %s adında %s yaşında bir %s yetiştirdi! Güç: %s, Potansiyel: %s', new_player.name, new_player.age, new_player.position, new_player.current_ability, new_player.potential_ability),
          false,
          now()
        );
      END IF;
    ELSIF club_row.user_id IS NOT NULL THEN
      INSERT INTO public.inbox_messages(recipient_id, club_id, title, body, is_read, created_at)
      VALUES (
        club_row.user_id,
        club_row.id,
        'Akademi Üretimi Bekliyor',
        'Akademiden yeni bir oyuncu çıkmaya hazır ama kadronuz dolu (30 oyuncu). Kadroda yer açtığınızda tekrar deneyin.',
        false,
        now()
      );
      CONTINUE;
    END IF;

    UPDATE public.clubs SET academy_completes_at = NULL, academy_ad_uses = 0 WHERE id = club_row.id;
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.process_timed_upgrades()
RETURNS void AS $$
BEGIN
  PERFORM public.process_player_development();
  PERFORM public.process_sponsor_upgrades();
  PERFORM public.process_club_upgrades();
  PERFORM public.process_stale_transfer_offers();
  PERFORM public.process_academy_production();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION public.start_academy_production(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.reduce_academy_time_with_ad(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.process_academy_production() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.process_timed_upgrades() TO authenticated, service_role;
