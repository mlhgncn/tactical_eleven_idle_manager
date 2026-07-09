-- Player development ("Gelişimi uygula") used to apply growth synchronously
-- in a single call. Turn it into a timed session: starting development
-- stores the inputs and a completion timestamp; a cron tick applies the
-- growth once the timestamp has passed, whether or not the app is open.
ALTER TABLE public.players
  ADD COLUMN IF NOT EXISTS development_completes_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS development_pending_minutes INT,
  ADD COLUMN IF NOT EXISTS development_pending_training_facility_level INT,
  ADD COLUMN IF NOT EXISTS development_pending_morale INT,
  ADD COLUMN IF NOT EXISTS development_pending_form_rating DOUBLE PRECISION;

-- Starts a development session for a player owned by the caller's club.
-- advance_player_development previously had no ownership check at all
-- (any authenticated user could call it against any player_id since it's
-- SECURITY DEFINER and bypasses RLS) - closing that here.
CREATE OR REPLACE FUNCTION public.start_player_development(
  p_player_id UUID,
  p_minutes_played INT DEFAULT 90,
  p_training_facility_level INT DEFAULT 1,
  p_morale INT DEFAULT 75,
  p_form_rating DOUBLE PRECISION DEFAULT 0.0
)
RETURNS public.players AS $$
DECLARE
  player_row public.players%ROWTYPE;
  duration_hours INT;
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

  duration_hours := 2 + GREATEST(0, LEAST(180, p_minutes_played)) / 30;

  UPDATE public.players
  SET development_completes_at = now() + make_interval(hours => duration_hours),
      development_pending_minutes = p_minutes_played,
      development_pending_training_facility_level = p_training_facility_level,
      development_pending_morale = p_morale,
      development_pending_form_rating = p_form_rating
  WHERE id = p_player_id
  RETURNING * INTO player_row;

  RETURN player_row;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Cron-driven: applies growth for every player whose development session
-- has completed, using the exact math advance_player_development used to
-- apply synchronously. Runs with no user context (see process_timed_upgrades).
CREATE OR REPLACE FUNCTION public.process_player_development()
RETURNS void AS $$
DECLARE
  player_row public.players%ROWTYPE;
  age_factor DOUBLE PRECISION;
  potential_factor DOUBLE PRECISION;
  training_factor DOUBLE PRECISION;
  minutes_factor DOUBLE PRECISION;
  morale_factor DOUBLE PRECISION;
  form_factor DOUBLE PRECISION;
  growth_delta INT;
  new_current_ability INT;
  new_fitness INT;
  new_morale INT;
  new_form_rating DOUBLE PRECISION;
  owner_id UUID;
BEGIN
  FOR player_row IN
    SELECT * FROM public.players
    WHERE development_completes_at IS NOT NULL AND development_completes_at <= now()
  LOOP
    IF player_row.age < 16 THEN
      age_factor := 0.85;
    ELSIF player_row.age BETWEEN 16 AND 23 THEN
      age_factor := 1.25;
    ELSIF player_row.age BETWEEN 24 AND 29 THEN
      age_factor := 0.95;
    ELSE
      age_factor := 0.75;
    END IF;

    potential_factor := (player_row.potential_ability / 100.0) * 0.9;
    training_factor := GREATEST(1, COALESCE(player_row.development_pending_training_facility_level, 1)) * 0.6;
    minutes_factor := LEAST(1.0, GREATEST(0.0, COALESCE(player_row.development_pending_minutes, 90)::DOUBLE PRECISION / 180.0));
    morale_factor := 1.0 + ((COALESCE(player_row.development_pending_morale, 75) - 75) / 100.0) * 0.15;
    form_factor := 1.0 + (COALESCE(player_row.development_pending_form_rating, 0.0) / 100.0) * 0.1;

    growth_delta := ROUND((8.0 + (player_row.potential_ability - player_row.current_ability) * 0.02) * age_factor * potential_factor * training_factor * minutes_factor * morale_factor * form_factor);
    new_current_ability := LEAST(99, GREATEST(1, player_row.current_ability + growth_delta));
    new_fitness := LEAST(100, GREATEST(40, player_row.fitness + ROUND(growth_delta * 0.15)));
    new_morale := LEAST(100, GREATEST(30, player_row.morale + ROUND(growth_delta * 0.03)));
    new_form_rating := LEAST(100.0, GREATEST(0.0, player_row.form_rating + (growth_delta * 0.15)));

    UPDATE public.players
    SET current_ability = new_current_ability,
        fitness = new_fitness,
        morale = new_morale,
        form_rating = new_form_rating,
        development_completes_at = NULL,
        development_pending_minutes = NULL,
        development_pending_training_facility_level = NULL,
        development_pending_morale = NULL,
        development_pending_form_rating = NULL
    WHERE id = player_row.id;

    IF player_row.club_id IS NOT NULL THEN
      SELECT user_id INTO owner_id FROM public.clubs WHERE id = player_row.club_id;
      IF owner_id IS NOT NULL THEN
        INSERT INTO public.inbox_messages(recipient_id, title, body, is_read, created_at)
        VALUES (
          owner_id,
          'Oyuncu Gelişimi',
          format('%s gelişimini tamamladı! Yeni güç: %s', player_row.name, new_current_ability),
          false,
          now()
        );
      END IF;
    END IF;
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
