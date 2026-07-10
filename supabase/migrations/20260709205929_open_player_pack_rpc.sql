-- Shared helpers factored out of generate_squad_for_club's inline logic
-- (left generate_squad_for_club itself untouched - it works, no reason to
-- risk it) so pack-generated players use the exact same name pool and
-- position weighting as onboarding-generated ones.
CREATE OR REPLACE FUNCTION public._random_player_name()
RETURNS TEXT AS $$
DECLARE
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
  RETURN first_names[1 + floor(random() * array_length(first_names, 1))::int] || ' ' ||
         last_names[1 + floor(random() * array_length(last_names, 1))::int];
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public._random_position()
RETURNS TEXT AS $$
DECLARE
  pos_pool TEXT[] := ARRAY['GK','CB','CB','LB','RB','CDM','CM','CM','CAM','LM','RM','ST','ST','LW','RW'];
BEGIN
  RETURN pos_pool[1 + floor(random() * array_length(pos_pool, 1))::int];
END;
$$ LANGUAGE plpgsql;

-- Inserts one generated player with current_ability uniformly sampled
-- from [p_ability_min, p_ability_max] into p_club_id, using the same
-- stat-derivation formulas as generate_squad_for_club (age, potential,
-- position-weighted skills) so pack players feel consistent with
-- normally-generated squad players.
CREATE OR REPLACE FUNCTION public._insert_generated_player(p_club_id UUID, p_ability_min INT, p_ability_max INT)
RETURNS public.players AS $$
DECLARE
  chosen_pos TEXT := public._random_position();
  gen_ca INT := GREATEST(1, LEAST(99, p_ability_min + floor(random() * GREATEST(1, p_ability_max - p_ability_min + 1))::int));
  gen_age INT := (17 + floor(random() * 17))::int;
  gen_pa INT;
  new_row public.players;
BEGIN
  gen_pa := LEAST(99, gen_ca + (
    CASE
      WHEN gen_age <= 21 THEN (5 + floor(random() * 22))::int
      WHEN gen_age <= 27 THEN floor(random() * 10)::int
      ELSE floor(random() * 3)::int
    END
  ));

  INSERT INTO public.players (
    club_id, name, position, current_ability, potential_ability, age,
    morale, fitness, finishing, passing, tackling, composure,
    determination, consistency, injury_proneness
  ) VALUES (
    p_club_id, public._random_player_name(), chosen_pos, gen_ca, gen_pa, gen_age,
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
    (3 + floor(random() * 10))::int
  )
  RETURNING * INTO new_row;

  RETURN new_row;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Opens a pack: deducts diamonds, generates 1 guaranteed-minimum player
-- plus random_slot_count players in the pack's random range, all into the
-- caller's own club. FOR UPDATE on the profile row prevents a double-tap
-- race from spending the same diamonds twice.
CREATE OR REPLACE FUNCTION public.open_player_pack(p_pack_id TEXT)
RETURNS SETOF public.players AS $$
DECLARE
  buyer_club_id UUID;
  pack_row public.player_packs%ROWTYPE;
  current_diamonds BIGINT;
  i INT;
  new_player public.players;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated user cannot open a pack';
  END IF;

  SELECT id INTO buyer_club_id FROM public.clubs WHERE user_id = auth.uid() LIMIT 1;
  IF buyer_club_id IS NULL THEN
    RAISE EXCEPTION 'User does not own a club';
  END IF;

  SELECT * INTO pack_row FROM public.player_packs WHERE id = p_pack_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Unknown pack';
  END IF;

  SELECT diamonds INTO current_diamonds FROM public.profiles WHERE id = auth.uid() FOR UPDATE;
  IF current_diamonds IS NULL OR current_diamonds < pack_row.diamond_cost THEN
    RAISE EXCEPTION 'Yetersiz elmas bakiyesi';
  END IF;

  UPDATE public.profiles SET diamonds = diamonds - pack_row.diamond_cost WHERE id = auth.uid();

  new_player := public._insert_generated_player(buyer_club_id, pack_row.guaranteed_min_ability, 99);
  RETURN NEXT new_player;

  FOR i IN 1..pack_row.random_slot_count LOOP
    new_player := public._insert_generated_player(buyer_club_id, pack_row.random_min_ability, pack_row.random_max_ability);
    RETURN NEXT new_player;
  END LOOP;

  RETURN;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
