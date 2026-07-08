-- OSM pivot, part 1: player data overhaul.
--
-- 16,226 of 16,228 live players share the exact same stub stats from the
-- initial bulk seed (current_ability=15, finishing=15, passing=15,
-- tackling=10, ...) - every player is functionally identical, which makes
-- scouting/transfers/match simulation meaningless. This migration:
--   1. Gives every stub player varied, position-appropriate stats, with a
--      per-club "quality tier" so some clubs are genuinely stronger than
--      others (like real leagues) instead of every player rolling
--      independently.
--   2. Tops up every club to a random 30-34 total players (matching a
--      realistic squad shape: GK/DEF/MID/FWD spread), for clubs currently
--      below that.

-- Part 1: fix existing stub players in place.
WITH club_quality AS (
  SELECT id AS club_id,
         30 + (('x' || substr(md5(id::text || 'quality'), 1, 8))::bit(32)::bigint % 45)::int AS quality
  FROM public.clubs
),
target_players AS (
  SELECT
    p.id,
    cq.quality,
    CASE
      WHEN p.position = 'GK' THEN 'GK'
      WHEN p.position IN ('CB','LB','RB','WB','LWB','RWB','FB') THEN 'DEF'
      WHEN p.position IN ('CM','CDM','CAM','LM','RM','DM','AM') THEN 'MID'
      ELSE 'FWD'
    END AS pos_group,
    (17 + floor(random() * 17))::int AS gen_age,
    GREATEST(20, LEAST(95, cq.quality + floor(random() * 30 - 12)))::int AS gen_ca
  FROM public.players p
  JOIN club_quality cq ON cq.club_id = p.club_id
  WHERE p.current_ability = 15 AND p.finishing = 15 AND p.passing = 15 AND p.tackling = 15
)
UPDATE public.players p
SET
  age = tp.gen_age,
  current_ability = tp.gen_ca,
  potential_ability = LEAST(99, tp.gen_ca + (
    CASE
      WHEN tp.gen_age <= 21 THEN (5 + floor(random() * 22))::int
      WHEN tp.gen_age <= 27 THEN floor(random() * 10)::int
      ELSE floor(random() * 3)::int
    END
  )),
  finishing = GREATEST(5, LEAST(20, CASE tp.pos_group
    WHEN 'FWD' THEN (tp.gen_ca / 5 + 2 + floor(random() * 3))::int
    WHEN 'MID' THEN (tp.gen_ca / 5 + floor(random() * 3))::int
    ELSE (tp.gen_ca / 6)::int
  END)),
  passing = GREATEST(5, LEAST(20, CASE tp.pos_group
    WHEN 'MID' THEN (tp.gen_ca / 5 + 2 + floor(random() * 3))::int
    WHEN 'FWD' THEN (tp.gen_ca / 5)::int
    ELSE (tp.gen_ca / 6 + floor(random() * 2))::int
  END)),
  tackling = GREATEST(5, LEAST(20, CASE tp.pos_group
    WHEN 'DEF' THEN (tp.gen_ca / 5 + 2 + floor(random() * 3))::int
    WHEN 'MID' THEN (tp.gen_ca / 6)::int
    ELSE (tp.gen_ca / 8)::int
  END)),
  composure = GREATEST(5, LEAST(20, (8 + floor(random() * 10))::int)),
  determination = GREATEST(5, LEAST(20, (8 + floor(random() * 10))::int)),
  consistency = GREATEST(5, LEAST(20, (8 + floor(random() * 10))::int)),
  injury_proneness = GREATEST(2, LEAST(20, (3 + floor(random() * 10))::int)),
  morale = (65 + floor(random() * 25))::int,
  fitness = (85 + floor(random() * 16))::int
FROM target_players tp
WHERE p.id = tp.id;

-- Part 2: top up every club's roster to a random 30-34 players.
DO $$
DECLARE
  club_rec RECORD;
  current_count INT;
  target_count INT;
  need INT;
  i INT;
  chosen_pos TEXT;
  gen_ca INT;
  gen_age INT;
  gen_pa INT;
  club_quality INT;
  pos_pool TEXT[] := ARRAY['GK','CB','CB','LB','RB','CDM','CM','CM','CAM','LM','RM','ST','ST','LW','RW'];
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
  FOR club_rec IN SELECT id FROM public.clubs LOOP
    SELECT count(*) INTO current_count FROM public.players WHERE club_id = club_rec.id;
    target_count := 30 + floor(random() * 5)::int;
    need := target_count - current_count;
    CONTINUE WHEN need <= 0;

    club_quality := 30 + floor(random() * 45)::int;

    FOR i IN 1..need LOOP
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
        club_rec.id,
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
  END LOOP;
END $$;
