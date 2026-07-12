-- Module 8: UI/UX, notifications, and screen optimizations.
-- 1) view_club_roster: lets any authenticated user look up any club's
--    current squad (used by the new "tap a team in standings" bottom
--    sheet) - unlike scout_opponent this has no match-participant or
--    15-minutes-to-kickoff restriction, since standings is a page where
--    everyone already sees everyone's results/positions.
-- 2) mark_message_unread: the missing inverse of the existing
--    mark-as-read flow, so a user can manually flip a message back to
--    unread.
-- 3) pre_match_alert_sent + process_pre_match_alerts: a 30-minutes-to-
--    kickoff reminder, cron-driven, mirroring process_injury_alerts's
--    shape but also pushing an FCM notification via the new
--    pre_match_alert_notification edge function (deployed separately).

CREATE OR REPLACE FUNCTION public.view_club_roster(p_club_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  result JSON;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated user cannot view a roster';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.clubs WHERE id = p_club_id) THEN
    RAISE EXCEPTION 'Kulüp bulunamadı';
  END IF;

  SELECT json_build_object(
    'club_id', p_club_id,
    'players', (
      SELECT COALESCE(json_agg(json_build_object(
        'id', p.id,
        'name', p.name,
        'position', p.position,
        'age', p.age,
        'current_ability', p.current_ability,
        'is_suspended', p.is_suspended,
        'injury_duration_weeks', p.injury_duration_weeks
      )), '[]'::json)
      FROM public.players p WHERE p.club_id = p_club_id
    ),
    'tactics', (
      SELECT COALESCE(
        (SELECT row_to_json(t) FROM (
          SELECT formation, mentality, starting_eleven_ids, press_intensity, tempo,
                 defensive_line, offside_trap, time_wasting
          FROM public.tactics WHERE club_id = p_club_id
        ) t),
        CASE WHEN (SELECT user_id FROM public.clubs WHERE id = p_club_id) IS NULL THEN
          json_build_object(
            'formation', 'f442',
            'mentality', 'balanced',
            'starting_eleven_ids', NULL,
            'press_intensity', 50,
            'tempo', 50,
            'defensive_line', 50,
            'offside_trap', false,
            'time_wasting', false
          )
        ELSE NULL END
      )
    )
  ) INTO result;

  RETURN result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.view_club_roster(UUID) TO authenticated;

CREATE OR REPLACE FUNCTION public.mark_message_unread(p_message_id UUID)
RETURNS public.inbox_messages AS $$
DECLARE
  u_id UUID := auth.uid();
  message_row public.inbox_messages;
BEGIN
  IF u_id IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated';
  END IF;

  UPDATE public.inbox_messages
  SET is_read = false
  WHERE id = p_message_id AND recipient_id = u_id
  RETURNING * INTO message_row;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Mesaj bulunamadı';
  END IF;

  RETURN message_row;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION public.mark_message_unread(UUID) TO authenticated;

ALTER TABLE public.matches ADD COLUMN IF NOT EXISTS pre_match_alert_sent BOOLEAN NOT NULL DEFAULT false;

-- Finds matches hitting the 30-minute-to-kickoff window and pushes the
-- payload to pre_match_alert_notification, which looks up each side's FCM
-- token and sends the actual push - this function only decides WHICH
-- matches are due and marks them sent (once, atomically per match), same
-- non-duplicate guarantee as process_injury_alerts.
CREATE OR REPLACE FUNCTION public.process_pre_match_alerts()
RETURNS void AS $$
DECLARE
  match_row RECORD;
BEGIN
  FOR match_row IN
    SELECT id, home_club_id, away_club_id
    FROM public.matches
    WHERE is_played = false
      AND pre_match_alert_sent = false
      AND match_date <= now() + interval '30 minutes'
      AND match_date > now() + interval '25 minutes'
  LOOP
    PERFORM net.http_post(
      url := 'https://dfdidifutotlxvvslzrl.supabase.co/functions/v1/pre_match_alert_notification',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-cron-secret', (SELECT value FROM public.environment_secrets WHERE key = 'CRON_SHARED_SECRET')
      ),
      body := jsonb_build_object(
        'match_id', match_row.id,
        'home_club_id', match_row.home_club_id,
        'away_club_id', match_row.away_club_id
      ),
      timeout_milliseconds := 10000
    );

    UPDATE public.matches SET pre_match_alert_sent = true WHERE id = match_row.id;
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

SELECT cron.unschedule(jobid) FROM cron.job WHERE jobname = 'process-pre-match-alerts';
SELECT cron.schedule(
  'process-pre-match-alerts',
  '*/5 * * * *',
  $$SELECT public.process_pre_match_alerts();$$
);
