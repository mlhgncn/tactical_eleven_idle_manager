-- generate_squad_for_club picked each of the 24 players' positions
-- uniformly at random from a 15-slot pool, so a freshly generated squad
-- could easily end up with zero goalkeepers, three left-backs and no
-- strikers - unusable without immediately buying replacements. Positions
-- are now drawn from a fixed 24-slot distribution (3 GK, 4 CB, 2 LB, 2 RB,
-- 2 CDM, 2 CM, 2 CAM, 2 LW, 2 RW, 3 ST) shuffled once per squad, so every
-- new club starts with a playable, realistically shaped roster while still
-- randomizing which specific slot each generated player lands in.
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

  -- Fisher-Yates shuffle of the fixed position slots, so which player gets
  -- which slot is still random even though the distribution itself isn't.
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
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
