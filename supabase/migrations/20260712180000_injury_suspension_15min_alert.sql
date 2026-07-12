-- Module 4's remaining piece: "Kadroda sakat veya cezalı oyuncu varsa,
-- kullanıcıya acil durum mesajı gönderilmeli" - a proactive inbox warning
-- sent once, ~15 minutes before kickoff, when a club's saved starting XI
-- (or the lack of one) still contains an injured/suspended player. The
-- actual auto-substitution at kickoff already happens client-side of the
-- match engine (buildEffectiveRoster in match_engine.ts) - this only adds
-- the advance warning so the user has a chance to fix the lineup
-- themselves before that automatic swap happens.

ALTER TABLE public.matches ADD COLUMN IF NOT EXISTS injury_alert_sent BOOLEAN NOT NULL DEFAULT false;

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
        INSERT INTO public.inbox_messages(recipient_id, title, body, is_read, created_at)
        VALUES (
          club_row.user_id,
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

SELECT cron.unschedule('process-injury-alerts') WHERE EXISTS (
  SELECT 1 FROM cron.job WHERE jobname = 'process-injury-alerts'
);

SELECT cron.schedule(
  'process-injury-alerts',
  '*/5 * * * *',
  $$SELECT public.process_injury_alerts();$$
);
