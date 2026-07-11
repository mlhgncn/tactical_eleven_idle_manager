-- Three related changes to player development:
-- 1. Potential ability cap raised from 99 to 109 (generate_squad_for_club,
--    _insert_generated_player) - current_ability caps are untouched.
-- 2. process_player_development now scales growth by how close the player
--    already is to their potential (diminishing returns in the last 10%),
--    instead of a flat 1-3% every session regardless of proximity.
-- 3. scout_opponent now reflects the DEFAULT_TACTIC that match_engine.ts
--    actually uses for bot-controlled clubs, instead of returning null
--    just because bot clubs never have a real tactics row.

CREATE OR REPLACE FUNCTION public.generate_squad_for_club(p_club_id UUID, p_quality INT DEFAULT NULL, p_theme TEXT DEFAULT 'turkey')
RETURNS void AS $$
DECLARE
  club_quality INT := COALESCE(p_quality, 30 + floor(random() * 45)::int);
  target_count INT := 30 + floor(random() * 5)::int;
  i INT;
  chosen_pos TEXT;
  gen_ca INT;
  gen_age INT;
  gen_pa INT;
  pos_pool TEXT[] := ARRAY['GK','CB','CB','LB','RB','CDM','CM','CM','CAM','LM','RM','ST','ST','LW','RW'];
  first_names TEXT[];
  last_names TEXT[];
  target_league_id UUID;
