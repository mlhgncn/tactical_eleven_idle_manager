-- Tactic preset library: a club can save multiple named formation/
-- mentality/slider combinations and re-apply one before a match instead
-- of re-adjusting sliders every time. Deliberately excludes
-- starting_eleven_ids and the set-piece taker ids (captain/penalty/
-- freekick/corner) - those are player-specific and the squad a preset
-- was saved against may not match the squad it's applied to later
-- (transfers, injuries), so a preset only carries the tactical shape,
-- never player assignments. tactics.club_id is a PRIMARY KEY (exactly
-- one live tactics row per club), so presets need their own table rather
-- than extending it.
CREATE TABLE IF NOT EXISTS public.tactic_presets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  club_id UUID NOT NULL REFERENCES public.clubs(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  formation TEXT NOT NULL,
  mentality TEXT NOT NULL,
  press_intensity INT NOT NULL DEFAULT 50,
  tempo INT NOT NULL DEFAULT 50,
  defensive_line INT NOT NULL DEFAULT 50,
  offside_trap BOOLEAN NOT NULL DEFAULT false,
  time_wasting BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (club_id, name)
);

CREATE INDEX IF NOT EXISTS idx_tactic_presets_club_id ON public.tactic_presets(club_id);

ALTER TABLE public.tactic_presets ENABLE ROW LEVEL SECURITY;

-- Same "owner of the club can CRUD" pattern as the tactics table itself.
DROP POLICY IF EXISTS tactic_presets_select_policy ON public.tactic_presets;
CREATE POLICY tactic_presets_select_policy ON public.tactic_presets
FOR SELECT USING (EXISTS (SELECT 1 FROM public.clubs c WHERE c.id = tactic_presets.club_id AND c.user_id = auth.uid()));

DROP POLICY IF EXISTS tactic_presets_insert_policy ON public.tactic_presets;
CREATE POLICY tactic_presets_insert_policy ON public.tactic_presets
FOR INSERT WITH CHECK (EXISTS (SELECT 1 FROM public.clubs c WHERE c.id = tactic_presets.club_id AND c.user_id = auth.uid()));

DROP POLICY IF EXISTS tactic_presets_update_policy ON public.tactic_presets;
CREATE POLICY tactic_presets_update_policy ON public.tactic_presets
FOR UPDATE
USING (EXISTS (SELECT 1 FROM public.clubs c WHERE c.id = tactic_presets.club_id AND c.user_id = auth.uid()))
WITH CHECK (EXISTS (SELECT 1 FROM public.clubs c WHERE c.id = tactic_presets.club_id AND c.user_id = auth.uid()));

DROP POLICY IF EXISTS tactic_presets_delete_policy ON public.tactic_presets;
CREATE POLICY tactic_presets_delete_policy ON public.tactic_presets
FOR DELETE USING (EXISTS (SELECT 1 FROM public.clubs c WHERE c.id = tactic_presets.club_id AND c.user_id = auth.uid()));

