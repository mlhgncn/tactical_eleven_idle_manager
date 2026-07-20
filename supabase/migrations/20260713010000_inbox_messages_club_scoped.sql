-- inbox_messages only had recipient_id (a user_id), with no way to know
-- which of a user's clubs a message concerns. Once a user could own
-- multiple clubs (multi-league support), every message ever sent to them
-- - match results, transfer offers, interest income, upgrades, player
-- development, championship - appeared identically in the inbox no matter
-- which club was currently active, since loadInboxMessages only filtered
-- by recipient_id. Adds a nullable club_id (NULL = account-level message,
-- e.g. ban notices, or historical rows predating this migration) and
-- updates every currently-live INSERT INTO inbox_messages call site to
-- populate it from context each function already has on hand.

ALTER TABLE public.inbox_messages ADD COLUMN IF NOT EXISTS club_id UUID REFERENCES public.clubs(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_inbox_messages_club_id ON public.inbox_messages(club_id);

-- _resolve_transfer_offer: both messages concern the buyer's club (from_club_id).
CREATE OR REPLACE FUNCTION public._resolve_transfer_offer(p_offer_id UUID, p_accept BOOLEAN)
RETURNS void AS $$
DECLARE
  offer_row public.transfer_offers%ROWTYPE;
  buyer_user_id UUID;
BEGIN
  SELECT * INTO offer_row FROM public.transfer_offers WHERE id = p_offer_id AND status = 'pending' FOR UPDATE;
  IF NOT FOUND THEN
    RETURN;
  END IF;

  SELECT user_id INTO buyer_user_id FROM public.clubs WHERE id = offer_row.from_club_id;

  IF p_accept THEN
    IF (SELECT count(*) FROM public.players WHERE club_id = offer_row.from_club_id) >= 30 THEN
      UPDATE public.clubs SET blocked_budget = GREATEST(0, blocked_budget - offer_row.offer_amount) WHERE id = offer_row.from_club_id;
      UPDATE public.transfer_offers SET status = 'rejected', responded_at = now() WHERE id = p_offer_id;
      IF buyer_user_id IS NOT NULL THEN
        INSERT INTO public.inbox_messages(recipient_id, club_id, title, body, is_read, created_at)
        VALUES (buyer_user_id, offer_row.from_club_id, 'Teklif Reddedildi', 'Kadronuz dolu (maksimum 30 oyuncu) olduğu için transfer gerçekleşmedi, teklif iade edildi.', false, now());
      END IF;
      RETURN;
    END IF;

    UPDATE public.clubs
    SET budget = budget - offer_row.offer_amount,
        blocked_budget = GREATEST(0, blocked_budget - offer_row.offer_amount)
    WHERE id = offer_row.from_club_id;

    UPDATE public.clubs SET budget = budget + offer_row.offer_amount WHERE id = offer_row.to_club_id;

    UPDATE public.players SET club_id = offer_row.from_club_id WHERE id = offer_row.player_id;

    INSERT INTO public.financial_transactions(club_id, type, amount, description, source)
    VALUES
      (offer_row.to_club_id, 'transfer_revenue', offer_row.offer_amount, format('Transfer geliri: %s GP', offer_row.offer_amount), 'transfer_offer'),
      (offer_row.from_club_id, 'transfer_cost', -offer_row.offer_amount, format('Transfer satın alım maliyeti: -%s GP', offer_row.offer_amount), 'transfer_offer');

    INSERT INTO public.transfer_history(player_id, seller_club_id, buyer_club_id, price)
    VALUES (offer_row.player_id, offer_row.to_club_id, offer_row.from_club_id, offer_row.offer_amount);

    UPDATE public.transfer_offers SET status = 'accepted', responded_at = now() WHERE id = p_offer_id;

    UPDATE public.clubs c
    SET blocked_budget = GREATEST(0, c.blocked_budget - o.offer_amount)
    FROM public.transfer_offers o
    WHERE o.id <> p_offer_id AND o.player_id = offer_row.player_id AND o.status = 'pending' AND c.id = o.from_club_id;

    UPDATE public.transfer_offers
    SET status = 'rejected', responded_at = now()
    WHERE player_id = offer_row.player_id AND id <> p_offer_id AND status = 'pending';

    DELETE FROM public.transfer_market WHERE player_id = offer_row.player_id;

    IF buyer_user_id IS NOT NULL THEN
      INSERT INTO public.inbox_messages(recipient_id, club_id, title, body, is_read, created_at)
      VALUES (buyer_user_id, offer_row.from_club_id, 'Teklif Kabul Edildi', 'Transfer teklifin kabul edildi, oyuncu artık kadronda!', false, now());
    END IF;
  ELSE
    UPDATE public.clubs SET blocked_budget = GREATEST(0, blocked_budget - offer_row.offer_amount) WHERE id = offer_row.from_club_id;
    UPDATE public.transfer_offers SET status = 'rejected', responded_at = now() WHERE id = p_offer_id;

    IF buyer_user_id IS NOT NULL THEN
      INSERT INTO public.inbox_messages(recipient_id, club_id, title, body, is_read, created_at)
      VALUES (buyer_user_id, offer_row.from_club_id, 'Teklif Reddedildi', 'Transfer teklifin reddedildi.', false, now());
    END IF;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- advance_completed_seasons: championship message concerns the champion club.
CREATE OR REPLACE FUNCTION public.advance_completed_seasons()
RETURNS void AS $$
DECLARE
  season_rec RECORD;
  champion_id UUID;
  champion_user_id UUID;
  champion_losses INT;
  human_club_id UUID;
BEGIN
  FOR season_rec IN
    SELECT s.id, s.league_id
    FROM public.seasons s
    WHERE s.is_active = true
      AND s.is_completed = false
      AND EXISTS (SELECT 1 FROM public.matches m WHERE m.season_id = s.id)
      AND NOT EXISTS (SELECT 1 FROM public.matches m WHERE m.season_id = s.id AND m.is_played = false)
  LOOP
    SELECT club_id, losses INTO champion_id, champion_losses
    FROM public.league_standings
    WHERE season_id = season_rec.id
    ORDER BY points DESC, goal_difference DESC, goals_for DESC
    LIMIT 1;

    UPDATE public.seasons
    SET is_completed = true, is_active = false, champion_club_id = champion_id, end_date = now()
    WHERE id = season_rec.id;

    IF champion_id IS NOT NULL THEN
      SELECT user_id INTO champion_user_id FROM public.clubs WHERE id = champion_id;
      IF champion_user_id IS NOT NULL THEN
        UPDATE public.profiles
        SET league_titles = league_titles + 1, diamonds = diamonds + 50
        WHERE id = champion_user_id;

        IF champion_losses = 0 THEN
          UPDATE public.profiles SET has_unbeaten_title = true WHERE id = champion_user_id;
        END IF;

        INSERT INTO public.inbox_messages(recipient_id, club_id, title, body, is_read, created_at)
        VALUES (
          champion_user_id,
          champion_id,
          'Şampiyonluk!',
          'Tebrikler, kulübün ligi şampiyon olarak tamamladı! Kupa dolabına bir kupa daha eklendi ve hesabına 50 elmas hediye edildi.',
          false,
          now()
        );
      END IF;
    END IF;

    SELECT id INTO human_club_id FROM public.clubs WHERE league_id = season_rec.league_id AND user_id IS NOT NULL LIMIT 1;
    IF human_club_id IS NOT NULL THEN
      UPDATE public.clubs SET pending_season_end_season_id = season_rec.id WHERE id = human_club_id;
    ELSE
      PERFORM public.generate_season_fixtures_for_league(season_rec.league_id);
    END IF;
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- make_transfer_offer: message concerns the seller's club (player_row.club_id).
CREATE OR REPLACE FUNCTION public.make_transfer_offer(p_player_id UUID, p_offer_amount BIGINT, p_club_id UUID DEFAULT NULL)
RETURNS public.transfer_offers AS $$
DECLARE
  buyer_club public.clubs%ROWTYPE;
  player_row public.players%ROWTYPE;
  seller_user_id UUID;
  available_budget BIGINT;
  new_offer public.transfer_offers;
  fair_value BIGINT;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated user cannot make an offer';
  END IF;
  IF p_offer_amount <= 0 THEN
    RAISE EXCEPTION 'Offer must be positive';
  END IF;

  IF p_club_id IS NOT NULL THEN
    SELECT * INTO buyer_club FROM public.clubs WHERE id = p_club_id AND user_id = auth.uid();
  ELSE
    SELECT * INTO buyer_club FROM public.clubs WHERE user_id = auth.uid() LIMIT 1;
  END IF;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'User does not own a club';
  END IF;

  SELECT * INTO player_row FROM public.players WHERE id = p_player_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Player not found';
  END IF;
  IF player_row.club_id IS NULL THEN
    RAISE EXCEPTION 'Player is a free agent, use sign_free_agent instead';
  END IF;
  IF player_row.club_id = buyer_club.id THEN
    RAISE EXCEPTION 'Cannot make an offer for your own player';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.transfer_offers
    WHERE player_id = p_player_id AND from_club_id = buyer_club.id AND status = 'pending'
  ) THEN
    RAISE EXCEPTION 'You already have a pending offer for this player';
  END IF;

  available_budget := buyer_club.budget - buyer_club.blocked_budget;
  IF available_budget < p_offer_amount THEN
    RAISE EXCEPTION 'Insufficient available budget to make this offer';
  END IF;

  UPDATE public.clubs SET blocked_budget = blocked_budget + p_offer_amount WHERE id = buyer_club.id;

  INSERT INTO public.transfer_offers(player_id, from_club_id, to_club_id, offer_amount, status)
  VALUES (p_player_id, buyer_club.id, player_row.club_id, p_offer_amount, 'pending')
  RETURNING * INTO new_offer;

  SELECT user_id INTO seller_user_id FROM public.clubs WHERE id = player_row.club_id;

  IF seller_user_id IS NOT NULL THEN
    INSERT INTO public.inbox_messages(recipient_id, club_id, title, body, is_read, created_at)
    VALUES (
      seller_user_id,
      player_row.club_id,
      'Transfer Teklifi',
      format('%s için %s GP teklif aldın.', player_row.name, p_offer_amount),
      false,
      now()
    );
    RETURN new_offer;
  END IF;

  fair_value := ((player_row.current_ability * 15000 + player_row.potential_ability * 5000 + player_row.age * 100)::numeric / 40)::BIGINT;
  PERFORM public._resolve_transfer_offer(new_offer.id, p_offer_amount >= (fair_value * 0.85)::BIGINT);

  SELECT * INTO new_offer FROM public.transfer_offers WHERE id = new_offer.id;
  RETURN new_offer;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- process_bank_interest: interest summary message concerns the club whose deposits earned it.
