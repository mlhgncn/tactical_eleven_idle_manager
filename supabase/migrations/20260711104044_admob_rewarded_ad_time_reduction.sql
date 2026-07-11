-- AdMob rewarded-ad integration: watching a rewarded ad while a player
-- development or club development (stadium/facility/ticket price) is in
-- progress cuts the REMAINING time by 25%, up to 2 times per development
-- session. The counter resets whenever a new development starts and when
-- one completes, so it's always "2 uses per session", not lifetime.

ALTER TABLE public.players ADD COLUMN IF NOT EXISTS development_ad_uses INT NOT NULL DEFAULT 0;
ALTER TABLE public.clubs ADD COLUMN IF NOT EXISTS development_ad_uses INT NOT NULL DEFAULT 0;

-- start_player_development: reset the ad-use counter for the new session.
CREATE OR REPLACE FUNCTION public.start_player_development(p_player_id uuid)
 RETURNS players
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  player_row public.players%ROWTYPE;
  owner_club_id UUID;
  target_group text;
  conflicting_player_name text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated user cannot start player development';
  END IF;

  SELECT id INTO owner_club_id FROM public.clubs WHERE user_id = auth.uid() LIMIT 1;

  SELECT * INTO player_row
  FROM public.players
  WHERE id = p_player_id
    AND club_id = owner_club_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Player not found or not owned by current user''s club';
  END IF;

  IF player_row.development_completes_at IS NOT NULL AND player_row.development_completes_at > now() THEN
    RAISE EXCEPTION 'Player development already in progress';
  END IF;

  IF player_row.current_ability >= player_row.potential_ability THEN
    RAISE EXCEPTION 'Player has already reached their potential';
  END IF;

  target_group := public.position_group_of(player_row.position);

  SELECT name INTO conflicting_player_name
  FROM public.players
  WHERE club_id = owner_club_id
    AND id != p_player_id
    AND development_completes_at IS NOT NULL
    AND development_completes_at > now()
    AND public.position_group_of(position) = target_group
  LIMIT 1;

  IF conflicting_player_name IS NOT NULL THEN
    RAISE EXCEPTION 'Bu mevki grubunda zaten bir gelişim sürüyor (%).', conflicting_player_name;
  END IF;

  UPDATE public.players
  SET development_completes_at = now() + interval '2 hours',
      development_ad_uses = 0
  WHERE id = p_player_id
  RETURNING * INTO player_row;

  RETURN player_row;
END;
$function$;

-- start_club_development: reset the ad-use counter for the new session.
CREATE OR REPLACE FUNCTION public.start_club_development(p_club_id uuid, p_upgrade_type text, p_target_value integer)
 RETURNS clubs
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
      development_completes_at = now() + make_interval(days => duration_days),
      development_ad_uses = 0
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
$function$;

-- process_player_development: reset the counter when a session completes.
CREATE OR REPLACE FUNCTION public.process_player_development()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
    growth_percent := 0.01 + random() * 0.02;
    growth_delta := GREATEST(1, ROUND(player_row.current_ability * growth_percent));
    new_current_ability := LEAST(99, LEAST(player_row.potential_ability, player_row.current_ability + growth_delta));

    UPDATE public.players
    SET current_ability = new_current_ability,
        development_completes_at = NULL,
        development_ad_uses = 0
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
$function$;

