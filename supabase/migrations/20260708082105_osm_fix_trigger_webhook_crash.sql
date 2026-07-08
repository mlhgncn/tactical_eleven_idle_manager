-- Found while debugging why auto_resolve_matches' UPDATE on matches kept
-- failing with "unrecognized configuration parameter app.supabase_url":
-- there's a trigger_webhook_on_match AFTER UPDATE trigger on matches (not
-- defined in any migration in this repo - applied directly against
-- production at some earlier point) that calls trigger_webhook() on every
-- single update, which reads current_setting('app.supabase_url') /
-- ('app.service_role_key') with no default. Neither was ever configured,
-- so the setting lookup raises, the trigger's exception propagates
-- uncaught, and Postgres rolls back the ENTIRE triggering UPDATE - meaning
-- every match update (both from play_next_fixture and
-- auto_resolve_matches) has been silently failing to ever mark a match as
-- played.
--
-- Fix trigger_webhook itself to degrade gracefully instead of raising: use
-- current_setting(..., true) (missing_ok) and skip the HTTP call entirely
-- if either piece of config isn't set, rather than letting an
-- infrastructure gap take down unrelated writes.
CREATE OR REPLACE FUNCTION public.trigger_webhook(
  p_event_type TEXT,
  p_payload JSONB
)
RETURNS void AS $$
DECLARE
  v_webhook_config RECORD;
  v_supabase_url TEXT;
  v_service_role_key TEXT;
BEGIN
  v_supabase_url := current_setting('app.supabase_url', true);
  v_service_role_key := current_setting('app.service_role_key', true);

  IF v_supabase_url IS NULL OR v_service_role_key IS NULL THEN
    RETURN;
  END IF;

  FOR v_webhook_config IN
    SELECT id, target_function
    FROM public.webhook_configurations
    WHERE event_type = p_event_type
      AND is_active = TRUE
  LOOP
    PERFORM
      net.http_post(
        url := concat('https://', v_supabase_url, '/functions/v1/', v_webhook_config.target_function),
        headers := jsonb_build_object(
          'Authorization', concat('Bearer ', v_service_role_key),
          'Content-Type', 'application/json'
        ),
        body := p_payload
      );
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