CREATE OR REPLACE FUNCTION public.process_bank_interest()
RETURNS void AS $$
DECLARE
  deposit_row RECORD;
  interest_amount BIGINT;
  total_by_club RECORD;
BEGIN
  FOR deposit_row IN
    SELECT d.id, d.club_id, d.balance, b.daily_interest_rate, b.name AS bank_name
    FROM public.bank_deposits d
    JOIN public.banks b ON b.id = d.bank_id
    WHERE d.withdrawn_at IS NULL AND d.last_interest_at <= now() - interval '1 day'
  LOOP
    interest_amount := GREATEST(1, ROUND(deposit_row.balance * deposit_row.daily_interest_rate));

    UPDATE public.bank_deposits
    SET balance = balance + interest_amount, last_interest_at = now()
    WHERE id = deposit_row.id;

    INSERT INTO public.financial_transactions(club_id, type, amount, description, source)
    VALUES (deposit_row.club_id, 'income', interest_amount, format('%s günlük faiz: +%s GP', deposit_row.bank_name, interest_amount), 'interest_income');
  END LOOP;

  FOR total_by_club IN
    SELECT club_id, user_id, sum(amount) AS total
    FROM public.financial_transactions ft
    JOIN public.clubs c ON c.id = ft.club_id
    WHERE ft.source = 'interest_income' AND ft.created_at >= now() - interval '5 minutes' AND c.user_id IS NOT NULL
    GROUP BY club_id, user_id
  LOOP
    INSERT INTO public.inbox_messages(recipient_id, club_id, title, body, is_read, created_at)
    VALUES (total_by_club.user_id, total_by_club.club_id, 'Faiz Geliri', format('Banka hesaplarından toplam %s GP faiz geliri elde ettin.', total_by_club.total), false, now());
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- process_injury_alerts: alert concerns club_row.id (the club with the injured/suspended starter).
CREATE OR REPLACE FUNCTION public.process_injury_alerts()
RETURNS void AS $$
DECLARE
  match_row RECORD;
  club_row RECORD;
  tactic_row RECORD;
  affected_names TEXT;
