CREATE TABLE IF NOT EXISTS public.match_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    match_id UUID NOT NULL REFERENCES public.matches(id) ON DELETE CASCADE,
    minute INT NOT NULL,
    event_type TEXT NOT NULL,
    club_id UUID REFERENCES public.clubs(id) ON DELETE SET NULL,
    player_id UUID REFERENCES public.players(id) ON DELETE SET NULL,
    assist_player_id UUID REFERENCES public.players(id) ON DELETE SET NULL,
    description TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.match_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS match_events_select_policy ON public.match_events;
CREATE POLICY match_events_select_policy ON public.match_events FOR SELECT TO authenticated
  USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS match_events_insert_policy ON public.match_events;
CREATE POLICY match_events_insert_policy ON public.match_events FOR INSERT TO authenticated
  USING (false);

DROP POLICY IF EXISTS match_events_update_policy ON public.match_events;
CREATE POLICY match_events_update_policy ON public.match_events FOR UPDATE TO authenticated
  USING (false);

DROP POLICY IF EXISTS match_events_delete_policy ON public.match_events;
CREATE POLICY match_events_delete_policy ON public.match_events FOR DELETE TO authenticated
  USING (false);
