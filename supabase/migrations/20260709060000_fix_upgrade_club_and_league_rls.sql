-- Parameters were previously named exactly like the public.clubs columns
-- they set (stadium_capacity, training_facility_level, ticket_price), which
-- made every bare reference inside the UPDATE's COALESCE() calls ambiguous
-- between the plpgsql parameter and the table column - plpgsql's default
-- variable_conflict=error setting made this raise on every single call, so
-- stadium/facility/ticket-price upgrades always failed. p_-prefixed names
-- (matching the convention used by every other function) remove the
-- collision. Postgres refuses to rename a parameter via CREATE OR REPLACE,
-- so the old signature is dropped first.
DROP FUNCTION IF EXISTS public.upgrade_club(uuid, integer, integer, integer);

CREATE OR REPLACE FUNCTION public.upgrade_club(
  p_club_id UUID,
  p_stadium_capacity INT,
  p_training_facility_level INT,
  p_ticket_price INT
)
RETURNS public.clubs AS $$
DECLARE
  current_club public.clubs%ROWTYPE;
  total_cost BIGINT := 0;
  updated_row public.clubs;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated user cannot upgrade club';
  END IF;

  SELECT * INTO current_club
  FROM public.clubs
  WHERE id = p_club_id
    AND user_id = auth.uid();

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Club not found or not owned by current user';
  END IF;

  IF p_stadium_capacity IS NOT NULL AND p_stadium_capacity > current_club.stadium_capacity THEN
    IF p_stadium_capacity > 100000 THEN
      RAISE EXCEPTION 'Stadium capacity cannot exceed 100000';
    END IF;
    total_cost := total_cost + 1000 + (p_stadium_capacity / 1000);
  END IF;

  IF p_training_facility_level IS NOT NULL THEN
    IF p_training_facility_level <= current_club.training_facility_level THEN
      RAISE EXCEPTION 'Training facility level must be higher than current level';
    END IF;
    IF p_training_facility_level > 10 THEN
      RAISE EXCEPTION 'Training facility level cannot exceed 10';
    END IF;
    total_cost := total_cost + 2000 + (p_training_facility_level * 1500);
  END IF;

  IF p_ticket_price IS NOT NULL THEN
    IF p_ticket_price <= current_club.ticket_price THEN
      RAISE EXCEPTION 'Ticket price must be higher than current price';
    END IF;
    total_cost := total_cost + 500;
  END IF;

  IF current_club.budget < total_cost THEN
    RAISE EXCEPTION 'Not enough budget for upgrade';
  END IF;

  UPDATE public.clubs
  SET budget = current_club.budget - total_cost,
      stadium_capacity = COALESCE(p_stadium_capacity, current_club.stadium_capacity),
      training_facility_level = COALESCE(p_training_facility_level, current_club.training_facility_level),
      ticket_price = COALESCE(p_ticket_price, current_club.ticket_price)
  WHERE id = p_club_id
  RETURNING * INTO updated_row;

  INSERT INTO public.financial_transactions(club_id, type, amount, description, source)
  VALUES (
    p_club_id,
    'upgrade_club',
    -total_cost,
    format('Kulüp yükseltme harcaması: -%s GP', total_cost),
    'upgrade_club'
  );

  RETURN updated_row;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Any authenticated user can see any club (needed to show opponent/rival
-- club names in league standings, fixtures, and match history) - mutations
-- stay locked down to the owner via the existing insert/update policies.
DROP POLICY IF EXISTS clubs_select_policy ON public.clubs;
CREATE POLICY clubs_select_policy ON public.clubs FOR SELECT TO authenticated USING (auth.uid() IS NOT NULL);

-- leagues/seasons/league_standings had RLS enabled with no SELECT policy at
-- all, which silently returned zero rows for every user (no error) - the
-- league table, season name/week, and standings all appeared permanently
-- empty regardless of how much data existed server-side.
DROP POLICY IF EXISTS leagues_select_policy ON public.leagues;
CREATE POLICY leagues_select_policy ON public.leagues FOR SELECT TO authenticated USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS seasons_select_policy ON public.seasons;
CREATE POLICY seasons_select_policy ON public.seasons FOR SELECT TO authenticated USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS league_standings_select_policy ON public.league_standings;
CREATE POLICY league_standings_select_policy ON public.league_standings FOR SELECT TO authenticated USING (auth.uid() IS NOT NULL);
