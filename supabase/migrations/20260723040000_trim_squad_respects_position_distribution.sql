-- _trim_club_squad_to_target (20260723030000) trimmed purely by lowest
-- current_ability across the whole squad, ignoring position - a claimed
-- club could easily lose every goalkeeper or every center-back if those
-- happened to be its weakest-rated players, leaving an unplayable squad.
-- Trim per position group instead, using the same target distribution
-- generate_squad_for_club uses for a fresh 24-player squad (3 GK, 8 DEF,
-- 6 MID, 7 FOR), so a trimmed club ends up shaped the same way a
-- freshly-generated one would - lowest current_ability released first,
-- but only within each group's own excess over its target count.
CREATE OR REPLACE FUNCTION public._trim_club_squad_to_target(p_club_id UUID, p_target_count INT)
RETURNS void AS $$
DECLARE
  group_targets JSONB := '{"GK": 3, "DEF": 8, "MID": 6, "FOR": 7}'::jsonb;
  group_key TEXT;
  group_target INT;
  group_positions TEXT[];
BEGIN
  -- Scales the fixed 24-player group targets proportionally if ever called
  -- with a different target count, instead of hardcoding 24.
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
      ORDER BY current_ability ASC, id ASC
      OFFSET group_target
    );
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