-- process_club_upgrades: reset the counter when a session completes.
CREATE OR REPLACE FUNCTION public.process_club_upgrades()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
          development_completes_at = NULL,
          development_ad_uses = 0
      WHERE id = club_row.id;
      message_title := 'Stadyum Genişletildi';
      message_body := format('Stadyum kapasitesi %s kişiye yükseltildi!', club_row.development_target_value);
    ELSIF club_row.development_upgrade_type = 'facility' THEN
      UPDATE public.clubs
      SET training_facility_level = club_row.development_target_value,
          development_upgrade_type = NULL,
          development_target_value = NULL,
          development_completes_at = NULL,
          development_ad_uses = 0
      WHERE id = club_row.id;
      message_title := 'Tesis Yükseltmesi';
      message_body := format('Tesis seviyesi %s''e yükseltildi!', club_row.development_target_value);
    ELSIF club_row.development_upgrade_type = 'ticket_price' THEN
      new_ticket_price := 20 + (club_row.development_target_value - 1) * 8;
      UPDATE public.clubs
      SET ticket_price = new_ticket_price,
          ticket_price_level = club_row.development_target_value,
          development_upgrade_type = NULL,
          development_target_value = NULL,
          development_completes_at = NULL,
          development_ad_uses = 0
      WHERE id = club_row.id;
      message_title := 'Bilet Fiyatı Güncellendi';
      message_body := format('Bilet fiyatı %s GP oldu!', new_ticket_price);
    ELSE
      UPDATE public.clubs
      SET development_upgrade_type = NULL,
          development_target_value = NULL,
          development_completes_at = NULL,
          development_ad_uses = 0
      WHERE id = club_row.id;
      CONTINUE;
    END IF;

    IF club_row.user_id IS NOT NULL THEN
      INSERT INTO public.inbox_messages(recipient_id, title, body, is_read, created_at)
      VALUES (club_row.user_id, message_title, message_body, false, now());
    END IF;
  END LOOP;
END;
$function$;

-- Watch a rewarded ad to cut a player's remaining development time by 25%
-- (compounding), max 2 uses per development session.
CREATE OR REPLACE FUNCTION public.reduce_player_development_time_with_ad(p_player_id uuid)
RETURNS public.players AS $$
DECLARE
  player_row public.players%ROWTYPE;
  owner_club_id UUID;
  remaining INTERVAL;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated user cannot reduce development time';
  END IF;

  SELECT id INTO owner_club_id FROM public.clubs WHERE user_id = auth.uid() LIMIT 1;

  SELECT * INTO player_row FROM public.players WHERE id = p_player_id AND club_id = owner_club_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Player not found or not owned by current user''s club';
  END IF;

  IF player_row.development_completes_at IS NULL OR player_row.development_completes_at <= now() THEN
    RAISE EXCEPTION 'No active development to speed up';
  END IF;

  IF player_row.development_ad_uses >= 2 THEN
    RAISE EXCEPTION 'Bu gelişim için reklam hakkınız kalmadı (en fazla 2 kez).';
  END IF;

  remaining := player_row.development_completes_at - now();

  UPDATE public.players
  SET development_completes_at = now() + (remaining * 0.75),
      development_ad_uses = development_ad_uses + 1
  WHERE id = p_player_id
  RETURNING * INTO player_row;

  RETURN player_row;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Same for club development (stadium/facility/ticket price).
CREATE OR REPLACE FUNCTION public.reduce_club_development_time_with_ad(p_club_id uuid)
RETURNS public.clubs AS $$
DECLARE
  club_row public.clubs%ROWTYPE;
  remaining INTERVAL;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated user cannot reduce development time';
  END IF;

  SELECT * INTO club_row FROM public.clubs WHERE id = p_club_id AND user_id = auth.uid();
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Club not found or not owned by current user';
  END IF;

  IF club_row.development_completes_at IS NULL OR club_row.development_completes_at <= now() THEN
    RAISE EXCEPTION 'No active development to speed up';
  END IF;

  IF club_row.development_ad_uses >= 2 THEN
    RAISE EXCEPTION 'Bu gelişim için reklam hakkınız kalmadı (en fazla 2 kez).';
  END IF;

  remaining := club_row.development_completes_at - now();

  UPDATE public.clubs
  SET development_completes_at = now() + (remaining * 0.75),
      development_ad_uses = development_ad_uses + 1
  WHERE id = p_club_id
  RETURNING * INTO club_row;

  RETURN club_row;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
