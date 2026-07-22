-- One-time data repair: the inverted-selection bug in 20260723040000
-- (fixed in 20260723050000) left many clubs short a full position group
-- (some with literally zero goalkeepers). The free-agent pool that would
-- normally cover a shortfall was fully drained by then (every position
-- exhausted except a handful of MID) after two earlier repair passes
-- consumed it, so generating brand-new players - same
-- ability/attribute formula generate_squad_for_club uses for a fresh
-- squad, scaled to each club's existing average ability - is the only
-- way to fill the remaining gap. Single pass per club (not per position
-- group, and skipping the per-league name-uniqueness check
-- _unique_player_name_for_league does) to stay within statement time
-- limits across ~1300 clubs - this is a one-time repair, not a path
-- worth optimizing for name uniqueness at this scale.
DO $$
DECLARE
  club_rec RECORD;
  chosen_pos TEXT;
  club_quality INT;
  gen_ca INT;
  gen_age INT;
  gen_pa INT;
  gk_need INT;
  def_need INT;
  mid_need INT;
  for_need INT;
  def_positions CONSTANT TEXT[] := ARRAY['CB','LB','RB'];
  mid_positions CONSTANT TEXT[] := ARRAY['CDM','CM','CAM','LM','RM'];
  for_positions CONSTANT TEXT[] := ARRAY['ST','LW','RW'];
  first_names CONSTANT TEXT[] := ARRAY['Ariel','Bruno','Cesar','Diego','Erik','Felix','Gustavo','Hugo','Ivan','Jonas','Kwame','Lars','Marco','Nils','Omar'];
  last_names CONSTANT TEXT[] := ARRAY['Aydin','Berg','Costa','Duarte','Eriksen','Fischer','Garcia','Hansen','Ibrahim','Jansen','Kovac','Lindberg','Martins','Novak','Oliveira'];
  slot RECORD;
BEGIN
  FOR club_rec IN
    SELECT c.id AS club_id,
      COALESCE((SELECT round(avg(current_ability)) FROM public.players WHERE club_id = c.id), 45) AS club_quality,
      (SELECT count(*) FROM public.players WHERE club_id = c.id AND position = 'GK') AS gk_count,
      (SELECT count(*) FROM public.players WHERE club_id = c.id AND position = ANY(def_positions)) AS def_count,
      (SELECT count(*) FROM public.players WHERE club_id = c.id AND position = ANY(mid_positions)) AS mid_count,
      (SELECT count(*) FROM public.players WHERE club_id = c.id AND position = ANY(for_positions)) AS for_count
    FROM public.clubs c
  LOOP
    gk_need := GREATEST(0, 3 - club_rec.gk_count);
    def_need := GREATEST(0, 8 - club_rec.def_count);
    mid_need := GREATEST(0, 6 - club_rec.mid_count);
    for_need := GREATEST(0, 7 - club_rec.for_count);

    CONTINUE WHEN gk_need = 0 AND def_need = 0 AND mid_need = 0 AND for_need = 0;

    club_quality := club_rec.club_quality;

    FOR slot IN
      SELECT 'GK'::text AS grp FROM generate_series(1, gk_need)
      UNION ALL SELECT def_positions[1 + floor(random() * 3)::int] FROM generate_series(1, def_need)
      UNION ALL SELECT mid_positions[1 + floor(random() * 5)::int] FROM generate_series(1, mid_need)
      UNION ALL SELECT for_positions[1 + floor(random() * 3)::int] FROM generate_series(1, for_need)
    LOOP
      chosen_pos := slot.grp;
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
        club_rec.club_id,
        first_names[1 + floor(random() * 15)::int] || ' ' || last_names[1 + floor(random() * 15)::int],
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
