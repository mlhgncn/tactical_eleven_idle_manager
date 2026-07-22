-- Critical bug fix: 20260723040000's _trim_club_squad_to_target had its
-- selection backwards. `ORDER BY current_ability ASC ... OFFSET
-- group_target` (no LIMIT) skips the LOWEST group_target rows and updates
-- EVERYTHING AFTER THE OFFSET - i.e. it released the group's BEST players
-- to free agency and kept the WORST ones, the exact opposite of the
-- stated intent ("lowest current_ability released first"). Fixed by
-- sorting DESC (best first) and offsetting past the players we want to
-- keep, so only the excess LOWEST-ability players in each group get
-- released.
CREATE OR REPLACE FUNCTION public._trim_club_squad_to_target(p_club_id UUID, p_target_count INT)
RETURNS void AS $$
DECLARE
  group_targets JSONB := '{"GK": 3, "DEF": 8, "MID": 6, "FOR": 7}'::jsonb;
  group_key TEXT;
  group_target INT;
  group_positions TEXT[];
BEGIN
  FOR group_key, group_target IN SELECT * FROM jsonb_each_text(group_targets) LOOP
    group_target := GREATEST(0, ROUND(group_target::numeric * p_target_count / 24));

    group_positions := CASE group_key
      WHEN 'GK' THEN ARRAY['GK']
      WHEN 'DEF' THEN ARRAY['CB', 'LB', 'RB']
      WHEN 'MID' THEN ARRAY['CDM', 'CM', 'CAM', 'LM', 'RM']
      ELSE ARRAY['ST', 'LW', 'RW']
    END;

    UPDATE public.players
    SET club_id = NULL
    WHERE id IN (
      SELECT id FROM public.players
      WHERE club_id = p_club_id AND position = ANY(group_positions)
      ORDER BY current_ability DESC, id ASC
      OFFSET group_target
    );
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