-- Saves (or overwrites, by name) a preset for the caller's club. Caps at
-- 8 presets per club so the library doesn't grow unbounded.
CREATE OR REPLACE FUNCTION public.save_tactic_preset(
  p_club_id UUID,
  p_name TEXT,
  p_formation TEXT,
  p_mentality TEXT,
  p_press_intensity INT,
  p_tempo INT,
  p_defensive_line INT,
  p_offside_trap BOOLEAN,
  p_time_wasting BOOLEAN
)
RETURNS public.tactic_presets AS $$
DECLARE
  owned_club_id UUID;
  preset_count INT;
  result_row public.tactic_presets;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated user cannot save a tactic preset';
  END IF;
  IF p_name IS NULL OR length(trim(p_name)) = 0 THEN
    RAISE EXCEPTION 'Şablon adı boş olamaz.';
  END IF;

  SELECT id INTO owned_club_id FROM public.clubs WHERE id = p_club_id AND user_id = auth.uid();
  IF owned_club_id IS NULL THEN
    RAISE EXCEPTION 'Bu kulübe sahip değilsiniz.';
  END IF;

  SELECT count(*) INTO preset_count
  FROM public.tactic_presets
  WHERE club_id = p_club_id AND name <> trim(p_name);
  IF preset_count >= 8 THEN
    RAISE EXCEPTION 'En fazla 8 taktik şablonu kaydedebilirsiniz.';
  END IF;

  INSERT INTO public.tactic_presets (
    club_id, name, formation, mentality, press_intensity, tempo, defensive_line, offside_trap, time_wasting
  ) VALUES (
    p_club_id, trim(p_name), p_formation, p_mentality, p_press_intensity, p_tempo, p_defensive_line, p_offside_trap, p_time_wasting
  )
  ON CONFLICT (club_id, name) DO UPDATE SET
    formation = EXCLUDED.formation,
    mentality = EXCLUDED.mentality,
    press_intensity = EXCLUDED.press_intensity,
    tempo = EXCLUDED.tempo,
    defensive_line = EXCLUDED.defensive_line,
    offside_trap = EXCLUDED.offside_trap,
    time_wasting = EXCLUDED.time_wasting
  RETURNING * INTO result_row;

  RETURN result_row;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Applies a saved preset's tactical shape onto the club's live tactics
-- row. Never touches starting_eleven_ids or the set-piece taker ids -
-- only the formation/mentality/slider fields the preset actually holds.
CREATE OR REPLACE FUNCTION public.apply_tactic_preset(p_preset_id UUID, p_club_id UUID DEFAULT NULL)
RETURNS public.tactics AS $$
DECLARE
  preset_row public.tactic_presets%ROWTYPE;
  target_club_id UUID;
  result_row public.tactics;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated user cannot apply a tactic preset';
  END IF;

  SELECT * INTO preset_row FROM public.tactic_presets WHERE id = p_preset_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Şablon bulunamadı.';
  END IF;

  IF p_club_id IS NOT NULL THEN
    SELECT id INTO target_club_id FROM public.clubs WHERE id = p_club_id AND user_id = auth.uid();
  ELSE
    SELECT id INTO target_club_id FROM public.clubs WHERE user_id = auth.uid() LIMIT 1;
  END IF;
  IF target_club_id IS NULL THEN
    RAISE EXCEPTION 'Bir kulübünüz yok';
  END IF;

  IF preset_row.club_id <> target_club_id THEN
    RAISE EXCEPTION 'Bu şablon bu kulübe ait değil.';
  END IF;

  INSERT INTO public.tactics (club_id, formation, mentality, press_intensity, tempo, defensive_line, offside_trap, time_wasting)
  VALUES (target_club_id, preset_row.formation, preset_row.mentality, preset_row.press_intensity, preset_row.tempo, preset_row.defensive_line, preset_row.offside_trap, preset_row.time_wasting)
  ON CONFLICT (club_id) DO UPDATE SET
    formation = EXCLUDED.formation,
    mentality = EXCLUDED.mentality,
    press_intensity = EXCLUDED.press_intensity,
    tempo = EXCLUDED.tempo,
    defensive_line = EXCLUDED.defensive_line,
    offside_trap = EXCLUDED.offside_trap,
    time_wasting = EXCLUDED.time_wasting
  RETURNING * INTO result_row;

  RETURN result_row;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.delete_tactic_preset(p_preset_id UUID)
RETURNS void AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated user cannot delete a tactic preset';
  END IF;

  DELETE FROM public.tactic_presets tp
  USING public.clubs c
  WHERE tp.id = p_preset_id AND tp.club_id = c.id AND c.user_id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.tactic_presets TO authenticated;
GRANT EXECUTE ON FUNCTION public.save_tactic_preset(UUID, TEXT, TEXT, TEXT, INT, INT, INT, BOOLEAN, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION public.apply_tactic_preset(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.delete_tactic_preset(UUID) TO authenticated;
