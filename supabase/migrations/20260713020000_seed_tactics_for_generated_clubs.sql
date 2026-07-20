-- Bots (and every newly generated club) never got a public.tactics row at
-- all - generate_squad_for_club only ever inserted players, so every match
-- involving a club without a manually-saved tactic fell through to
-- match_engine.ts's hardcoded DEFAULT_TACTIC (4-4-2/balanced/50/50/50)
-- forever, no matter how many matches it played. This seeds a real,
-- club-specific tactics row (randomized formation + mentality, starting XI
-- picked from the squad's highest-ability player per position group) right
-- after the squad is generated, so bots play with an actual tactic from
-- their first match on - same body as
-- 20260712270000_proportional_squad_positions.sql, plus the new INSERT at
-- the end.
CREATE OR REPLACE FUNCTION public.generate_squad_for_club(p_club_id UUID, p_quality INT DEFAULT NULL, p_theme TEXT DEFAULT 'turkey')
RETURNS void AS $$
DECLARE
  club_quality INT := COALESCE(p_quality, 30 + floor(random() * 45)::int);
  target_count INT := 24;
  i INT;
  chosen_pos TEXT;
  gen_ca INT;
  gen_age INT;
  gen_pa INT;
  pos_slots TEXT[] := ARRAY[
    'GK','GK','GK',
    'CB','CB','CB','CB',
    'LB','LB','RB','RB',
    'CDM','CDM','CM','CM','CAM','CAM',
    'LW','LW','RW','RW',
    'ST','ST','ST'
  ];
  first_names TEXT[];
  last_names TEXT[];
  target_league_id UUID;
BEGIN
  SELECT league_id INTO target_league_id FROM public.clubs WHERE id = p_club_id;

  FOR i IN REVERSE array_length(pos_slots, 1)..2 LOOP
    DECLARE
      j INT := 1 + floor(random() * i)::int;
      tmp TEXT := pos_slots[i];
    BEGIN
      pos_slots[i] := pos_slots[j];
      pos_slots[j] := tmp;
    END;
  END LOOP;

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
    ELSE
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
    chosen_pos := pos_slots[i];
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

  INSERT INTO public.tactics (club_id, formation, mentality, starting_eleven_ids)
  SELECT
    p_club_id,
    (ARRAY['f442','f433','f352','f532','f442b','f4231','f4141'])[1 + floor(random() * 7)::int],
    (ARRAY['defensive','balanced','attacking'])[1 + floor(random() * 3)::int],
    (
      SELECT array_agg(id) FROM (
        (SELECT id FROM public.players WHERE club_id = p_club_id AND position = 'GK' ORDER BY current_ability DESC LIMIT 1)
        UNION ALL
        (SELECT id FROM public.players WHERE club_id = p_club_id AND position IN ('CB','LB','RB') ORDER BY current_ability DESC LIMIT 4)
        UNION ALL
        (SELECT id FROM public.players WHERE club_id = p_club_id AND position IN ('CDM','CM','CAM') ORDER BY current_ability DESC LIMIT 3)
        UNION ALL
        (SELECT id FROM public.players WHERE club_id = p_club_id AND position IN ('LW','RW','ST') ORDER BY current_ability DESC LIMIT 3)
      ) eleven
    )
  ON CONFLICT (club_id) DO NOTHING;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Backfill: seed a tactics row for every EXISTING club that doesn't have
-- one yet (this is the vast majority of bot clubs today, per the research
-- - only 11 tactics rows existed against 1254 clubs).
INSERT INTO public.tactics (club_id, formation, mentality, starting_eleven_ids)
SELECT
  c.id,
  (ARRAY['f442','f433','f352','f532','f442b','f4231','f4141'])[1 + floor(random() * 7)::int],
  (ARRAY['defensive','balanced','attacking'])[1 + floor(random() * 3)::int],
  (
    SELECT array_agg(p.id) FROM (
      (SELECT id FROM public.players WHERE club_id = c.id AND position = 'GK' ORDER BY current_ability DESC LIMIT 1)
      UNION ALL
      (SELECT id FROM public.players WHERE club_id = c.id AND position IN ('CB','LB','RB') ORDER BY current_ability DESC LIMIT 4)
      UNION ALL
      (SELECT id FROM public.players WHERE club_id = c.id AND position IN ('CDM','CM','CAM') ORDER BY current_ability DESC LIMIT 3)
      UNION ALL
      (SELECT id FROM public.players WHERE club_id = c.id AND position IN ('LW','RW','ST') ORDER BY current_ability DESC LIMIT 3)
    ) p
  )
FROM public.clubs c
WHERE NOT EXISTS (SELECT 1 FROM public.tactics t WHERE t.club_id = c.id)
  AND EXISTS (SELECT 1 FROM public.players p WHERE p.club_id = c.id)
ON CONFLICT (club_id) DO NOTHING;
