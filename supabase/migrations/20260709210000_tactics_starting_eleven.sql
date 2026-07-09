-- The squad screen's pitch view only ever showed an auto-picked "best XI"
-- with no way to move a bench player into the lineup. Persist an explicit
-- starting XI (one player id per formation slot, in slot order) so a manual
-- swap sticks - NULL means "no manual lineup set, keep auto-picking".
ALTER TABLE public.tactics
  ADD COLUMN IF NOT EXISTS starting_eleven_ids UUID[];
