-- Free-position lineup placement: a starter's actual (x, y) coordinate on
-- the pitch (not a fixed formation slot) now drives their effective
-- position group in the match engine. starting_eleven_ids is kept as-is
-- (it's still the source of truth for "who's in the starting XI" and
-- lets old rows / clients with no positions saved yet keep working via
-- the existing slot-based fallback) - this just adds a parallel JSONB map
-- from player_id to their {x, y} on the pitch. NULL means "no free
-- positions saved for this club yet", so both match_engine.ts and the
-- Flutter client fall back to the fixed per-formation slot layout.
ALTER TABLE public.tactics
  ADD COLUMN IF NOT EXISTS starting_eleven_positions JSONB;
