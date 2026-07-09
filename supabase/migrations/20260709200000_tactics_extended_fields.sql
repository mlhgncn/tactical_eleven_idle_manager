-- The tactics screen redesign adds press intensity, tempo, defensive line
-- sliders, offside-trap/time-wasting toggles, and separate free-kick/corner
-- takers (previously only captain_id/penalty_taker_id existed). These are
-- the same kind of self-contained, persisted-but-not-yet-simulated fields
-- as the existing captain_id/penalty_taker_id (match_engine.ts only reads
-- formation+mentality today) - saving/loading works fully, match-sim
-- effects can follow as a separate change.
ALTER TABLE public.tactics
  ADD COLUMN IF NOT EXISTS free_kick_taker_id UUID REFERENCES public.players(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS corner_taker_id UUID REFERENCES public.players(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS press_intensity INT NOT NULL DEFAULT 50,
  ADD COLUMN IF NOT EXISTS tempo INT NOT NULL DEFAULT 50,
  ADD COLUMN IF NOT EXISTS defensive_line INT NOT NULL DEFAULT 50,
  ADD COLUMN IF NOT EXISTS offside_trap BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS time_wasting BOOLEAN NOT NULL DEFAULT false;
