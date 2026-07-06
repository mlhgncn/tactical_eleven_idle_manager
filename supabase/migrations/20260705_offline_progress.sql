ALTER TABLE public.clubs
ADD COLUMN IF NOT EXISTS last_activity_at TIMESTAMPTZ;

CREATE OR REPLACE FUNCTION public.simulate_offline_progress()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, row_security = off
AS $$
DECLARE
  current_user_id UUID := auth.uid();
  club_row public.clubs%ROWTYPE;
  now_ts TIMESTAMPTZ := now();
  last_activity TIMESTAMPTZ;
  offline_duration INTERVAL;
  max_reward_minutes INT := 24 * 60 * 3; -- 3 days
  reward_minutes INT;
  reward_multiplier NUMERIC := 1.0;
  income BIGINT := 0;
  matches_simulated INT := 0;
  players_improved INT := 0;
  transfer_offers INT := 0;
  inbox_messages_added INT := 0;
  bonus_income BIGINT := 0;
  result jsonb;
BEGIN
  IF current_user_id IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated user cannot simulate offline progress';
  END IF;

  SELECT * INTO club_row
  FROM public.clubs
  WHERE user_id = current_user_id
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'matchesSimulated', 0,
      'totalIncome', 0,
      'playersImproved', 0,
      'transferOffersReceived', 0,
      'inboxMessagesAdded', 0,
      'offlineDurationMinutes', 0,
      'summary', 'Kulüp bulunamadığı için offline ilerleme işlenmedi.'
    );
  END IF;

  last_activity := club_row.last_activity_at;
  IF last_activity IS NULL THEN
    last_activity := now_ts - interval '1 hour';
  END IF;

  offline_duration := now_ts - last_activity;
  reward_minutes := LEAST(EXTRACT(EPOCH FROM offline_duration)::int / 60, max_reward_minutes);

  IF reward_minutes <= 0 THEN
    UPDATE public.clubs
    SET last_activity_at = now_ts
    WHERE id = club_row.id;

    RETURN jsonb_build_object(
      'matchesSimulated', 0,
      'totalIncome', 0,
      'playersImproved', 0,
      'transferOffersReceived', 0,
      'inboxMessagesAdded', 0,
      'offlineDurationMinutes', EXTRACT(EPOCH FROM offline_duration)::int / 60,
      'summary', 'Offline ilerleme için yeterli süre yok.'
    );
  END IF;

  matches_simulated := GREATEST(1, reward_minutes / 60::int);
  reward_multiplier := CASE
    WHEN reward_minutes >= max_reward_minutes THEN 1.0
    ELSE 1.0 + (reward_minutes::numeric / max_reward_minutes::numeric) * 0.25
  END;

  income := (club_row.sponsor_level * 500 + 3000) * (matches_simulated::numeric * reward_multiplier)::bigint;
  bonus_income := (matches_simulated * 1000)::bigint;
  income := income + bonus_income;

  players_improved := CASE WHEN random() < 0.15 THEN 1 ELSE 0 END;
  transfer_offers := CASE WHEN random() < 0.1 THEN 1 ELSE 0 END;

  UPDATE public.clubs
  SET budget = budget + income,
      last_activity_at = now_ts
  WHERE id = club_row.id;

  IF players_improved > 0 THEN
    INSERT INTO public.inbox_messages (recipient_id, title, body, is_read, created_at)
    VALUES (
      current_user_id,
      'Oyuncu Gelişimi',
      'Takımınızda bir oyuncu offline dönemde gelişim gösterdi.',
      FALSE,
      now_ts
    );
  END IF;

  IF transfer_offers > 0 THEN
    INSERT INTO public.inbox_messages (recipient_id, title, body, is_read, created_at)
    VALUES (
      current_user_id,
      'Transfer Teklifi',
      'Offline süreçte bir transfer teklifi geldi.',
      FALSE,
      now_ts
    );
  END IF;

  inbox_messages_added := players_improved + transfer_offers;

  IF inbox_messages_added > 0 THEN
    INSERT INTO public.inbox_messages (recipient_id, title, body, is_read, created_at)
    VALUES (
      current_user_id,
      'Offline Özeti',
      format('Offline süreçte %s maç simüle edildi, %s GP gelir elde edildi.', matches_simulated, income),
      FALSE,
      now_ts
    );
    inbox_messages_added := inbox_messages_added + 1;
  END IF;

  result := jsonb_build_object(
    'matchesSimulated', matches_simulated,
    'totalIncome', income,
    'playersImproved', players_improved,
    'transferOffersReceived', transfer_offers,
    'inboxMessagesAdded', inbox_messages_added,
    'offlineDurationMinutes', EXTRACT(EPOCH FROM offline_duration)::int / 60,
    'summary', format('Offline süreçte %s maç simüle edildi ve %s GP gelir elde edildi.', matches_simulated, income)
  );

  RETURN result;
END;
$$;