BEGIN
  SELECT league_id INTO target_league_id FROM public.clubs WHERE id = p_club_id;

  CASE p_theme
    WHEN 'england' THEN
      first_names := ARRAY[
        'James','Harry','Jack','Oliver','George','Charlie','Thomas','Daniel','William','Callum',
        'Jacob','Joseph','Ryan','Luke','Adam','Ben','Sam','Josh','Alfie','Liam',
        'Connor','Reece','Dylan','Ethan','Freddie','Archie','Max','Leo','Toby','Finley'
      ];
      last_names := ARRAY[
        'Wilson','Thompson','Walker','Taylor','Clarke','Cooper','Turner','Baker','Hughes','Evans',
        'Roberts','Green','Hall','Wood','Harris','Martin','Jackson','White','Edwards','Collins',
        'Stewart','Morris','Rogers','Reed','Bell','Murphy','Bailey','Cook','Kelly','Ward'
      ];
    WHEN 'spain' THEN
      first_names := ARRAY[
        'Alejandro','Pablo','Diego','Sergio','Javier','Adrian','Ivan','Mario','Alvaro','Ruben',
        'Carlos','Daniel','David','Jorge','Miguel','Raul','Victor','Antonio','Manuel','Jose',
        'Andres','Cristian','Fernando','Gonzalo','Hugo','Joaquin','Luis','Marcos','Nicolas','Oscar'
      ];
      last_names := ARRAY[
        'Garcia','Fernandez','Lopez','Martinez','Gonzalez','Rodriguez','Sanchez','Perez','Gomez','Diaz',
        'Alonso','Moreno','Munoz','Alvarez','Romero','Navarro','Torres','Ramirez','Ruiz','Serrano',
        'Blanco','Molina','Morales','Ortiz','Delgado','Castro','Ortega','Rubio','Marin','Vega'
      ];
    WHEN 'germany' THEN
      first_names := ARRAY[
        'Lukas','Maximilian','Jonas','Felix','Niklas','Tim','Leon','Paul','Finn','Jan',
        'Julian','Moritz','Simon','Tobias','Florian','Sebastian','Philipp','Christian','Daniel','Alexander',
        'Markus','Stefan','Andreas','Thomas','Michael','Matthias','Benjamin','David','Fabian','Marcel'
      ];
      last_names := ARRAY[
        'Muller','Schmidt','Schneider','Fischer','Weber','Meyer','Wagner','Becker','Hoffmann','Schulz',
        'Koch','Bauer','Richter','Klein','Wolf','Neumann','Schwarz','Zimmermann','Braun','Kruger',
        'Hartmann','Lange','Werner','Krause','Lehmann','Schmid','Schulze','Maier','Herrmann','Walter'
      ];
    WHEN 'italy' THEN
      first_names := ARRAY[
        'Matteo','Lorenzo','Andrea','Francesco','Alessandro','Marco','Luca','Davide','Simone','Riccardo',
        'Gabriele','Federico','Antonio','Giovanni','Stefano','Paolo','Roberto','Alberto','Emanuele','Nicola',
        'Fabio','Giuseppe','Michele','Salvatore','Vincenzo','Domenico','Angelo','Claudio','Massimo','Enrico'
      ];
      last_names := ARRAY[
        'Rossi','Russo','Ferrari','Esposito','Bianchi','Romano','Colombo','Ricci','Marino','Greco',
        'Bruno','Gallo','Conti','De Luca','Costa','Giordano','Mancini','Rizzo','Lombardi','Moretti',
        'Barbieri','Fontana','Santoro','Mariani','Rinaldi','Caruso','Ferrara','Galli','Martini','Leone'
      ];
    ELSE -- 'turkey' and any unrecognized theme fall back to the original mixed pool
      first_names := ARRAY[
        'Ariel','Bruno','Cesar','Diego','Erik','Felix','Gustavo','Hugo','Ivan','Jonas',
        'Kwame','Lars','Marco','Nils','Omar','Pedro','Quinten','Rafael','Sami','Tomas',
        'Umut','Viktor','Wesley','Xander','Yusuf','Zoltan','Adam','Bilal','Carlos','Denis',
        'Emre','Fabio','Giorgio','Hakan','Igor','Jamal','Kevin','Luca','Milan','Nico',
        'Oscar','Pablo','Quincy','Ruben','Stefan','Tarik','Urs','Vasco','Walid','Yannick'
      ];
      last_names := ARRAY[
        'Aydin','Berg','Costa','Duarte','Eriksen','Fischer','Garcia','Hansen','Ibrahim','Jansen',
        'Kovac','Lindberg','Martins','Novak','Oliveira','Petrov','Quiroga','Rossi','Santos','Tanaka',
        'Ulrich','Vidal','Weber','Xhaka','Yildiz','Zeman','Andersson','Batista','Costello','Dimitrov',
        'Ekstrom','Ferreira','Gomez','Hoffmann','Ivanovic','Johansson','Kruger','Larsen','Mendes','Nilsson',
        'Ostrowski','Perez','Radic','Sorensen','Torres','Uzun','Varga','Wagner','Yamamoto','Zorc'
      ];
  END CASE;

  FOR i IN 1..target_count LOOP
    chosen_pos := pos_pool[1 + floor(random() * array_length(pos_pool, 1))::int];
    gen_ca := GREATEST(20, LEAST(95, club_quality + floor(random() * 30 - 12)))::int;
    gen_age := (17 + floor(random() * 17))::int;
    gen_pa := LEAST(109, gen_ca + (
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
      p_club_id,
      public._unique_player_name_for_league(target_league_id, first_names, last_names),
      chosen_pos,
      gen_ca, gen_pa, gen_age,
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
    );
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public._insert_generated_player(p_club_id UUID, p_ability_min INT, p_ability_max INT)
RETURNS public.players AS $$
DECLARE
  chosen_pos TEXT := public._random_position();
  gen_ca INT := GREATEST(1, LEAST(99, p_ability_min + floor(random() * GREATEST(1, p_ability_max - p_ability_min + 1))::int));
  gen_age INT := (17 + floor(random() * 17))::int;
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

  gen_pa := LEAST(109, gen_ca + (
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
    (3 + floor(random() * 10))::int
  )
  RETURNING * INTO new_row;

  RETURN new_row;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- process_player_development: growth now scales down as current_ability
-- approaches potential_ability, instead of a flat 1-3% every session.
-- Below 90% of the way there, behavior is unchanged; in the last 10%,
-- the growth percentage is linearly scaled from 100% down to 10%.
CREATE OR REPLACE FUNCTION public.process_player_development()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
        INSERT INTO public.inbox_messages(recipient_id, title, body, is_read, created_at)
        VALUES (
          owner_id,
          'Oyuncu Gelişimi',
          format('%s gelişimini tamamladı! Yeni güç: %s (+%s)', player_row.name, new_current_ability, new_current_ability - player_row.current_ability),
          false,
          now()
        );
      END IF;
    END IF;
  END LOOP;
END;
$function$;

-- scout_opponent: bot-controlled clubs never have a real tactics row (RLS
-- only lets club owners insert into public.tactics), but match_engine.ts
-- still simulates them with a fixed DEFAULT_TACTIC. Reflect that default
-- here instead of returning null, so scouting a bot opponent shows the
-- tactics they'll actually play with. Real clubs that haven't saved
-- tactics yet still correctly get null.
CREATE OR REPLACE FUNCTION public.scout_opponent(p_match_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  match_row public.matches%ROWTYPE;
  caller_club_id UUID;
  opponent_club_id_var UUID;
  result JSON;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated user cannot scout an opponent';
  END IF;

  SELECT id INTO caller_club_id FROM public.clubs WHERE user_id = auth.uid() LIMIT 1;
  IF caller_club_id IS NULL THEN
    RAISE EXCEPTION 'Bir kulübünüz yok';
  END IF;

  SELECT * INTO match_row FROM public.matches WHERE id = p_match_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Maç bulunamadı';
  END IF;

  IF match_row.home_club_id != caller_club_id AND match_row.away_club_id != caller_club_id THEN
    RAISE EXCEPTION 'Bu maçın tarafı değilsiniz';
  END IF;

  IF match_row.is_played THEN
    RAISE EXCEPTION 'Bu maç zaten oynandı';
  END IF;

  IF match_row.match_date > now() + interval '15 minutes' THEN
    RAISE EXCEPTION 'Rakip kadrosu maça 15 dakika kalana kadar görüntülenemez';
  END IF;

  opponent_club_id_var := CASE
    WHEN match_row.home_club_id = caller_club_id THEN match_row.away_club_id
    ELSE match_row.home_club_id
  END;

  SELECT json_build_object(
    'club_id', opponent_club_id_var,
    'players', (
      SELECT COALESCE(json_agg(json_build_object(
        'id', p.id,
        'name', p.name,
        'position', p.position,
        'age', p.age,
        'current_ability', p.current_ability,
        'is_suspended', p.is_suspended,
        'injury_duration_weeks', p.injury_duration_weeks
      )), '[]'::json)
      FROM public.players p WHERE p.club_id = opponent_club_id_var
    ),
    'tactics', (
      SELECT COALESCE(
        (SELECT row_to_json(t) FROM (
          SELECT formation, mentality, starting_eleven_ids, press_intensity, tempo,
                 defensive_line, offside_trap, time_wasting
          FROM public.tactics WHERE club_id = opponent_club_id_var
        ) t),
        CASE WHEN (SELECT user_id FROM public.clubs WHERE id = opponent_club_id_var) IS NULL THEN
          json_build_object(
            'formation', 'f442',
            'mentality', 'balanced',
            'starting_eleven_ids', NULL,
            'press_intensity', 50,
            'tempo', 50,
            'defensive_line', 50,
            'offside_trap', false,
            'time_wasting', false
          )
        ELSE NULL END
      )
    )
  ) INTO result;

  RETURN result;
END;
$$;
