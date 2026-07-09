-- Replace the multi-factor (minutes/facility/morale/form) development
-- formula with the requested simpler spec: every session takes a fixed
-- 2 hours and grants a random 1-3% ability increase, capped at both 99
-- and the player's own potential (you can't out-train your ceiling).
-- The old pending_* input columns are no longer needed since there are
-- no more per-session inputs to remember.
ALTER TABLE public.players
  DROP COLUMN IF EXISTS development_pending_minutes,
  DROP COLUMN IF EXISTS development_pending_training_facility_level,
  DROP COLUMN IF EXISTS development_pending_morale,
  DROP COLUMN IF EXISTS development_pending_form_rating;

CREATE OR REPLACE FUNCTION public.start_player_development(p_player_id UUID)
RETURNS public.players AS $$
DECLARE
  player_row public.players%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated user cannot start player development';
  END IF;

  SELECT * INTO player_row
  FROM public.players
  WHERE id = p_player_id
    AND club_id = (SELECT id FROM public.clubs WHERE user_id = auth.uid() LIMIT 1);

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Player not found or not owned by current user''s club';
  END IF;

  IF player_row.development_completes_at IS NOT NULL AND player_row.development_completes_at > now() THEN
    RAISE EXCEPTION 'Player development already in progress';
  END IF;

  IF player_row.current_ability >= player_row.potential_ability THEN
    RAISE EXCEPTION 'Player has already reached their potential';
  END IF;

  UPDATE public.players
  SET development_completes_at = now() + interval '2 hours'
  WHERE id = p_player_id
  RETURNING * INTO player_row;

  RETURN player_row;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.process_player_development()
RETURNS void AS $$
DECLARE
  player_row public.players%ROWTYPE;
  growth_percent DOUBLE PRECISION;
  growth_delta INT;
  new_current_ability INT;
  owner_id UUID;
BEGIN
  FOR player_row IN
    SELECT * FROM public.players
    WHERE development_completes_at IS NOT NULL AND development_completes_at <= now()
  LOOP
    -- Random 1% - 3% of current ability, at least 1 point, never past
    -- 99 or the player's own potential.
    growth_percent := 0.01 + random() * 0.02;
    growth_delta := GREATEST(1, ROUND(player_row.current_ability * growth_percent));
    new_current_ability := LEAST(99, LEAST(player_row.potential_ability, player_row.current_ability + growth_delta));

    UPDATE public.players
    SET current_ability = new_current_ability,
        development_completes_at = NULL
    WHERE id = player_row.id;

    IF player_row.club_id IS NOT NULL THEN
      SELECT user_id INTO owner_id FROM public.clubs WHERE id = player_row.club_id;
      IF owner_id IS NOT NULL THEN
        INSERT INTO public.inbox_messages(recipient_id, title, body, is_read, created_at)
        VALUES (
          owner_id,
          'Oyuncu Gelişimi',
          format('%s gelişimini tamamladı! Yeni güç: %s (+%s)', player_row.name, new_current_ability, new_current_ability - player_row.current_ability),
          false,
          now()
        );
      END IF;
    END IF;
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
