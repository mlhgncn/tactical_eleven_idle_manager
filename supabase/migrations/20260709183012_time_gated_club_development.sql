-- Club development (stadium capacity + training facility level) used to
-- complete instantly. Make these two take time (like sponsor upgrades),
-- with a higher cost than before, one "construction slot" at a time, and
-- existing max levels preserved (stadium 100000, facility 10). Ticket
-- price stays instant - it's a pricing decision, not construction.
ALTER TABLE public.clubs
  ADD COLUMN IF NOT EXISTS development_upgrade_type TEXT,
  ADD COLUMN IF NOT EXISTS development_target_value INT,
  ADD COLUMN IF NOT EXISTS development_completes_at TIMESTAMPTZ;

DROP FUNCTION IF EXISTS public.upgrade_club(uuid, integer, integer, integer);

-- Ticket price only now; stadium/facility moved to start_club_development.
CREATE OR REPLACE FUNCTION public.upgrade_club(
  p_club_id UUID,
  p_ticket_price INT
)
RETURNS public.clubs AS $$
DECLARE
  current_club public.clubs%ROWTYPE;
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

  IF p_ticket_price IS NULL OR p_ticket_price <= current_club.ticket_price THEN
    RAISE EXCEPTION 'Ticket price must be higher than current price';
  END IF;

  IF current_club.budget < 500 THEN
    RAISE EXCEPTION 'Not enough budget for upgrade';
  END IF;

  UPDATE public.clubs
  SET budget = current_club.budget - 500,
      ticket_price = p_ticket_price
  WHERE id = p_club_id
  RETURNING * INTO updated_row;

  INSERT INTO public.financial_transactions(club_id, type, amount, description, source)
  VALUES (p_club_id, 'upgrade_club', -500, 'Bilet fiyatı güncelleme harcaması: -500 GP', 'upgrade_club');

  RETURN updated_row;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.start_club_development(
  p_club_id UUID,
  p_upgrade_type TEXT,
  p_target_value INT
)
RETURNS public.clubs AS $$
DECLARE
  current_club public.clubs%ROWTYPE;
  updated_row public.clubs;
  total_cost BIGINT;
  duration_days INT;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated user cannot upgrade club';
  END IF;

  IF p_upgrade_type NOT IN ('stadium', 'facility') THEN
    RAISE EXCEPTION 'Invalid upgrade type';
  END IF;

  SELECT * INTO current_club
  FROM public.clubs
  WHERE id = p_club_id
    AND user_id = auth.uid();

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Club not found or not owned by current user';
  END IF;

  IF current_club.development_completes_at IS NOT NULL AND current_club.development_completes_at > now() THEN
    RAISE EXCEPTION 'A club development upgrade is already in progress';
  END IF;

  IF p_upgrade_type = 'stadium' THEN
    IF p_target_value <= current_club.stadium_capacity THEN
      RAISE EXCEPTION 'Stadium capacity must be higher than current capacity';
    END IF;
    IF p_target_value > 100000 THEN
      RAISE EXCEPTION 'Stadium capacity cannot exceed 100000';
    END IF;
    -- Double the old instant-upgrade cost formula.
    total_cost := 2 * (1000 + (p_target_value / 1000));
    -- The bigger the stadium already is, the longer further expansion
    -- takes: +1 day of construction per 5000 capacity already built,
    -- capped at 14 days so late-game expansions stay reasonable.
    duration_days := LEAST(14, 1 + FLOOR((current_club.stadium_capacity - 15000) / 5000));
  ELSE
    IF p_target_value <= current_club.training_facility_level THEN
      RAISE EXCEPTION 'Training facility level must be higher than current level';
    END IF;
    IF p_target_value > 10 THEN
      RAISE EXCEPTION 'Training facility level cannot exceed 10';
    END IF;
    -- Double the old instant-upgrade cost formula.
    total_cost := 2 * (2000 + (p_target_value * 1500));
    -- 1, 3, 5 ... days as level increases, same pattern as sponsor upgrades.
    duration_days := 2 * current_club.training_facility_level - 1;
  END IF;

  IF current_club.budget < total_cost THEN
    RAISE EXCEPTION 'Not enough budget for upgrade';
  END IF;

  UPDATE public.clubs
  SET budget = current_club.budget - total_cost,
      development_upgrade_type = p_upgrade_type,
      development_target_value = p_target_value,
      development_completes_at = now() + make_interval(days => duration_days)
  WHERE id = p_club_id
  RETURNING * INTO updated_row;

  INSERT INTO public.financial_transactions(club_id, type, amount, description, source)
  VALUES (
    p_club_id,
    'upgrade_club',
    -total_cost,
    format('Kulüp geliştirme harcaması: -%s GP (%s gün sürecek)', total_cost, duration_days),
    'upgrade_club'
  );

  RETURN updated_row;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.process_club_upgrades()
RETURNS void AS $$
DECLARE
  club_row public.clubs%ROWTYPE;
  message_title TEXT;
  message_body TEXT;
BEGIN
  FOR club_row IN
    SELECT * FROM public.clubs
    WHERE development_completes_at IS NOT NULL AND development_completes_at <= now()
  LOOP
    IF club_row.development_upgrade_type = 'stadium' THEN
      UPDATE public.clubs
      SET stadium_capacity = club_row.development_target_value,
          development_upgrade_type = NULL,
          development_target_value = NULL,
          development_completes_at = NULL
      WHERE id = club_row.id;
      message_title := 'Stadyum Genişletildi';
      message_body := format('Stadyum kapasitesi %s kişiye yükseltildi!', club_row.development_target_value);
    ELSIF club_row.development_upgrade_type = 'facility' THEN
      UPDATE public.clubs
      SET training_facility_level = club_row.development_target_value,
          development_upgrade_type = NULL,
          development_target_value = NULL,
          development_completes_at = NULL
      WHERE id = club_row.id;
      message_title := 'Tesis Yükseltmesi';
      message_body := format('Tesis seviyesi %s''e yükseltildi!', club_row.development_target_value);
    ELSE
      UPDATE public.clubs
      SET development_upgrade_type = NULL,
          development_target_value = NULL,
          development_completes_at = NULL
      WHERE id = club_row.id;
      CONTINUE;
    END IF;

    IF club_row.user_id IS NOT NULL THEN
      INSERT INTO public.inbox_messages(recipient_id, title, body, is_read, created_at)
      VALUES (club_row.user_id, message_title, message_body, false, now());
    END IF;
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