BEGIN
  FOR match_row IN
    SELECT id, home_club_id, away_club_id
    FROM public.matches
    WHERE is_played = false
      AND injury_alert_sent = false
      AND match_date <= now() + interval '15 minutes'
      AND match_date > now()
  LOOP
    FOR club_row IN
      SELECT id, user_id FROM public.clubs
      WHERE id IN (match_row.home_club_id, match_row.away_club_id) AND user_id IS NOT NULL
    LOOP
      SELECT starting_eleven_ids INTO tactic_row FROM public.tactics WHERE club_id = club_row.id;

      SELECT string_agg(p.name, ', ') INTO affected_names
      FROM public.players p
      WHERE p.club_id = club_row.id
        AND (p.injury_duration_weeks > 0 OR p.is_suspended)
        AND (
          tactic_row.starting_eleven_ids IS NULL
          OR p.id = ANY(tactic_row.starting_eleven_ids)
        );

      IF affected_names IS NOT NULL THEN
        INSERT INTO public.inbox_messages(recipient_id, club_id, title, body, is_read, created_at)
        VALUES (
          club_row.user_id,
          club_row.id,
          'Acil: Kadroda Sakat/Cezalı Oyuncu',
          format('Maça 15 dakikadan az kaldı ve kadronda sakat/cezalı oyuncu var: %s. Kadroyu düzenlemezsen sistem otomatik olarak en iyi uygun yedeği yerine koyacak.', affected_names),
          false,
          now()
        );
      END IF;
    END LOOP;

    UPDATE public.matches SET injury_alert_sent = true WHERE id = match_row.id;
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- process_club_upgrades: message concerns club_row.id.
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
      INSERT INTO public.inbox_messages(recipient_id, club_id, title, body, is_read, created_at)
      VALUES (club_row.user_id, club_row.id, message_title, message_body, false, now());
    END IF;
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- process_player_development: message concerns player_row.club_id.
CREATE OR REPLACE FUNCTION public.process_player_development()
RETURNS void AS $$
DECLARE
  player_row public.players%ROWTYPE;
  growth_percent DOUBLE PRECISION;
  growth_delta INT;
  new_current_ability INT;
  owner_id UUID;
  proximity_ratio NUMERIC;
  diminishing_factor NUMERIC;
