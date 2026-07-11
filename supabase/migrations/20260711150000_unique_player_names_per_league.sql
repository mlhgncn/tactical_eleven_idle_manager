-- A player's name (first+last, randomly combined from a ~50x50 pool) could
-- previously collide within the same league - with ~576 players spread
-- across 18 clubs drawn from only 2500 combinations, duplicate names inside
-- one league were common (birthday-paradox territory). The same name is
-- fine across different leagues, just not twice inside one league. Both
-- squad generation (generate_squad_for_club) and pack-opened players
-- (_insert_generated_player) now retry name selection against the other
-- players already in the same league until they find a free one.

CREATE OR REPLACE FUNCTION public._unique_player_name_for_league(p_league_id UUID, p_first_names TEXT[], p_last_names TEXT[])
RETURNS TEXT AS $$
DECLARE
  candidate TEXT;
  attempt INT := 0;
BEGIN
  IF p_league_id IS NULL THEN
    -- No league context (e.g. a club not yet attached to a league) - just
    -- return a random name, nothing to de-duplicate against.
    RETURN p_first_names[1 + floor(random() * array_length(p_first_names, 1))::int] || ' ' ||
           p_last_names[1 + floor(random() * array_length(p_last_names, 1))::int];
  END IF;

  LOOP
    candidate := p_first_names[1 + floor(random() * array_length(p_first_names, 1))::int] || ' ' ||
                 p_last_names[1 + floor(random() * array_length(p_last_names, 1))::int];
    attempt := attempt + 1;

    EXIT WHEN attempt >= 30; -- pool is exhausted or nearly so - stop retrying, accept a duplicate rather than loop forever
    EXIT WHEN NOT EXISTS (
      SELECT 1 FROM public.players p
      JOIN public.clubs c ON c.id = p.club_id
      WHERE c.league_id = p_league_id AND p.name = candidate
    );
  END LOOP;

  RETURN candidate;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- generate_squad_for_club: same body as before, but each player's name
-- now goes through _unique_player_name_for_league instead of a bare
-- random pick.
-- ============================================================
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

-- ============================================================
-- _insert_generated_player: same body as before, but the name now goes
-- through _unique_player_name_for_league scoped to the target club's league.
-- ============================================================
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
