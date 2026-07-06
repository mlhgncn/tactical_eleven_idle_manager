-- Enable pg_cron and pg_net extensions for scheduled tasks
CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;

-- Note: Cron jobs for calling Edge Functions are set up separately via Supabase Dashboard
-- Cron jobs require the http_post function from pg_net extension
-- Configuration:
-- 1. auto_match_simulator: Daily at 02:00 UTC
-- 2. offline_progress_simulator: Every 6 hours

-- Table for webhook configurations
CREATE TABLE IF NOT EXISTS public.webhook_configurations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  event_type TEXT NOT NULL,  -- 'match_played', 'player_injured', 'transfer_offer'
  target_function TEXT NOT NULL,  -- Edge function name to call
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- RLS for webhook_configurations
ALTER TABLE public.webhook_configurations ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all to read webhook configurations" ON public.webhook_configurations
  FOR SELECT USING (true);

-- Insert default webhook configurations
INSERT INTO public.webhook_configurations (name, event_type, target_function, is_active)
VALUES
  ('Match Result Notification', 'match_played', 'match_result_notification', TRUE),
  ('Player Injury Alert', 'player_injured', 'match_result_notification', TRUE),
  ('Transfer Offer Notification', 'transfer_offer', 'match_result_notification', TRUE)
ON CONFLICT (name) DO NOTHING;

-- Function to trigger webhooks
CREATE OR REPLACE FUNCTION public.trigger_webhook(
  p_event_type TEXT,
  p_payload JSONB
)
RETURNS void AS $$
DECLARE
  v_webhook_config RECORD;
BEGIN
  FOR v_webhook_config IN
    SELECT id, target_function
    FROM public.webhook_configurations
    WHERE event_type = p_event_type
      AND is_active = TRUE
  LOOP
    PERFORM
      net.http_post(
        url := concat(
          'https://',
          current_setting('app.supabase_url'),
          '/functions/v1/',
          v_webhook_config.target_function
        ),
        headers := jsonb_build_object(
          'Authorization', concat('Bearer ', current_setting('app.service_role_key')),
          'Content-Type', 'application/json'
        ),
        body := p_payload
      );
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute on webhook trigger to authenticated users
GRANT EXECUTE ON FUNCTION public.trigger_webhook(TEXT, JSONB) TO authenticated;

-- Table for storing environment secrets
CREATE TABLE IF NOT EXISTS public.environment_secrets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  key TEXT NOT NULL UNIQUE,
  value TEXT NOT NULL,
  is_encrypted BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- RLS for environment_secrets
ALTER TABLE public.environment_secrets ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow service role only" ON public.environment_secrets
  FOR ALL USING (auth.role() = 'service_role');

-- Insert FCM API Key placeholder (actual value should be set via environment variable)
INSERT INTO public.environment_secrets (key, value, is_encrypted)
VALUES ('FCM_API_KEY', '', TRUE)
ON CONFLICT (key) DO NOTHING;

-- Function to get environment secret (for use by edge functions)
CREATE OR REPLACE FUNCTION public.get_secret(p_key TEXT)
RETURNS TEXT AS $$
DECLARE
  v_value TEXT;
BEGIN
  SELECT value INTO v_value
  FROM public.environment_secrets
  WHERE key = p_key;
  RETURN v_value;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute to service_role and authenticated
GRANT EXECUTE ON FUNCTION public.get_secret(TEXT) TO service_role, authenticated;

-- Add column to track last function trigger
ALTER TABLE public.clubs
ADD COLUMN IF NOT EXISTS last_match_played_at TIMESTAMPTZ DEFAULT NULL,
ADD COLUMN IF NOT EXISTS last_offline_progress_at TIMESTAMPTZ DEFAULT NULL;

-- Function to update last_activity_at on clubs
CREATE OR REPLACE FUNCTION public.update_last_activity()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE public.clubs
  SET last_activity_at = now()
  WHERE id = NEW.club_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers for tracking last activity
CREATE TRIGGER update_last_activity_on_match
AFTER UPDATE ON public.matches
FOR EACH ROW
WHEN (NEW.is_played = TRUE AND OLD.is_played = FALSE)
EXECUTE FUNCTION public.update_last_activity();

CREATE TRIGGER update_last_activity_on_financial
AFTER INSERT ON public.financial_transactions
FOR EACH ROW
EXECUTE FUNCTION public.update_last_activity();

-- Index for better performance
CREATE INDEX IF NOT EXISTS idx_clubs_last_activity_at ON public.clubs(last_activity_at DESC);
CREATE INDEX IF NOT EXISTS idx_webhook_configurations_event_type ON public.webhook_configurations(event_type);
