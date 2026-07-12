-- scout_opponent (20260711180000_scout_opponent.sql) only ever returned a
-- live snapshot, gated to the 15-minutes-before-kickoff window and never
-- persisted - once the user navigated away there was no way back to a
-- previously scouted opponent's squad/tactics. This keeps the 15-minute
-- gate for producing a *new* scout (still narrow, still time-boxed), but
-- saves each report so it can be reopened later from the club screen.
CREATE TABLE IF NOT EXISTS public.scouted_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  scouting_club_id UUID NOT NULL REFERENCES public.clubs(id) ON DELETE CASCADE,
  opponent_club_id UUID NOT NULL REFERENCES public.clubs(id) ON DELETE CASCADE,
  match_id UUID NOT NULL REFERENCES public.matches(id) ON DELETE CASCADE,
  report JSON NOT NULL,
  scouted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (scouting_club_id, match_id)
);

CREATE INDEX IF NOT EXISTS scouted_reports_scouting_club_idx ON public.scouted_reports (scouting_club_id, scouted_at DESC);

ALTER TABLE public.scouted_reports ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS scouted_reports_select_policy ON public.scouted_reports;
CREATE POLICY scouted_reports_select_policy ON public.scouted_reports FOR SELECT TO authenticated
  USING (scouting_club_id IN (SELECT id FROM public.clubs WHERE user_id = auth.uid()));
-- No insert/update/delete policy for regular users - only the
-- SECURITY DEFINER scout_opponent() function writes rows.

CREATE OR REPLACE FUNCTION public.scout_opponent(p_match_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  match_row public.matches%ROWTYPE;
  caller_club_id UUID;
  opponent_club_id_var UUID;
  result JSON;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated user cannot scout an opponent';
  END IF;

  SELECT id INTO caller_club_id FROM public.clubs WHERE user_id = auth.uid() LIMIT 1;
  IF caller_club_id IS NULL THEN
    RAISE EXCEPTION 'Bir kulübünüz yok';
  END IF;

  SELECT * INTO match_row FROM public.matches WHERE id = p_match_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Maç bulunamadı';
  END IF;

  IF match_row.home_club_id != caller_club_id AND match_row.away_club_id != caller_club_id THEN
    RAISE EXCEPTION 'Bu maçın tarafı değilsiniz';
  END IF;

  IF match_row.is_played THEN
    RAISE EXCEPTION 'Bu maç zaten oynandı';
  END IF;

  IF match_row.match_date > now() + interval '15 minutes' THEN
    RAISE EXCEPTION 'Rakip kadrosu maça 15 dakika kalana kadar görüntülenemez';
  END IF;

  opponent_club_id_var := CASE
    WHEN match_row.home_club_id = caller_club_id THEN match_row.away_club_id
    ELSE match_row.home_club_id
  END;

  SELECT json_build_object(
    'club_id', opponent_club_id_var,
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
      FROM public.players p WHERE p.club_id = opponent_club_id_var
    ),
    'tactics', (
      SELECT row_to_json(t) FROM (
        SELECT formation, mentality, starting_eleven_ids, press_intensity, tempo,
               defensive_line, offside_trap, time_wasting
        FROM public.tactics WHERE club_id = opponent_club_id_var
      ) t
    )
  ) INTO result;

  INSERT INTO public.scouted_reports (scouting_club_id, opponent_club_id, match_id, report)
  VALUES (caller_club_id, opponent_club_id_var, p_match_id, result)
  ON CONFLICT (scouting_club_id, match_id) DO UPDATE SET report = EXCLUDED.report, scouted_at = now();

  RETURN result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.scout_opponent(UUID) TO authenticated;

-- Lists this club's previously saved scout reports (most recent first) so
-- the club screen can offer a "view saved scouts" list without re-running
-- the 15-minute-gated live scout.
CREATE OR REPLACE FUNCTION public.list_scouted_reports()
RETURNS TABLE(
  id UUID,
  match_id UUID,
  opponent_club_id UUID,
  opponent_name TEXT,
  report JSON,
  scouted_at TIMESTAMPTZ
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT sr.id, sr.match_id, sr.opponent_club_id, c.name, sr.report, sr.scouted_at
  FROM public.scouted_reports sr
  JOIN public.clubs c ON c.id = sr.opponent_club_id
  WHERE sr.scouting_club_id IN (SELECT id FROM public.clubs WHERE user_id = auth.uid())
  ORDER BY sr.scouted_at DESC;
$$;

GRANT EXECUTE ON FUNCTION public.list_scouted_reports() TO authenticated;
