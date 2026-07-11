-- Multi-theme leagues: the user picks a country theme (Turkey, England,
-- Spain, Germany, Italy) when creating a new league, and bot club names +
-- generated player names now match that theme instead of always being
-- Turkey-flavored. Fictional/inspired names only (no real club/player
-- names) to avoid trademark issues.

ALTER TABLE public.leagues ADD COLUMN IF NOT EXISTS theme TEXT NOT NULL DEFAULT 'turkey';

-- ============================================================
-- 1. generate_bot_club_name(p_theme) - theme-aware bot club names
-- ============================================================
CREATE OR REPLACE FUNCTION public.generate_bot_club_name(p_theme TEXT DEFAULT 'turkey')
RETURNS TEXT AS $$
DECLARE
  city_names TEXT[];
  suffixes TEXT[];
BEGIN
  CASE p_theme
    WHEN 'england' THEN
      city_names := ARRAY[
        'Manchester','Liverpool','London','Leeds','Birmingham','Newcastle','Sheffield','Nottingham',
        'Bristol','Leicester','Southampton','Everton','Sunderland','Blackburn','Bolton','Derby',
        'Fulham','Watford','Norwich','Ipswich','Preston','Luton','Reading','Brighton',
        'Middlesbrough','Stoke','Wigan','Hull','Swansea','Cardiff'
      ];
      suffixes := ARRAY[
        'United','City','Athletic','Rovers','Town','Wanderers','Albion','Rangers',
        'FC','Villa','Palace','County'
      ];
    WHEN 'spain' THEN
      city_names := ARRAY[
        'Madrid','Barcelona','Sevilla','Valencia','Bilbao','Zaragoza','Malaga','Granada',
        'Vigo','Cadiz','Cordoba','Murcia','Alicante','Gijon','Santander','Valladolid',
        'Pamplona','Salamanca','Toledo','Almeria','Huelva','Leon','Burgos','Tarragona',
        'Girona','Logrono','Badajoz','Castellon','Lugo','Oviedo'
      ];
      suffixes := ARRAY[
        'CF','FC','Deportivo','Atletico','Real','Union','Recreativo','Balompie',
        'Sporting','Club'
      ];
    WHEN 'germany' THEN
      city_names := ARRAY[
        'Munich','Berlin','Hamburg','Dortmund','Leipzig','Cologne','Stuttgart','Frankfurt',
        'Bremen','Hannover','Nuremberg','Duisburg','Bochum','Wolfsburg','Bielefeld','Bonn',
        'Mannheim','Karlsruhe','Augsburg','Wiesbaden','Munster','Mainz','Kiel','Rostock',
        'Kassel','Freiburg','Dresden','Essen','Dusseldorf','Gelsenkirchen'
      ];
      suffixes := ARRAY[
        'SV','FC','Borussia','Eintracht','Fortuna','Werder','Union','Viktoria',
        'Hertha','Alemannia'
      ];
    WHEN 'italy' THEN
      city_names := ARRAY[
        'Milano','Roma','Napoli','Torino','Firenze','Bologna','Genova','Palermo',
        'Verona','Bari','Catania','Venezia','Padova','Brescia','Parma','Modena',
        'Cagliari','Salerno','Trieste','Bergamo','Perugia','Livorno','Foggia','Pisa',
        'Ferrara','Reggio','Taranto','Lecce','Ancona','Udine'
      ];
      suffixes := ARRAY[
        'FC','AC','Calcio','Unione','Sportiva','Atletico','Vecchia','Nuova',
        'Reale','Virtus'
      ];
    ELSE -- 'turkey' and any unrecognized theme fall back to Turkey
      city_names := ARRAY[
        'Ankara','Istanbul','Izmir','Bursa','Antalya','Konya','Adana','Gaziantep','Kayseri','Mersin',
        'Trabzon','Samsun','Eskisehir','Diyarbakir','Malatya','Erzurum','Van','Denizli','Sakarya','Manisa',
        'Kocaeli','Balikesir','Aydin','Tekirdag','Ordu','Rize','Sivas','Elazig','Batman','Corum'
      ];
      suffixes := ARRAY[
        'FK','SK','United','City','Athletic','Rovers','Town','Wanderers','CF','Spor',
        'Gucu','Yildiz','Birlik','Genclik','Kartal','Yildizspor'
      ];
  END CASE;

  RETURN city_names[1 + floor(random() * array_length(city_names, 1))::int] || ' ' ||
         suffixes[1 + floor(random() * array_length(suffixes, 1))::int];
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 2. generate_squad_for_club(p_club_id, p_quality, p_theme) - theme-aware player names
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
BEGIN
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
      first_names[1 + floor(random() * array_length(first_names, 1))::int] || ' ' ||
        last_names[1 + floor(random() * array_length(last_names, 1))::int],
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
-- 3. create_league_and_join(p_theme) - theme selection at league creation
-- ============================================================
CREATE OR REPLACE FUNCTION public.create_league_and_join(p_theme TEXT DEFAULT 'turkey')
 RETURNS clubs
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  new_league_id UUID;
  new_club_id UUID;
  league_counter INT;
  invite_code TEXT;
  i INT;
  bot_club_id UUID;
  club_quality INT;
  club_budget BIGINT;
  updated_row public.clubs;
  listing_rec RECORD;
  league_display_name TEXT;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated user cannot create a league';
  END IF;
  IF EXISTS (SELECT 1 FROM public.clubs WHERE user_id = auth.uid()) THEN
    RAISE EXCEPTION 'Zaten bir kulübünüz var.';
  END IF;
  IF p_theme NOT IN ('turkey', 'england', 'spain', 'germany', 'italy') THEN
    RAISE EXCEPTION 'Geçersiz lig teması';
  END IF;

  invite_code := public.generate_invitation_code();
  SELECT count(*) INTO league_counter FROM public.leagues WHERE theme = p_theme;

  league_display_name := CASE p_theme
    WHEN 'england' THEN 'İngiltere Ligi'
    WHEN 'spain' THEN 'İspanya Ligi'
    WHEN 'germany' THEN 'Almanya Ligi'
    WHEN 'italy' THEN 'İtalya Ligi'
    ELSE 'Türkiye Ligi'
  END;

  INSERT INTO public.leagues (name, tier, is_active, season_generated, invitation_code, theme)
  VALUES (league_display_name || ' ' || (league_counter + 1), 1, true, false, invite_code, p_theme)
  RETURNING id INTO new_league_id;

  club_quality := 30 + floor(random() * 45)::int;
  club_budget := public.budget_for_quality(club_quality);

  INSERT INTO public.clubs (name, user_id, league_id, budget)
  VALUES (public.generate_bot_club_name(p_theme), auth.uid(), new_league_id, club_budget)
  RETURNING id INTO new_club_id;

  PERFORM public.generate_squad_for_club(new_club_id, club_quality, p_theme);

  -- Fill the rest of the league with bot clubs so it can start playing
  -- immediately, and seed a transfer listing or two from each one.
  FOR i IN 1..17 LOOP
    club_quality := 30 + floor(random() * 45)::int;
    club_budget := public.budget_for_quality(club_quality);

    INSERT INTO public.clubs (name, league_id, budget)
    VALUES (public.generate_bot_club_name(p_theme), new_league_id, club_budget)
    RETURNING id INTO bot_club_id;
    PERFORM public.generate_squad_for_club(bot_club_id, club_quality, p_theme);

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

  PERFORM public.generate_season_fixtures_for_league(new_league_id);

  SELECT * INTO updated_row FROM public.clubs WHERE id = new_club_id;
  RETURN updated_row;
END;
$function$;