BEGIN
  FOR player_row IN
    SELECT * FROM public.players
    WHERE development_completes_at IS NOT NULL AND development_completes_at <= now()
  LOOP
    proximity_ratio := player_row.current_ability::numeric / GREATEST(1, player_row.potential_ability);
    diminishing_factor := CASE
      WHEN proximity_ratio < 0.9 THEN 1.0
      ELSE GREATEST(0.1, 1.0 - (proximity_ratio - 0.9) * 9.0)
    END;

    growth_percent := (0.01 + random() * 0.02) * diminishing_factor;
    growth_delta := GREATEST(1, ROUND(player_row.current_ability * growth_percent));
    new_current_ability := LEAST(player_row.potential_ability, player_row.current_ability + growth_delta);

    UPDATE public.players
    SET current_ability = new_current_ability,
        development_completes_at = NULL,
        development_ad_uses = 0
    WHERE id = player_row.id;

    IF player_row.club_id IS NOT NULL THEN
      SELECT user_id INTO owner_id FROM public.clubs WHERE id = player_row.club_id;
      IF owner_id IS NOT NULL THEN
        INSERT INTO public.inbox_messages(recipient_id, club_id, title, body, is_read, created_at)
        VALUES (
          owner_id,
          player_row.club_id,
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

-- process_sponsor_upgrades: message concerns club_row.id.
CREATE OR REPLACE FUNCTION public.process_sponsor_upgrades()
RETURNS void AS $$
DECLARE
  club_row public.clubs%ROWTYPE;
  new_level INT;
BEGIN
  FOR club_row IN
    SELECT * FROM public.clubs
    WHERE sponsor_upgrade_completes_at IS NOT NULL AND sponsor_upgrade_completes_at <= now()
  LOOP
    new_level := LEAST(5, club_row.sponsor_level + 1);

    UPDATE public.clubs
    SET sponsor_level = new_level,
        sponsor_upgrade_completes_at = NULL
    WHERE id = club_row.id;

    IF club_row.user_id IS NOT NULL THEN
      INSERT INTO public.inbox_messages(recipient_id, club_id, title, body, is_read, created_at)
      VALUES (
        club_row.user_id,
        club_row.id,
        'Sponsor Anlaşması',
        format('Sponsor seviyesi %s''e yükseltildi! Yeni aylık gelir: %s GP', new_level, new_level * 1000),
        false,
        now()
      );
    END IF;
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- simulate_offline_progress: already scoped to a single club_row (picked
-- via the same LIMIT-1 pattern as bug 7's inventory - left as-is here
-- since "simulate offline progress for the club I'm about to view" only
-- makes sense for the currently active club, but stamping club_id on its
-- own messages is still correct and needed regardless of which club it is).
CREATE OR REPLACE FUNCTION public.simulate_offline_progress()
RETURNS jsonb AS $$
DECLARE
  current_user_id UUID := auth.uid();
  club_row public.clubs%ROWTYPE;
  now_ts TIMESTAMPTZ := now();
  last_activity TIMESTAMPTZ;
  offline_duration INTERVAL;
  max_reward_minutes INT := 24 * 60 * 3;
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
    INSERT INTO public.inbox_messages (recipient_id, club_id, title, body, is_read, created_at)
    VALUES (
      current_user_id,
      club_row.id,
      'Oyuncu Gelişimi',
      'Takımınızda bir oyuncu offline dönemde gelişim gösterdi.',
      FALSE,
      now_ts
    );
  END IF;

  IF transfer_offers > 0 THEN
    INSERT INTO public.inbox_messages (recipient_id, club_id, title, body, is_read, created_at)
    VALUES (
      current_user_id,
      club_row.id,
      'Transfer Teklifi',
      'Offline süreçte bir transfer teklifi geldi.',
      FALSE,
      now_ts
    );
  END IF;

  inbox_messages_added := players_improved + transfer_offers;

  IF inbox_messages_added > 0 THEN
    INSERT INTO public.inbox_messages (recipient_id, club_id, title, body, is_read, created_at)
    VALUES (
      current_user_id,
      club_row.id,
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
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- track_lineup_neglect: message already scoped by p_club_id.
CREATE OR REPLACE FUNCTION public.track_lineup_neglect(p_club_id UUID, p_had_valid_lineup BOOLEAN)
RETURNS void AS $$
DECLARE
  new_count INT;
BEGIN
  IF p_had_valid_lineup THEN
    UPDATE public.clubs SET matches_without_lineup = 0 WHERE id = p_club_id;
    RETURN;
  END IF;

  UPDATE public.clubs SET matches_without_lineup = matches_without_lineup + 1
  WHERE id = p_club_id
  RETURNING matches_without_lineup INTO new_count;

  IF new_count >= 10 THEN
    UPDATE public.players SET club_id = NULL WHERE club_id = p_club_id;
    UPDATE public.clubs SET matches_without_lineup = 0 WHERE id = p_club_id;

    INSERT INTO public.inbox_messages(recipient_id, club_id, title, body, is_read, created_at)
    SELECT user_id, p_club_id, 'Kadro Dağıtıldı', 'Üst üste 10 maç boyunca kadro düzenlemediğiniz için tüm oyuncularınız serbest kaldı.', false, now()
    FROM public.clubs WHERE id = p_club_id AND user_id IS NOT NULL;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION public._resolve_transfer_offer(UUID, BOOLEAN) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.advance_completed_seasons() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.make_transfer_offer(UUID, BIGINT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.process_bank_interest() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.process_injury_alerts() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.process_club_upgrades() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.process_player_development() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.process_sponsor_upgrades() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.simulate_offline_progress() TO authenticated;
GRANT EXECUTE ON FUNCTION public.track_lineup_neglect(UUID, BOOLEAN) TO authenticated, service_role;
