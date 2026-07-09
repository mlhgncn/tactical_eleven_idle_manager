-- Ticket price becomes a time-gated club development upgrade too (same
-- construction-slot system as stadium/facility), and all three get more
-- realistic values: stadium expands in bigger, meaningful increments with
-- cost that scales with how large the stadium already is; training
-- facility and ticket price cost scale with target level instead of the
-- old flat-ish formulas that were trivially cheap next to weekly match
-- income (~50-200k GP/week for a mid-table club).
ALTER TABLE public.clubs
  ADD COLUMN IF NOT EXISTS ticket_price_level INT NOT NULL DEFAULT 1;

-- upgrade_club (instant ticket price change) is fully replaced by the
-- timed path below - drop it, nothing else references it.
DROP FUNCTION IF EXISTS public.upgrade_club(uuid, integer);

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
  capacity_increment INT;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated user cannot upgrade club';
  END IF;

  IF p_upgrade_type NOT IN ('stadium', 'facility', 'ticket_price') THEN
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
    capacity_increment := p_target_value - current_club.stadium_capacity;
    -- 15 GP per new seat, plus a premium that grows with how large the
    -- stadium already is (expanding a big stadium costs more per seat
    -- than expanding a small one).
    total_cost := (capacity_increment * 15) + ((current_club.stadium_capacity::BIGINT * capacity_increment) / 50000);
    duration_days := LEAST(14, 1 + FLOOR((current_club.stadium_capacity - 15000) / 10000));
  ELSIF p_upgrade_type = 'facility' THEN
    IF p_target_value <= current_club.training_facility_level THEN
      RAISE EXCEPTION 'Training facility level must be higher than current level';
    END IF;
    IF p_target_value > 10 THEN
      RAISE EXCEPTION 'Training facility level cannot exceed 10';
    END IF;
    total_cost := p_target_value * 15000;
    duration_days := 2 * current_club.training_facility_level - 1;
  ELSE
    IF p_target_value <= current_club.ticket_price_level THEN
      RAISE EXCEPTION 'Ticket price level must be higher than current level';
    END IF;
    IF p_target_value > 10 THEN
      RAISE EXCEPTION 'Ticket price level cannot exceed 10';
    END IF;
    total_cost := p_target_value * 6000;
    duration_days := 2 * current_club.ticket_price_level - 1;
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
  new_ticket_price INT;
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
    ELSIF club_row.development_upgrade_type = 'ticket_price' THEN
      -- Level -> price ladder: 20 GP base, +8 GP per level (level 1 = 20, level 10 = 92).
      new_ticket_price := 20 + (club_row.development_target_value - 1) * 8;
      UPDATE public.clubs
      SET ticket_price = new_ticket_price,
          ticket_price_level = club_row.development_target_value,
          development_upgrade_type = NULL,
          development_target_value = NULL,
          development_completes_at = NULL
      WHERE id = club_row.id;
      message_title := 'Bilet Fiyatı Güncellendi';
      message_body := format('Bilet fiyatı %s GP oldu!', new_ticket_price);
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
